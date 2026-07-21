#!/usr/bin/env python3
"""
BusyBox's `unzip` (used by ROCKNIX and some other CFWs) fails with
"unzip: short read" on some entries inside patch.zip / PokeMMO.exe,
which silently truncates extraction and breaks the build pipeline
downstream (empty javap dumps, missing classes, failed loader.jar).
"""
import os
import sys
import zipfile
import stat


def main():
    if len(sys.argv) < 3:
        print("usage: pmzipextract.py <zipfile> <destdir> [prefix ...]", file=sys.stderr)
        return 1

    zip_path = sys.argv[1]
    dest_dir = sys.argv[2]
    prefixes = sys.argv[3:]

    os.makedirs(dest_dir, exist_ok=True)

    with zipfile.ZipFile(zip_path) as zf:
        names = zf.namelist()
        if prefixes:
            names = [n for n in names if any(n.startswith(p) for p in prefixes)]

        for name in names:
            zf.extract(name, dest_dir)

            info = zf.getinfo(name)
            mode = (info.external_attr >> 16) & 0xFFFF
            if mode:
                target = os.path.join(dest_dir, name)
                try:
                    os.chmod(target, mode)
                except OSError:
                    pass

    print(f"[pmzipextract] extracted {len(names)} entries from {zip_path} -> {dest_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
