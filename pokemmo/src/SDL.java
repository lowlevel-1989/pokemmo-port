package org.lwjgl.sdl;

import org.lwjgl.system.Configuration;
import org.lwjgl.system.Library;
import org.lwjgl.system.Platform;
import org.lwjgl.system.SharedLibrary;

public final class SDL {
  private static final SharedLibrary SDL = Library.loadNative(SDL.class, "org.lwjgl.sdl", "SDL2", true);

  public static SharedLibrary getLibrary() {
    return SDL;
  }

  private SDL() {
    throw new UnsupportedOperationException();
  }
}
