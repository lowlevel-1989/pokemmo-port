javac -d out/ -cp "f.jar:libs/*" src/*.java src/auto/*.java
cp -r src/com out
jar cf loader.jar -C out org -C out com -C out f
rm -rf out
