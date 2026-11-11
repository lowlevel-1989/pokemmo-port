#!/usr/bin/env bash
# Builds an aarch64 sysroot (Ubuntu 18.04 / glibc 2.27 + SDL2 + SDL2_ttf) without
# containers: downloads the .deb files from ports.ubuntu.com and unpacks them.
# Old glibc on purpose: the binaries then only need GLIBC_2.17 and run on every CFW.
#
#   tools/mksysroot.sh [dest]     (default ~/.cache/pokemmo-port/sysroot-arm64)
set -euo pipefail

DEST="${1:-${SYSROOT:-$HOME/.cache/pokemmo-port/sysroot-arm64}}"
MIRROR="${UBUNTU_PORTS:-http://ports.ubuntu.com/ubuntu-ports}"
DIST=bionic
PKGS=(libc6 libc6-dev linux-libc-dev
      libsdl2-2.0-0 libsdl2-dev
      libsdl2-ttf-2.0-0 libsdl2-ttf-dev)

WORK="$(dirname "$DEST")/sysroot-work"
mkdir -p "$WORK/debs" "$WORK/idx"

echo "==> package indexes"
for suite in "$DIST" "$DIST-updates" "$DIST-security"; do
  for comp in main universe; do
    f="$WORK/idx/$suite-$comp"
    [ -s "$f" ] || curl -fsSL "$MIRROR/dists/$suite/$comp/binary-arm64/Packages.gz" | gunzip > "$f"
  done
done

# newest Filename for a package across all indexes (updates/security listed last win)
find_deb() {
  awk -v p="$1" '
    /^Package: / { pkg = $2 }
    /^Filename: / && pkg == p { file = $2 }
    END { print file }' "$WORK"/idx/"$DIST"-main "$WORK"/idx/"$DIST"-universe \
                       "$WORK"/idx/"$DIST"-updates-* "$WORK"/idx/"$DIST"-security-*
}

rm -rf "$DEST.tmp"; mkdir -p "$DEST.tmp"
for p in "${PKGS[@]}"; do
  file="$(find_deb "$p")"
  [ -n "$file" ] || { echo "package $p not found" >&2; exit 1; }
  deb="$WORK/debs/$(basename "$file")"
  [ -s "$deb" ] || { echo "  get $(basename "$file")"; curl -fsSL "$MIRROR/$file" -o "$deb"; }
  # a .deb is an ar archive with data.tar.{xz,gz,zst}
  d="$WORK/x"; rm -rf "$d"; mkdir -p "$d"
  (cd "$d" && ar x "$deb")
  tar -xf "$d"/data.tar.* -C "$DEST.tmp"
done
rm -rf "$WORK/x"

# absolute symlinks -> relative to the sysroot (libc.so -> /lib/... etc.)
find "$DEST.tmp" -type l | while read -r l; do
  t="$(readlink "$l")"
  case "$t" in /*) ln -sfn "$(realpath -m --relative-to="$(dirname "$l")" "$DEST.tmp$t")" "$l";; esac
done
# libc.so / libpthread.so linker scripts use absolute paths: --sysroot handles them

rm -rf "$DEST"; mv "$DEST.tmp" "$DEST"
echo "==> sysroot ready: $DEST"
