#!/usr/bin/env python3
"""Audit the LMS suite's shared gmem address space.

Every LMS plugin declares `options:gmem=DrumBanger`, so all of them read and
write ONE flat global array. Nothing in JSFX prevents two plugins from picking
the same address, and nothing announces it when they do -- the symptom is a
value that occasionally goes wrong, in a plugin that looks correct.

This resolves every `gmem[...]` in the suite back to the constant or literal
that anchors it, and checks that anchor falls inside a region declared in
lms_core.jsfx-inc. An address nobody declared is the thing to catch: that is
what an accidental collision looks like before it becomes one.

Declare regions in lms_core.jsfx-inc with lines of the form:

    // @gmem NAME start=960000 size=100 owner=lms_harmony_map.jsfx -- what it is

Usage:  python tools/gmem_audit.py [--map]
Exit:   0 clean, 1 if anything is undeclared or two regions overlap.
"""
import re, sys, glob, os, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORE = os.path.join(ROOT, 'lms_core.jsfx-inc')

REGION_RE = re.compile(
    r'^\s*//\s*@gmem\s+(\w+)\s+start=(\d+)\s+size=(\d+)\s+owner=(\S+)\s*(?:--\s*(.*))?$')


def load_regions():
    regions = []
    with open(CORE, encoding='utf-8', errors='replace') as fh:
        for ln, line in enumerate(fh, 1):
            m = REGION_RE.match(line)
            if m:
                regions.append(dict(name=m.group(1), start=int(m.group(2)),
                                    size=int(m.group(3)), owner=m.group(4),
                                    desc=(m.group(5) or '').strip(), line=ln))
    regions.sort(key=lambda r: r['start'])
    return regions


def source_files():
    files = sorted(glob.glob(os.path.join(ROOT, 'lms_*.jsfx')))
    files.append(CORE)
    return files


def consts(src):
    """NAME = 12345;  and  this.NAME = 12345;  -- plain numeric constants."""
    d = {}
    for m in re.finditer(r'^\s*(?:this\.)?([A-Za-z_]\w*)\s*=\s*(\d+)\s*;', src, re.M):
        d.setdefault(m.group(1), int(m.group(2)))
    return d


def last_segment(name):
    """`bc.BC_MY_REGION` -> `BC_MY_REGION`.

    Instances are addressed through whatever local name the caller gave the
    namespace, so only the final segment is stable across files.
    """
    return name.rsplit('.', 1)[-1]


def anchor_of(expr, table):
    """Resolve a gmem index expression to the numeric address anchoring it.

    Handles `NAME`, `1234`, `NAME + i*4 + 3`, `this.NAME + 1`. Returns None if
    no leading constant can be identified.
    """
    expr = expr.strip()
    m = re.match(r'^([A-Za-z_][\w.]*)', expr)
    if m:
        name = last_segment(m.group(1))
        if name in table:
            return table[name]
        return None
    m = re.match(r'^(\d+)', expr)
    if m:
        return int(m.group(1))
    return None


def local_bases(src, table):
    """Variables assigned from a constant, e.g. `base = 961100 + slot * 20;`.

    These are how most plugins address a per-slot sub-region, so without them
    a third of the accesses resolve to nothing.
    """
    out = dict(table)
    for _ in range(3):                      # a few passes: bases built from bases
        changed = False
        for m in re.finditer(r'^\s*((?:this\.)?[A-Za-z_][\w.]*)\s*=\s*([^;]+);', src, re.M):
            var, rhs = last_segment(m.group(1)), m.group(2)
            if var in out:
                continue
            a = anchor_of(rhs, out)
            if a is not None and a >= 10:   # ignore tiny loop counters
                out[var] = a
                changed = True
        if not changed:
            break
    return out


def audit():
    regions = load_regions()
    problems = []

    for i in range(len(regions) - 1):
        a, b = regions[i], regions[i + 1]
        if a['start'] + a['size'] > b['start']:
            problems.append(
                f"OVERLAP: {a['name']} ({a['start']}..{a['start']+a['size']-1}) "
                f"runs into {b['name']} (starts {b['start']})")

    def region_of(addr):
        for r in regions:
            if r['start'] <= addr < r['start'] + r['size']:
                return r
        return None

    core_src = open(CORE, encoding='utf-8', errors='replace').read()
    core_consts = local_bases(core_src, consts(core_src))

    hits = collections.defaultdict(set)
    undeclared = collections.defaultdict(set)
    unresolved = collections.Counter()
    resolved = []          # (file, address) for every access we could pin down

    for path in source_files():
        name = os.path.basename(path)
        raw = open(path, encoding='utf-8', errors='replace').read()
        if 'options:gmem' not in raw and name != 'lms_core.jsfx-inc':
            continue
        # Strip line comments first. Prose mentions addresses -- a note saying
        # "this used to live at gmem[50030]" is not a use of gmem[50030].
        src = re.sub(r'//[^\n]*', '', raw)
        # Every plugin imports lms_core, so a base it addresses may well be
        # defined there rather than locally. Resolve against both.
        table = local_bases(raw, dict(core_consts, **consts(raw)))
        for m in re.finditer(r'gmem\s*\[([^\]]*)\]', src):
            addr = anchor_of(m.group(1), table)
            if addr is None:
                unresolved[name] += 1
                continue
            resolved.append((name, addr))
            r = region_of(addr)
            if r:
                hits[r['name']].add(name)
            else:
                undeclared[addr].add(name)

    return regions, problems, hits, undeclared, unresolved, resolved


def main():
    regions, problems, hits, undeclared, unresolved, resolved = audit()

    if '--dump' in sys.argv:
        # Every resolved access, sorted. Refactors that only rename constants
        # must leave this byte-identical -- if a rename misses a reference the
        # name goes undefined, EEL2 reads it as 0, and the address silently
        # moves to the bottom of the map.
        for name, addr in sorted(resolved):
            print(f'{name} {addr}')
        for name, count in sorted(unresolved.items()):
            print(f'{name} UNRESOLVED x{count}')
        return 0


    if '--map' in sys.argv:
        print(f"{'REGION':<22}{'RANGE':<24}{'OWNER':<30}USED BY")
        for r in regions:
            rng = f"{r['start']}..{r['start']+r['size']-1}"
            users = ', '.join(sorted(hits.get(r['name'], ())) ) or '-'
            print(f"{r['name']:<22}{rng:<24}{r['owner']:<30}{users}")
        print()

    for p in problems:
        print('  ' + p)
    for addr in sorted(undeclared):
        print(f"  UNDECLARED: gmem[{addr}] used by {', '.join(sorted(undeclared[addr]))} "
              f"-- no @gmem region covers it")
    if unresolved:
        total = sum(unresolved.values())
        print(f"  note: {total} access(es) with a base this tool cannot resolve statically "
              f"({', '.join(f'{k}:{v}' for k, v in unresolved.most_common())})")

    bad = len(problems) + len(undeclared)
    print(f"\n{len(regions)} regions declared, "
          f"{'no problems' if not bad else str(bad) + ' problem(s)'}")
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
