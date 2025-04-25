javac -d out/ src/HO.java
jar cf hack.jar -C out .
rm -rf out
