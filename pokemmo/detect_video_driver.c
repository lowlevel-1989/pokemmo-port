// gcc -o detect_video_driver detect_video_driver.c `sdl2-config --cflags --libs` -lGLESv2

#include <stdio.h>
#include <string.h>
#include <SDL2/SDL.h>
#include <GLES2/gl2.h>

int main() {
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        printf("SDL Init Error: %s\n", SDL_GetError());
        return 3;
    }

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);

    SDL_Window *window = SDL_CreateWindow("Detect Driver",
                                          0, 0, 1, 1,
                                          SDL_WINDOW_OPENGL | SDL_WINDOW_HIDDEN);
    if (!window) {
        printf("SDL Window Error: %s\n", SDL_GetError());
        SDL_Quit();
        return 3;
    }

    SDL_GLContext context = SDL_GL_CreateContext(window);
    if (!context) {
        printf("SDL Context Error: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 3;
    }

    const char *vendor = (const char*)glGetString(GL_VENDOR);
    const char *renderer = (const char*)glGetString(GL_RENDERER);

    printf("vendor   %s\n", vendor);
    printf("renderer %s\n", renderer);

    if (vendor && strstr(vendor, "Mesa")) {
      printf("driver   Panfrost (Mesa)\n");
      SDL_DestroyWindow(window);
      SDL_Quit();
      return 0;
    } else if (vendor && strstr(vendor, "ARM")) {
      printf("driver   libMali (ARM)\n");
    }

    SDL_DestroyWindow(window);
    SDL_Quit();
    return 1;
}

