#!/usr/bin/env python3
"""
BusyBox's `unzip` (used by ROCKNIX and some other CFWs) fails with
"unzip: short read" on some entries inside patch.zip / PokeMMO.exe,
which silently truncates extraction and breaks the build pipeline
downstream (empty javap dumps, missing classes, failed loader.jar).

usage: pmzipextract.py [--progress] <zipfile> <destdir> [prefix ...]

--progress prints launch_menu trace directives (@STATUS / @PROGRESS),
flushed immediately so the menu can show them in real time.
"""
import os
import sys
import zipfile


def main():
    args = sys.argv[1:]
    progress = "--progress" in args
    args = [a for a in args if a != "--progress"]

    if len(args) < 2:
        print("usage: pmzipextract.py [--progress] <zipfile> <destdir> [prefix ...]", file=sys.stderr)
        return 1

    zip_path, dest_dir, prefixes = args[0], args[1], args[2:]
    os.makedirs(dest_dir, exist_ok=True)

    try:
        with zipfile.ZipFile(zip_path) as zf:
            infos = zf.infolist()
            if prefixes:
                infos = [i for i in infos if any(i.filename.startswith(p) for p in prefixes)]

            total = len(infos) or 1
            last_pct = -1
            if progress:
                print(f"@STATUS Extracting {os.path.basename(zip_path)} ({len(infos)} files)", flush=True)

            for n, info in enumerate(infos, 1):
                zf.extract(info, dest_dir)
                mode = (info.external_attr >> 16) & 0xFFFF
                if mode:
                    try:
                        os.chmod(os.path.join(dest_dir, info.filename), mode)
                    except OSError:
                        pass

                if progress:
                    pct = n * 100 // total
                    if pct != last_pct:
                        last_pct = pct
                        print(f"@PROGRESS {pct}", flush=True)
    except (zipfile.BadZipFile, OSError) as e:
        print(f"__ERROR__ {os.path.basename(zip_path)}: {e}", flush=True)
        return 1

    print(f"[pmzipextract] extracted {len(infos)} entries from {zip_path} -> {dest_dir}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
