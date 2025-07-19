javac -d out/ src/*.java
jar cf hack.jar   -C out f
jar cf loader.jar -C out org
rm -rf out
