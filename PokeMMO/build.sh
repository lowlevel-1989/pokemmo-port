javac -d out/ src/*.java
cp -r src/com out
jar cf hack.jar -C out .
rm -rf out
