javac -d out/ src/*.java
jar cf hack.jar -C out .
rm -rf out
