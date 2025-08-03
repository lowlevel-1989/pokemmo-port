package f;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;

public class {class_name} {{

  public static String  {username} = "";
  public static String  {password} = "";
  public static boolean {auto}     = false;

  static {{
    System.out.println("---- LOAD HACK | HO ----");

    String path = System.getenv("GAMEDIR");

    try (BufferedReader reader = new BufferedReader(new FileReader(path + "/credentials.txt"))) {{
      {username} = reader.readLine();
      {password} = reader.readLine();
    }} catch (IOException e) {{
      e.printStackTrace();
    }}
  }}
}}
