#!/bin/bash

set -e

cd pokemmo

rm -f patch.zip
# only the folders that exist (libs/src are optional)
zip -r patch.zip $(for d in config data libs src; do [ -e "$d" ] && echo "$d"; done)

cd ..

rm -f pokemmo.zip
zip -r pokemmo.zip . \
  -x '.git/*' \
     'README.md' \
     'make_zip_autoinstall.sh' \
     'test/*' \
     'tools/*' \
     'shaderfix_dump/*' \
     'pokemmo/shaderfix_dump/*' \
     '.gitignore' \
     'docs/*' \
     'build/*' \
     'pokemmo/data/*' \
     'pokemmo/libs/*' \
     'pokemmo/build.sh' \
     'pokemmo/f/*' \
     'pokemmo/com/*' \
     'pokemmo/PokeMMO.exe'
