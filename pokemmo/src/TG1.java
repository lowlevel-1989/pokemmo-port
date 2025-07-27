package f;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;

public class TG1 {

  public static String  fD1 = "";    // username
  public static String  rw  = "";   // password
  public static boolean rH  = false; // auto

  static {
    System.out.println("---- LOAD HACK | HO ----");

    String path = System.getenv("GAMEDIR");

    try (BufferedReader reader = new BufferedReader(new FileReader(path + "/credentials.txt"))) {
      fD1  = reader.readLine(); // username
      rw   = reader.readLine(); // password
    } catch (IOException e) {
      e.printStackTrace();
    }
  }
}
