package org.lwjgl.sdl;

import java.nio.IntBuffer;
import java.nio.ShortBuffer;
import java.nio.FloatBuffer;
import java.nio.ByteBuffer;
import java.nio.Buffer;
import java.nio.BufferOverflowException;
import java.nio.BufferUnderflowException;
import java.nio.ByteOrder;

/* Fake SDLJoystick implementation that always simulates "no joystick connected" */
public class SDLJoystick {
  public static final int SDL_JOYSTICK_TYPE_UNKNOWN = 0;
  public static final int SDL_JOYSTICK_AXIS_MAX = 32767;
  public static final int SDL_JOYSTICK_AXIS_MIN = -32768;

  public static class Functions {
    public static final long LockJoysticks = 0L;
    public static final long UnlockJoysticks = 0L;
    public static final long GetJoysticks = 0L;
    public static final long GetJoystickNameForID = 0L;
    public static final long OpenJoystick = 0L;
    // Add more if needed, all set to 0
  }

  public SDLJoystick() {
    // Constructor does nothing
  }

  public static void SDL_LockJoysticks() {
    // No operation
  }

  public static void SDL_UnlockJoysticks() {
    // No operation
  }

  public static boolean SDL_HasJoystick() {
    return false;
  }

  public static IntBuffer SDL_GetJoysticks() {
    return IntBuffer.allocate(0); // Empty buffer
  }

  public static String SDL_GetJoystickNameForID(int id) {
    return null;
  }

  public static int SDL_GetJoystickPlayerIndexForID(int id) {
    return -1; // Invalid
  }

  public static long SDL_OpenJoystick(int id) {
    return 0L; // Null pointer
  }

  public static boolean SDL_IsJoystickVirtual(int id) {
    return false;
  }

  public static boolean SDL_SetJoystickVirtualAxis(long joystick, int axis, short value) {
    return false;
  }

  public static boolean SDL_SetJoystickVirtualButton(long joystick, int button, boolean pressed) {
    return false;
  }

  public static short SDL_GetJoystickAxis(long joystick, int axis) {
    return 0;
  }

  public static byte SDL_GetJoystickHat(long joystick, int hat) {
    return 0;
  }

  public static boolean SDL_GetJoystickButton(long joystick, int button) {
    return false;
  }

  public static void SDL_CloseJoystick(long joystick) {
    // No-op
  }

  public static int SDL_GetJoystickConnectionState(long joystick) {
    return -1; // Invalid
  }

  public static boolean SDL_JoystickConnected(long joystick) {
    return false;
  }

  public static boolean SDL_GetJoystickAxisInitialState(long joystick, int axis, ShortBuffer buffer) {
    if (buffer != null && buffer.remaining() > 0) {
      buffer.put((short) 0);
    }
    return false;
  }

  public static int SDL_GetNumJoystickAxes(long joystick) {
    return 0;
  }

  public static int SDL_GetNumJoystickButtons(long joystick) {
    return 0;
  }

  public static int SDL_GetNumJoystickHats(long joystick) {
    return 0;
  }

  public static int SDL_GetJoystickTypeForID(int id) {
    return SDL_JOYSTICK_TYPE_UNKNOWN;
  }

  public static boolean SDL_DetachVirtualJoystick(int id) {
    return false;
  }

  public static boolean SDL_SetJoystickLED(long joystick, byte r, byte g, byte b) {
    return false;
  }

  public static boolean SDL_SendJoystickEffect(long joystick, ByteBuffer buffer) {
    return false;
  }

  public static boolean SDL_RumbleJoystick(long joystick, short lowFreq, short highFreq, int duration) {
    return false;
  }

  public static void SDL_UpdateJoysticks() {
    // No-op
  }

  public static boolean SDL_JoystickEventsEnabled() {
    return false;
  }

  public static void SDL_SetJoystickEventsEnabled(boolean enabled) {
    // No-op
  }
}
