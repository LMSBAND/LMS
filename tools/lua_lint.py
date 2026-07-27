#!/usr/bin/env python3
"""Catch Lua string literals that run off the end of their line.

Why this exists: a manager edit went out with a real newline inside a quoted
string instead of the two characters backslash-n. Lua stops at the line end and
reports "unfinished string", which in a ReaScript means the whole tool fails to
load -- and the failure surfaces on the user's machine, not here.

It got through because the syntax check in use (luaparser) accepts a newline
inside a short string. So the check that matters is not "does a parser accept
it" but this one specific, mechanical property, verified directly.

Lua's own rule: a short string, opened with ' or ", may not contain a raw
newline. Long strings ([[ ]]) may. Comments are skipped so an apostrophe in
prose -- "don't" -- is not read as an opening quote.

Usage: python tools/lua_lint.py [files...]   (defaults to scripts/*.lua)
Exit code 1 if anything is wrong, so it can gate a commit.
"""

import glob
import sys

NL = chr(10)
BACKSLASH = chr(92)


def check(path):
    """Returns a list of (line_number, message)."""
    with open(path, encoding="utf-8", newline="") as fh:
        src = fh.read()

    problems = []
    i, line, n = 0, 1, len(src)

    while i < n:
        ch = src[i]

        if ch == NL:
            line += 1
            i += 1
            continue

        # Long bracket, as a string or a comment body: [[ ... ]] / [==[ ... ]==]
        if ch == "[" or src.startswith("--[", i):
            j = i + 3 if src.startswith("--[", i) else i + 1
            eq = 0
            while j < n and src[j] == "=":
                eq += 1
                j += 1
            if j < n and src[j] == "[":
                close = "]" + "=" * eq + "]"
                end = src.find(close, j + 1)
                if end == -1:
                    problems.append((line, "long bracket never closed"))
                    break
                line += src.count(NL, i, end)
                i = end + len(close)
                continue

        # Line comment: everything to the end of the line, quotes and all.
        if src.startswith("--", i):
            end = src.find(NL, i)
            i = n if end == -1 else end
            continue

        # Short string: the case this tool exists for.
        if ch in "\"'":
            quote, j = ch, i + 1
            while j < n:
                c = src[j]
                if c == BACKSLASH:
                    # An escaped newline is legal Lua and continues the string.
                    if j + 1 < n and src[j + 1] == NL:
                        line += 1
                    j += 2
                    continue
                if c == NL:
                    problems.append((
                        line,
                        "unfinished string: a raw newline inside " + quote + "..." + quote
                        + " -- did a " + BACKSLASH + "n become a real line break?"))
                    break
                if c == quote:
                    break
                j += 1
            else:
                problems.append((line, "string never closed before end of file"))
                break
            if j < n and src[j] == NL:
                i = j          # resync at the newline; keep scanning the file
                continue
            i = j + 1
            continue

        i += 1

    return problems


def main(argv):
    paths = argv[1:] or sorted(glob.glob("scripts/*.lua"))
    if not paths:
        print("no Lua files found")
        return 1

    total = 0
    for path in paths:
        for line, msg in check(path):
            print(path + ":" + str(line) + ": " + msg)
            total += 1

    if total:
        print()
        print(str(total) + " problem(s) found")
        return 1

    print(str(len(paths)) + " Lua file(s) checked, no unfinished strings")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
