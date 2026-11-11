#!/usr/bin/env bash
# PokeMMO port - dev helper: build, deploy to a console, run, collect logs.
#
#   tools/dev.sh build [shaderfix|menu|all]   cross-build aarch64 (podman/docker + qemu)
#   tools/dev.sh deploy                        copy launcher, libs, menu, shaders to console
#   tools/dev.sh run [menu-index]              launch the port on the console (default 0 = PokeMMO)
#   tools/dev.sh stop                          kill the game on the console
#   tools/dev.sh logs [-f]                     show console log.txt (shaderfix lines highlighted)
#   tools/dev.sh dumps                         pull shaderfix_dump/ from the console
#   tools/dev.sh test [menu-index] [secs]      build + deploy + run + wait + report
#   tools/dev.sh unittest [host|console|all]   test shaderfix detection/replacement with fake shaders
#   tools/dev.sh restore                       put back the files saved before the first deploy
#   tools/dev.sh shell [cmd...]                ssh into the console
#   tools/dev.sh zip                           run make_zip_autoinstall.sh
#   tools/dev.sh pr-sync                       copy port files into the PortMaster checkout
#                                              (working tree only: no git add/commit/push)
#
# Environment:
#   CONSOLE_HOST  (default 192.168.1.157)   CONSOLE_USER (default root)
#   CONSOLE_PASS  (default rocknix, only used when no SSH key is accepted)
#   CONSOLE_PORTS (default /storage/roms/ports)
#   PM_REPO       (default ~/repos/PortMaster-MV-New)
#   CONTAINER     (podman|docker, auto)
#   BUILD_IMAGE   (default docker.io/library/ubuntu:18.04 -> glibc 2.27, binaries need GLIBC_2.17)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME="$ROOT/pokemmo"
HOST="${CONSOLE_HOST:-192.168.1.157}"
USER_="${CONSOLE_USER:-root}"
PASS="${CONSOLE_PASS:-rocknix}"
PORTS="${CONSOLE_PORTS:-/storage/roms/ports}"
RGAME="$PORTS/pokemmo"
PM_REPO="${PM_REPO:-$HOME/repos/PortMaster-MV-New}"
BUILD_IMAGE="${BUILD_IMAGE:-docker.io/library/ubuntu:18.04}"
BUILDER_TAG="localhost/pokemmo-port-builder:arm64"
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}/pokemmo-dev"
mkdir -p "$RUNTIME"; chmod 700 "$RUNTIME"

c_info() { printf '\033[1;36m==> %s\033[0m\n' "$*"; }
c_ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
c_err()  { printf '\033[1;31m✘ %s\033[0m\n' "$*" >&2; }

# ---------------------------------------------------------------- ssh
# One shared master connection (ControlMaster) -> password asked at most once.
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o LogLevel=ERROR -o ConnectTimeout=8
          -o ControlMaster=auto -o "ControlPath=$RUNTIME/ssh-%r@%h" -o ControlPersist=120)

ssh_ready() {
  ssh "${SSH_OPTS[@]}" -O check "$USER_@$HOST" 2>/dev/null && return 0
  # 1) key auth
  if ssh "${SSH_OPTS[@]}" -o BatchMode=yes -fN "$USER_@$HOST" 2>/dev/null; then return 0; fi
  # 2) password via SSH_ASKPASS (no sshpass needed); password never hits the command line
  local ap="$RUNTIME/askpass.sh"
  printf '#!/bin/sh\nprintf "%%s\\n" "$POKEMMO_DEV_PASS"\n' > "$ap"; chmod 700 "$ap"
  POKEMMO_DEV_PASS="$PASS" SSH_ASKPASS="$ap" SSH_ASKPASS_REQUIRE=force \
    setsid -w ssh "${SSH_OPTS[@]}" -o PubkeyAuthentication=no -fN "$USER_@$HOST" </dev/null \
    || { c_err "cannot connect to $USER_@$HOST"; exit 1; }
}
rsh()   { ssh_ready; ssh "${SSH_OPTS[@]}" "$USER_@$HOST" "$@"; }
rsync_to() { ssh_ready; rsync -rlt --chmod=u+rwx,go+rx -e "ssh ${SSH_OPTS[*]}" "$@"; }

# ---------------------------------------------------------------- build
container() {
  if [ -n "${CONTAINER:-}" ]; then echo "$CONTAINER"
  elif command -v podman >/dev/null; then echo podman
  elif command -v docker >/dev/null; then echo docker
  else c_err "podman or docker required"; exit 1; fi
}

builder_image() {
  local ce; ce=$(container)
  if ! $ce image exists "$BUILDER_TAG" 2>/dev/null && ! $ce image inspect "$BUILDER_TAG" >/dev/null 2>&1; then
    c_info "creating builder image $BUILDER_TAG from $BUILD_IMAGE (one time)"
    printf 'FROM %s\nRUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gcc libc6-dev make libsdl2-dev libsdl2-ttf-dev binutils && rm -rf /var/lib/apt/lists/*\n' "$BUILD_IMAGE" \
      | $ce build --platform linux/arm64 -t "$BUILDER_TAG" -f - "$RUNTIME"
  fi
}

in_builder() {
  local ce; ce=$(container)
  builder_image
  $ce run --rm --platform linux/arm64 -v "$GAME":/src:Z -w /src "$BUILDER_TAG" sh -ec "$1"
}

check_glibc() {
  local need; need=$(objdump -T "$1" | grep -oE 'GLIBC_2\.[0-9]+' | sort -Vu | tail -1)
  echo "   $(basename "$1"): needs ${need:-none}"
}

SYSROOT="${SYSROOT:-$HOME/.cache/pokemmo-port/sysroot-arm64}"
CROSS_CC="${CROSS_CC:-aarch64-linux-gnu-gcc}"
CROSS_STRIP="${CROSS_STRIP:-aarch64-linux-gnu-strip}"

# fast path: native cross compiler + sysroot (tools/mksysroot.sh)
cmd_build_cross() {
  local what="$1"
  command -v "$CROSS_CC" >/dev/null || { c_err "$CROSS_CC not found (dnf install gcc-aarch64-linux-gnu)"; exit 1; }
  [ -f "$SYSROOT/usr/include/SDL2/SDL.h" ] || "$ROOT/tools/mksysroot.sh" "$SYSROOT"
  local S="$SYSROOT" L="$SYSROOT/usr/lib/aarch64-linux-gnu"
  # Fedora's gcc spec always adds -latomic_asneeded, which a cross toolchain lacks: empty stub
  [ -f "$S/stubs/libatomic_asneeded.a" ] || { mkdir -p "$S/stubs"; aarch64-linux-gnu-ar rc "$S/stubs/libatomic_asneeded.a"; }
  local CF=(--sysroot="$S" -isystem "$S/usr/include/aarch64-linux-gnu" -O2 -Wall -Wextra)
  local LF=(--sysroot="$S" -B"$L" -L"$L" -L"$S/stubs" -L"$S/lib/aarch64-linux-gnu"
            -Wl,-rpath-link,"$L":"$S/lib/aarch64-linux-gnu" -Wl,--allow-shlib-undefined)
  if [[ $what == all || $what == shaderfix ]]; then
    c_info "building libshaderfix.aarch64.so ($CROSS_CC)"
    "$CROSS_CC" "${CF[@]}" -shared -fPIC -o "$GAME/libshaderfix.aarch64.so" "$GAME/shaderfix.c" "${LF[@]}" -ldl
    "$CROSS_STRIP" "$GAME/libshaderfix.aarch64.so"
    check_glibc "$GAME/libshaderfix.aarch64.so"
  fi
  if [[ $what == all || $what == menu ]]; then
    c_info "building menu/launch_menu.aarch64 ($CROSS_CC)"
    "$CROSS_CC" "${CF[@]}" -I"$S/usr/include/SDL2" -D_REENTRANT \
      -o "$GAME/menu/launch_menu.aarch64" "$GAME/menu/launch_menu.c" "${LF[@]}" -lSDL2 -lSDL2_ttf
    "$CROSS_STRIP" "$GAME/menu/launch_menu.aarch64"
    check_glibc "$GAME/menu/launch_menu.aarch64"
  fi
  c_ok "build done"
}

cmd_build() {
  local what="${1:-all}"
  [ "${BUILD_MODE:-cross}" = cross ] && { cmd_build_cross "$what"; return; }
  if [[ $what == all || $what == shaderfix ]]; then
    c_info "building libshaderfix.aarch64.so"
    in_builder 'gcc -O2 -Wall -Wextra -shared -fPIC -o libshaderfix.aarch64.so shaderfix.c -ldl && strip libshaderfix.aarch64.so'
    check_glibc "$GAME/libshaderfix.aarch64.so"
  fi
  if [[ $what == all || $what == menu ]]; then
    c_info "building menu/launch_menu.aarch64"
    in_builder 'cd menu && gcc -O2 -Wall -Wextra $(sdl2-config --cflags) -o launch_menu.aarch64 launch_menu.c $(sdl2-config --libs) -lSDL2_ttf && strip launch_menu.aarch64'
    check_glibc "$GAME/menu/launch_menu.aarch64"
  fi
  c_ok "build done"
}

# ---------------------------------------------------------------- deploy
DEPLOY_FILES=(
  libshaderfix.aarch64.so
  menu/launch_menu.aarch64
  menu/launch_menu.c
  pmzipextract.py
  RELEASE
)

cmd_deploy() {
  for f in "${DEPLOY_FILES[@]}"; do
    [ -e "$GAME/$f" ] || { c_err "missing $f (run: tools/dev.sh build)"; exit 1; }
  done
  rsh "test -d '$RGAME'" || { c_err "$RGAME not found on console (install the port first)"; exit 1; }

  c_info "backup of original console files (only the first time)"
  rsh "set -e; B='$RGAME/.devbackup'; if [ ! -d \"\$B\" ]; then mkdir -p \"\$B/menu\" \"\$B/data\";
       cp -a '$PORTS/PokeMMO.sh' \"\$B/\"; cd '$RGAME';
       for f in ${DEPLOY_FILES[*]}; do [ -e \"\$f\" ] && cp -a \"\$f\" \"\$B/\$f\" || true; done;
       [ -d data/shaders ] && cp -a data/shaders \"\$B/data/\" || true; echo saved in \$B; fi"

  c_info "deploying to $HOST:$RGAME"
  rsync_to "$ROOT/PokeMMO.sh" "$USER_@$HOST:$PORTS/PokeMMO.sh"
  (cd "$GAME" && rsync_to -R "${DEPLOY_FILES[@]}" "$USER_@$HOST:$RGAME/")
  rsync_to "$GAME/data/shaders/" "$USER_@$HOST:$RGAME/data/shaders/"
  rsh "chmod +x '$PORTS/PokeMMO.sh' '$RGAME/menu/launch_menu.aarch64'; cat '$RGAME/RELEASE'"
  c_ok "deployed"
}

cmd_restore() {
  c_info "restoring files from $RGAME/.devbackup"
  rsh "set -e; B='$RGAME/.devbackup'; [ -d \"\$B\" ] || { echo 'no backup'; exit 1; }
       cp -a \"\$B/PokeMMO.sh\" '$PORTS/PokeMMO.sh'; cd \"\$B\";
       for f in ${DEPLOY_FILES[*]}; do [ -e \"\$f\" ] && cp -a \"\$f\" '$RGAME/'\"\$f\" || rm -f '$RGAME/'\"\$f\"; done;
       [ -d data/shaders ] && { rm -rf '$RGAME/data/shaders'; cp -a data/shaders '$RGAME/data/'; } || true"
  c_ok "restored (backup kept in $RGAME/.devbackup)"
}

# ---------------------------------------------------------------- run
cmd_stop() {
  # [x]yz patterns never match this remote shell's own command line
  rsh 'pids=$(ps -eo pid,args | grep -E "[P]okeMMO|[l]aunch_menu|[g]ptokeyb|[w]estonwrap|[w]p_weston|[X]wayland" | awk "{print \$1}");
       [ -n "$pids" ] && kill $pids 2>/dev/null; sleep 2;
       pids=$(ps -eo pid,args | grep -E "[P]okeMMO|[l]aunch_menu|[g]ptokeyb|[w]estonwrap|[w]p_weston|[X]wayland" | awk "{print \$1}");
       [ -n "$pids" ] && kill -9 $pids 2>/dev/null; echo stopped' || true
}

# Runs PokeMMO.sh like EmulationStation does: same environment as the ES process
# (WAYLAND_DISPLAY, XDG_RUNTIME_DIR, SDL_*...), detached, output in log.txt.
cmd_run() {
  local sel="${1:-0}"
  c_info "launching port on console (menu option $sel)"
  rsh "set -e
    ES=\$(pidof emulationstation | cut -d' ' -f1 || true)
    ENVF=/tmp/pokemmo-dev.env
    if [ -n \"\$ES\" ]; then tr '\0' '\n' < /proc/\$ES/environ | grep -E '^(WAYLAND_DISPLAY|XDG_RUNTIME_DIR|SDL_|DISPLAY|HOME|PATH|LANG|SWAYSOCK|DBUS)' | sed 's/^/export /; s/=/=\"/; s/\$/\"/' > \$ENVF; else : > \$ENVF; fi
    cd '$PORTS'
    nohup sh -c \". \$ENVF; export LAUNCH_MENU_AUTOSELECT=$sel SHADERFIX_DUMP='$RGAME/shaderfix_dump'; exec bash ./PokeMMO.sh\" >/tmp/pokemmo-dev.out 2>&1 </dev/null &
    echo started pid \$!"
}

cmd_logs() {
  if [[ ${1:-} == -f ]]; then
    rsh "tail -n 50 -F '$RGAME/log.txt'" | grep --line-buffered --color=always -E 'shaderfix|COMPILE FAILED|ERROR|WARNING|$'
  else
    rsh "cat '$RGAME/log.txt'" | grep --color=always -E 'shaderfix|COMPILE FAILED|ERROR|WARNING|$'
  fi
}

cmd_dumps() {
  local out="$ROOT/shaderfix_dump"
  mkdir -p "$out"
  ssh_ready
  rsync -rt -e "ssh ${SSH_OPTS[*]}" "$USER_@$HOST:$RGAME/shaderfix_dump/" "$out/" && c_ok "dumps in $out" \
    || c_err "no dumps yet"
}

# Summary of what shaderfix did in the last run
report() {
  local log="$RUNTIME/last-log.txt"
  rsh "cat '$RGAME/log.txt'" > "$log" || true
  echo
  c_info "report ($(wc -l < "$log") log lines, full log: $log)"
  grep -E 'OpenGL renderer|OpenGL version' "$log" | head -2 | sed 's/^.*\] //'
  grep -E 'WESTOMPACK|SHADERFIX ' "$log" | head -2
  local loaded replaced failed warn
  loaded=$(grep -c 'shaders loaded from' "$log" || true)
  replaced=$(grep -c ': replaced by' "$log" || true)
  failed=$(grep -c 'COMPILE FAILED' "$log" || true)
  warn=$(grep -c '\[shaderfix\] WARNING' "$log" || true)
  echo "   shaderfix loaded: $loaded  replaced: $replaced  compile failures: $failed  warnings: $warn"
  grep -E '\[shaderfix\] (shader .*replaced|WARNING|.*COMPILE FAILED)' "$log" | sort | uniq -c | head -20
  if grep -q 'COMPILE FAILED' "$log"; then
    c_err "compile errors:"; grep -A6 'COMPILE FAILED' "$log" | head -40
  fi
  if grep -vE '^rm:' "$log" | grep -qE 'hs_err_pid[0-9]|Exception|SIGSEGV'; then
    c_err "java errors:"; grep -vE '^rm:' "$log" | grep -E 'hs_err_pid[0-9]|Exception|SIGSEGV' | head -10
  fi
  [ "$loaded" -gt 0 ] && [ "$failed" -eq 0 ] && c_ok "no shader compile errors" || true
}

cmd_test() {
  local sel="${1:-0}" secs="${2:-60}"
  cmd_build all
  cmd_deploy
  cmd_stop >/dev/null
  rsh "rm -rf '$RGAME/shaderfix_dump'"
  cmd_run "$sel"
  c_info "waiting ${secs}s for the game to start"
  local t=0
  while [ $t -lt "$secs" ]; do
    sleep 5; t=$((t + 5))
    if rsh "grep -q 'COMPILE FAILED\|World Shader Bones' '$RGAME/log.txt' 2>/dev/null"; then sleep 5; break; fi
    printf '.'
  done
  report
  [ "${KEEP_RUNNING:-0}" = 1 ] || { c_info "stopping game (KEEP_RUNNING=1 to leave it running)"; cmd_stop >/dev/null; }
}

# ---------------------------------------------------------------- unit test
# Feeds fake shaders through the real hook (no game needed). [host|console|all]
cmd_unittest() {
  local where="${1:-all}" out="$RUNTIME/unittest" rc=0
  mkdir -p "$out"
  if [[ $where == all || $where == host ]]; then
    c_info "shaderfix unit test on this PC ($(uname -m))"
    gcc -O2 -Wall -Wextra -shared -fPIC -o "$out/libshaderfix.host.so" "$GAME/shaderfix.c" -ldl
    gcc -O1 -Wall -Wextra -rdynamic -o "$out/test_shaderfix.host" "$ROOT/tools/test_shaderfix.c" -ldl
    TMPDIR="$out" sh "$ROOT/tools/test_shaderfix.sh" "$out/test_shaderfix.host" "$out/libshaderfix.host.so" "$GAME/data/shaders" || rc=1
  fi
  if [[ $where == all || $where == console ]]; then
    c_info "shaderfix unit test on the console (aarch64, real glibc)"
    [ -f "$GAME/libshaderfix.aarch64.so" ] || cmd_build shaderfix
    local S="$SYSROOT" L="$SYSROOT/usr/lib/aarch64-linux-gnu"
    "$CROSS_CC" --sysroot="$S" -isystem "$S/usr/include/aarch64-linux-gnu" -O1 -rdynamic \
      -o "$out/test_shaderfix.aarch64" "$ROOT/tools/test_shaderfix.c" \
      -B"$L" -L"$L" -L"$S/lib/aarch64-linux-gnu" -L"$S/stubs" -ldl
    rsh "mkdir -p /tmp/shaderfix-unittest"
    rsync_to "$out/test_shaderfix.aarch64" "$ROOT/tools/test_shaderfix.sh" "$GAME/libshaderfix.aarch64.so" \
      "$USER_@$HOST:/tmp/shaderfix-unittest/"
    rsync_to "$GAME/data/shaders/" "$USER_@$HOST:/tmp/shaderfix-unittest/shaders/"
    rsh "cd /tmp/shaderfix-unittest && TMPDIR=/tmp/shaderfix-unittest sh test_shaderfix.sh ./test_shaderfix.aarch64 ./libshaderfix.aarch64.so ./shaders; r=\$?; rm -rf /tmp/shaderfix-unittest; exit \$r" || rc=1
  fi
  [ $rc -eq 0 ] && c_ok "unit tests passed" || { c_err "unit tests failed"; return 1; }
}

# ---------------------------------------------------------------- packaging
cmd_zip() { (cd "$ROOT" && ./make_zip_autoinstall.sh); }

cmd_pr_sync() {
  local dst="$PM_REPO/ports/pokemmo"
  [ -d "$dst" ] || { c_err "$dst not found"; exit 1; }
  c_info "copying to $dst (working tree only)"
  cp -v "$ROOT/PokeMMO.sh" "$dst/PokeMMO.sh"
  (cd "$GAME" && rsync -Rv "${DEPLOY_FILES[@]}" shaderfix.c "$dst/pokemmo/")
  [ -f "$GAME/patch.zip" ] && cp -v "$GAME/patch.zip" "$dst/pokemmo/patch.zip"
  git -C "$PM_REPO" status --short -- ports/pokemmo
  c_ok "review with: git -C $PM_REPO diff -- ports/pokemmo   (nothing was committed)"
}

# ---------------------------------------------------------------- main
cmd="${1:-help}"; shift || true
case "$cmd" in
  build)   cmd_build "$@";;
  deploy)  cmd_deploy;;
  run)     cmd_run "$@";;
  stop)    cmd_stop;;
  logs)    cmd_logs "$@";;
  dumps)   cmd_dumps;;
  report)  report;;
  test)    cmd_test "$@";;
  unittest) cmd_unittest "$@";;
  restore) cmd_restore;;
  shell)   if [ $# -gt 0 ]; then rsh "$@"; else ssh_ready; ssh "${SSH_OPTS[@]}" -t "$USER_@$HOST"; fi;;
  zip)     cmd_zip;;
  pr-sync) cmd_pr_sync;;
  *)       sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//';;
esac
