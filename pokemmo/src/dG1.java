package f;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;

public class dG1 {

  public static String  aP = "";    // username
  public static String  bC0 = "";   // password
  public static boolean Lr = false; // auto

  static {
    System.out.println("---- LOAD HACK | HO ----");

    String path = System.getenv("GAMEDIR");

    try (BufferedReader reader = new BufferedReader(new FileReader(path + "/credentials.txt"))) {
      aP  = reader.readLine(); // username
      bC0 = reader.readLine(); // password
    } catch (IOException e) {
      e.printStackTrace();
    }
  }
}
