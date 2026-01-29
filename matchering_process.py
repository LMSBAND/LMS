#!/usr/bin/env python3
"""Matchering processor - called by the ReaScript as a subprocess."""

import sys
import os
import matchering as mg


def main():
    if len(sys.argv) < 4:
        print("Usage: matchering_process.py <target> <reference> <output>", file=sys.stderr)
        sys.exit(1)

    target = sys.argv[1]
    reference = sys.argv[2]
    output = sys.argv[3]

    for f in [target, reference]:
        if not os.path.isfile(f):
            print(f"File not found: {f}", file=sys.stderr)
            sys.exit(1)

    mg.log(print)

    mg.process(
        target=target,
        reference=reference,
        results=[
            mg.pcm24(output),
        ],
    )

    print(f"Done! Output saved to: {output}")


if __name__ == "__main__":
    main()
