#!/usr/bin/env python3
"""Entry point used by both platform launchers."""
import sys

sys.dont_write_bytecode = True
for stream in (sys.stdout, sys.stderr):
    if hasattr(stream, "reconfigure"):
        stream.reconfigure(encoding="utf-8", errors="replace")
from dotfiles.cli import main

if __name__ == '__main__':
    raise SystemExit(main())
