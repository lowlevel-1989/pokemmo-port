package f;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;

public class HO {

  public static String  UW = ""; // user
  public static String  Vu = ""; // pass
  public static boolean iQ = false;

  static {
    System.out.println("---- LOAD HACK ----");

    String path = System.getenv("GAMEDIR");

    try (BufferedReader reader = new BufferedReader(new FileReader(path + "/credentials.txt"))) {
      UW = reader.readLine();
      Vu = reader.readLine();
    } catch (IOException e) {
      e.printStackTrace();
    }
  }
}
