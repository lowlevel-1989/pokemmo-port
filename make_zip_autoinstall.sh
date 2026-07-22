#!/bin/bash

set -e

cd pokemmo

rm -f patch.zip
zip -r patch.zip config data libs src

cd ..

rm -f pokemmo.zip
zip -r pokemmo.zip . \
  -x '.git/*' \
     'README.md' \
     'make_zip_autoinstall.sh' \
     'test/*' \
     '.gitignore' \
     'docs/*' \
     'build/*' \
     'pokemmo/data/*' \
     'pokemmo/libs/*' \
     'pokemmo/build.sh' \
     'pokemmo/f/*' \
     'pokemmo/com/*' \
     'pokemmo/PokeMMO.exe'
