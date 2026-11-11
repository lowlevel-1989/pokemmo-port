#!/bin/sh
# Runs test_shaderfix against libshaderfix. Works on the PC (x86_64 build) and on
# the console (aarch64 build).
#   test_shaderfix.sh <test_shaderfix bin> <libshaderfix.so> <data/shaders dir>
set -u
BIN="$1"; LIB="$2"; DATA="$3"
TMP="${TMPDIR:-/tmp}/shaderfix-test.$$"
mkdir -p "$TMP/data"
cp "$DATA"/*.glsl "$TMP/data/"
printf 'varying vec3 v_ambientLight;\r\nvoid main(){ gl_FragColor = vec4(v_ambientLight,1.0); }\r\n' > "$TMP/data/bad.fragment.glsl"

SHADERFIX_DATA="$TMP/data" SHADERFIX_DUMP="$TMP/dump" LD_PRELOAD="$LIB" "$BIN" "$TMP/data" 2> "$TMP/stderr"
rc=$?

fail=0
expect() {  # expect <description> <grep -E pattern>
  if grep -qE "$2" "$TMP/stderr"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi
}
expect "log: data shaders loaded"                  'shaders loaded from'
expect "log: WARNING for data file w/ ambient"     'WARNING: .*bad\.fragment\.glsl uses v_ambientLight'
expect "log: replaced by default.vertex"           'replaced by .*default\.vertex\.glsl'
expect "log: replaced by default.fragment"         'replaced by .*default\.fragment\.glsl'
expect "log: replaced by depth.vertex"             'replaced by .*depth\.vertex\.glsl'
expect "log: replaced by depth.fragment"           'replaced by .*depth\.fragment\.glsl'
expect "log: compile failure reported with log"    'GLX COMPILE FAILED for shader 7'
expect "log: driver error text shown"              'fake error'
n=$(ls "$TMP/dump" 2>/dev/null | grep -c '^GLX_[0-9a-f]')
m=$(ls "$TMP/dump" 2>/dev/null | grep -c '^EGL_')
r=$(ls "$TMP/dump" 2>/dev/null | grep -c '^GLX_replaced_')
[ "$n" -gt 0 ] && [ "$m" -gt 0 ] && [ "$r" -gt 0 ] && echo "PASS  dumps written (GLX=$n EGL=$m replaced=$r)" \
  || { echo "FAIL  dumps (GLX=$n EGL=$m replaced=$r)"; fail=1; }

if [ $rc -ne 0 ] || [ $fail -ne 0 ]; then
  echo "---- shaderfix stderr ----"; cat "$TMP/stderr"
  rm -rf "$TMP"; exit 1
fi
rm -rf "$TMP"
echo "ALL OK"
