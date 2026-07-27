#!/usr/bin/env python3
"""Check every plugin is visible to the LMS Plugin Manager.

The manager identifies a plugin from the name REAPER displays, which comes
from the `desc:` line, by looking for a substring from JSFX_TO_TYPE or
DISPLAY_TO_TYPE. A plugin whose desc contains neither is invisible: it will
not appear in the Overview, cannot be followed or stolen from, and an amp
swapped to it seems to vanish.

Nothing enforces the link. Rename a plugin in its desc line and it silently
drops out of the manager, with no error anywhere. Six were missing when this
was written -- OJ 95 (desc says "OJ 95", the key said "oj95"), TOMASTEKNIK
(the reverse), PEQ4U and Kitty Kats Big Krush (desc bears no relation to the
key), Bluhm Send (renamed, key never added) and Bloody Glue (never had one).

Run after touching any desc: line or either lookup table.

Usage:  python tools/name_audit.py
Exit:   0 if every plugin resolves, 1 otherwise.
"""
import glob, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANAGER = os.path.join(ROOT, 'scripts', 'lms_manager.lua')


def table_keys(src, name):
    m = re.search(r'local %s = \{(.*?)\n\}' % name, src, re.S)
    if not m:
        sys.exit(f'{name} not found in the manager')
    return re.findall(r'\["([^"]+)"\]', m.group(1))


def main():
    src = open(MANAGER, encoding='utf-8', errors='replace').read()
    keys = table_keys(src, 'JSFX_TO_TYPE') + table_keys(src, 'DISPLAY_TO_TYPE')

    missing = []
    checked = 0
    for path in sorted(glob.glob(os.path.join(ROOT, 'lms_*.jsfx'))):
        text = open(path, encoding='utf-8', errors='replace').read()
        desc = re.search(r'^desc:(.*)$', text, re.M)
        if not desc:
            continue
        checked += 1
        # REAPER prefixes "JS: " and matching is done lowercased.
        shown = ('JS: ' + desc.group(1).strip()).lower()
        if not any(k in shown for k in keys):
            missing.append((os.path.basename(path), shown))

    for name, shown in missing:
        print(f'  INVISIBLE: {name}')
        print(f'             REAPER shows "{shown}"')
        print(f'             no JSFX_TO_TYPE or DISPLAY_TO_TYPE key matches it')

    print(f'\n{checked} plugins checked, '
          f'{"all resolve" if not missing else f"{len(missing)} invisible to the manager"}')
    return 1 if missing else 0


if __name__ == '__main__':
    sys.exit(main())
