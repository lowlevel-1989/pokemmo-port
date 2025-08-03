package org.lwjgl.util.tinyfd;


public class TinyFileDialogs {

    /** Contains tinyfd current version number. */
    public static final String tinyfd_version = "tinyfd_version";

    /** Contains info about requirements. */
    public static final String tinyfd_needs = "tinyfd_needs";

    public static final String tinyfd_response = "tinyfd_response";

    public static final String tinyfd_verbose = "tinyfd_verbose";

    public static final String tinyfd_silent = "tinyfd_silent";

    public static final String tinyfd_allowCursesDialogs = "tinyfd_allowCursesDialogs";

    public static final String tinyfd_forceConsole = "tinyfd_forceConsole";

    public static final String tinyfd_assumeGraphicDisplay = "tinyfd_assumeGraphicDisplay";

    public static final String tinyfd_winUtf8 = "tinyfd_winUtf8";

    protected TinyFileDialogs() {
        throw new UnsupportedOperationException();
    }

    public static boolean tinyfd_messageBox(CharSequence a, CharSequence b, CharSequence c, CharSequence d, boolean e) {
      return true;
    }

    public static String tinyfd_getGlobalChar(CharSequence a) {
      return "";
    }

}
