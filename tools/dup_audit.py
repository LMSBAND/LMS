#!/usr/bin/env python3
"""Cross-file duplication audit for the published LMS JSFX suite.

Answers three questions with numbers instead of impressions:

  1. Which published plugins import lms_core.jsfx-inc, and how much of it do
     they actually call? A plugin that imports the core and then reimplements
     a biquad locally is the cheapest kind of win.
  2. Which function names are defined in more than one file? Same name, two
     bodies, is either a core candidate or a drift hazard -- fix one and the
     other keeps the bug.
  3. Which runs of code are byte-identical across two or more plugins? These
     are the raw material for anything that belongs in the core.

Scope is the ReaPack index, not the working tree: plugins deliberately left
out of the pack (Bloody Glue, PEQ4U) are not audited.

Usage:
    python tools/dup_audit.py [--min-run N] [--top N]
"""

import argparse
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INDEX = os.path.join(ROOT, "index.xml")
CORE = "lms_core.jsfx-inc"

COMMENT = re.compile(r"//.*$")
FUNC_DEF = re.compile(r"^\s*function\s+([A-Za-z_][A-Za-z0-9_.]*)\s*\(")
CORE_CALL = re.compile(r"\b(lms_[A-Za-z0-9_]+)\s*\(")
PKG = re.compile(r'<reapack name="([^"]+)" type="effect"')

# A run made only of these carries no information -- closing parens, loop
# scaffolding. Counted for continuity, but a run must hold more than these to
# be worth reporting.
TRIVIAL = re.compile(r"^[\s();,]*$|^\s*\)\s*;?\s*$|^\s*\(\s*$")


def published_effects():
    """The .jsfx the ReaPack actually ships, core excluded."""
    with open(INDEX, encoding="utf-8", errors="replace") as fh:
        names = PKG.findall(fh.read())
    return sorted(n for n in names if n.endswith(".jsfx"))


def normalize(path):
    """(normalized_line, original_lineno) with comments and blanks dropped."""
    out = []
    with open(path, encoding="utf-8", errors="replace") as fh:
        for n, raw in enumerate(fh, 1):
            line = COMMENT.sub("", raw).strip()
            if line:
                out.append((line, n))
    return out


def find_runs(files, norm, min_run):
    """Maximal runs of identical normalized lines shared across two files.

    Greedy and one-directional: each (file, line) is claimed by at most one
    reported run, so a block copied into five plugins reports once with five
    sites rather than ten times pairwise.
    """
    window = min_run
    index = defaultdict(list)
    for f in files:
        lines = [l for l, _ in norm[f]]
        for i in range(len(lines) - window + 1):
            index[tuple(lines[i:i + window])].append((f, i))

    claimed = defaultdict(set)
    runs = []
    for f in files:
        lines = [l for l, _ in norm[f]]
        i = 0
        while i <= len(lines) - window:
            if i in claimed[f]:
                i += 1
                continue
            sites = [(g, j) for g, j in index.get(tuple(lines[i:i + window]), [])
                     if g != f or j != i]
            others = [(g, j) for g, j in sites if g != f]
            if not others:
                i += 1
                continue

            # Extend the match as far as every partner site agrees.
            length = window
            while True:
                a = i + length
                if a >= len(lines):
                    break
                ok = []
                for g, j in others:
                    b = j + length
                    gl = [l for l, _ in norm[g]]
                    if b < len(gl) and gl[b] == lines[a]:
                        ok.append((g, j))
                if not ok:
                    break
                others = ok
                length += 1

            body = lines[i:i + length]
            if sum(0 if TRIVIAL.match(l) else 1 for l in body) >= max(4, window // 2):
                sites = [(f, i)] + others
                runs.append((length, sites))
                for g, j in sites:
                    claimed[g].update(range(j, j + length))
            i += length
    return runs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--min-run", type=int, default=10,
                    help="shortest identical run to report (normalized lines)")
    ap.add_argument("--top", type=int, default=25)
    args = ap.parse_args()

    effects = published_effects()
    if not effects:
        print("No effect packages found in index.xml", file=sys.stderr)
        return 1

    norm = {}
    raw_len = {}
    imports_core = {}
    core_calls = defaultdict(set)
    local_funcs = defaultdict(set)

    core_path = os.path.join(ROOT, CORE)
    core_defined = set()
    if os.path.exists(core_path):
        with open(core_path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                m = FUNC_DEF.match(line)
                if m:
                    core_defined.add(m.group(1))

    present = []
    for name in effects:
        path = os.path.join(ROOT, name)
        if not os.path.exists(path):
            print(f"  ! in index.xml but not in the tree: {name}")
            continue
        present.append(name)
        norm[name] = normalize(path)
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        raw_len[name] = text.count("\n") + 1
        imports_core[name] = bool(re.search(r"^\s*import\s+lms_core", text, re.M))
        for m in CORE_CALL.finditer(COMMENT.sub("", text)):
            if m.group(1) in core_defined:
                core_calls[name].add(m.group(1))
        for line in text.splitlines():
            m = FUNC_DEF.match(line)
            if m:
                local_funcs[name].add(m.group(1))

    print("=" * 72)
    print("CORE UPTAKE  (published effects, %d)" % len(present))
    print("=" * 72)
    print("%-32s %6s %7s %6s %6s" % ("plugin", "lines", "import", "uses", "own fn"))
    for name in sorted(present, key=lambda n: -raw_len[n]):
        print("%-32s %6d %7s %6d %6d" % (
            name, raw_len[name],
            "yes" if imports_core[name] else "NO",
            len(core_calls[name]), len(local_funcs[name])))

    print()
    print("=" * 72)
    print("SAME FUNCTION NAME, MORE THAN ONE FILE")
    print("=" * 72)
    owners = defaultdict(list)
    for name, fns in local_funcs.items():
        for fn in fns:
            owners[fn].append(name)
    dupes = {fn: fs for fn, fs in owners.items() if len(fs) > 1}
    if not dupes:
        print("  (none)")
    for fn in sorted(dupes, key=lambda f: -len(dupes[f])):
        also = " also in core" if fn in core_defined else ""
        print("  %-28s %d files%s" % (fn, len(dupes[fn]), also))
        print("      " + ", ".join(sorted(dupes[fn])))

    print()
    print("=" * 72)
    print("IDENTICAL RUNS ACROSS PLUGINS  (>= %d normalized lines)" % args.min_run)
    print("=" * 72)
    runs = find_runs(present, norm, args.min_run)
    runs.sort(key=lambda r: -(r[0] * len(r[1])))
    total = 0
    for length, sites in runs[:args.top]:
        total += length * (len(sites) - 1)
        f0, i0 = sites[0]
        head = norm[f0][i0][0][:58]
        print("\n  %d lines x %d files  (%d duplicated)  first: %s" % (
            length, len(sites), length * (len(sites) - 1), head))
        for g, j in sorted(sites):
            print("      %s:%d" % (g, norm[g][j][1]))
    dup_all = sum(l * (len(s) - 1) for l, s in runs)
    print("\n  %d runs found; %d normalized lines are copies "
          "(%d shown above)" % (len(runs), dup_all, total))
    return 0


if __name__ == "__main__":
    sys.exit(main())
