/*
 * Copyright (C) 2025  Vinicio Valbuena (lowlevel.1989)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

/*
 * launch_menu v0.5.0
 *
 *   launch_menu <menu.items> <font.ttf> [--godot]
 *   launch_menu <menu.items> <font.ttf> --show "message"
 *   launch_menu <menu.items> <font.ttf> --trace [--trace-file F] [--title T] [--pid N]
 *
 * Exit code: 0 = Exit, 1 = error, N+2 = menu.items line N.
 *
 * Trace mode follows a text file in real time (like tail -f):
 *   - the file may not exist yet: the window waits for it
 *   - truncation / re-creation of the file is detected
 *   - '\r' rewrites the current line (curl --progress-bar works as-is)
 *   - a "NN%" or "NN.N%" in a line updates the progress bar
 *   - directives (one per line):
 *        @TITLE text      big title
 *        @STATUS text     status line above the progress bar
 *        @PROGRESS n      progress 0..100 (-1 hides the bar)
 *        __ERROR__ text   shows the error, closes after a few seconds
 *        __END__          closes the window
 *   - with --pid, the window also closes if that process dies
 */

#include <SDL2/SDL.h>
#include <SDL2/SDL_ttf.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#define VERSION          "0.5.0"
#define TRACE_FILE       "/tmp/launch_menu.trace"
#define SCREEN_WIDTH     640
#define SCREEN_HEIGHT    480
#define FONT_SIZE        24
#define FONT_SIZE_SMALL  16
#define MARGIN           15
#define ITEM_HEIGHT      35
#define MAX_OPTIONS      100
#define MAX_KEY          2048
#define MAX_ABS          2048
#define TRACE_LINES      64
#define TRACE_LINE_LEN   256
#define ERROR_HOLD_MS    5000

#define BSWAP16(x) ((__u16)(((x) << 8) | ((x) >> 8)))
#define NBITS(x) ((((x)-1)/8/sizeof(long))+1)
#define test_bit(nr, addr) (((1UL << ((nr) % (8*sizeof(long)))) & ((addr)[(nr)/ (8*sizeof(long))])) != 0)

static const SDL_Color WHITE  = {255, 255, 255, 255};
static const SDL_Color YELLOW = {255, 255,   0, 255};
static const SDL_Color GREY   = {140, 140, 140, 255};
static const SDL_Color RED    = {255,  80,  80, 255};

/* ------------------------------------------------------------------ */
/* rendering helpers                                                    */
/* ------------------------------------------------------------------ */

typedef struct {
  SDL_Window   *window;
  SDL_Renderer *renderer;
  TTF_Font     *font;
  TTF_Font     *small;
} Ui;

static void ui_clear(Ui *ui)
{
  SDL_SetRenderDrawColor(ui->renderer, 0, 0, 0, 255);
  SDL_RenderClear(ui->renderer);
}

/* draws text, cut to max_w pixels (0 = no limit); returns its height */
static int ui_text(Ui *ui, TTF_Font *font, const char *text, int x, int y, SDL_Color color, int max_w)
{
  if (!text || !*text) return TTF_FontHeight(font);

  char buf[TRACE_LINE_LEN + 4];
  snprintf(buf, sizeof buf, "%s", text);
  if (max_w > 0) {
    int w = 0;
    size_t n = strlen(buf);
    while (n > 0 && TTF_SizeUTF8(font, buf, &w, NULL) == 0 && w > max_w) {
      /* drop one UTF-8 char */
      do { n--; } while (n > 0 && ((unsigned char)buf[n] & 0xC0) == 0x80);
      buf[n] = '\0';
    }
  }

  SDL_Surface *s = TTF_RenderUTF8_Blended(font, buf, color);
  if (!s) return TTF_FontHeight(font);
  SDL_Texture *t = SDL_CreateTextureFromSurface(ui->renderer, s);
  if (t) {
    SDL_Rect dst = {x, y, s->w, s->h};
    SDL_RenderCopy(ui->renderer, t, NULL, &dst);
    SDL_DestroyTexture(t);
  }
  int h = s->h;
  SDL_FreeSurface(s);
  return h;
}

/* pump events while waiting, so the window never looks frozen */
static void ui_wait(int ms)
{
  Uint32 end = SDL_GetTicks() + (Uint32)ms;
  SDL_Event e;
  while ((Sint32)(end - SDL_GetTicks()) > 0) {
    while (SDL_PollEvent(&e)) if (e.type == SDL_QUIT) return;
    SDL_Delay(16);
  }
}

/* full-screen message, like the original */
static void ui_message(Ui *ui, const char *text, int ms)
{
  ui_clear(ui);
  ui_text(ui, ui->font, text, MARGIN, MARGIN, WHITE, SCREEN_WIDTH - 2 * MARGIN);
  SDL_RenderPresent(ui->renderer);
  ui_wait(ms);
}

/* ------------------------------------------------------------------ */
/* menu items                                                           */
/* ------------------------------------------------------------------ */

static char *menu_options[MAX_OPTIONS];
static int   option_count;

static bool add_option(const char *s)
{
  if (option_count >= MAX_OPTIONS) return false;
  menu_options[option_count] = strdup(s);
  if (!menu_options[option_count]) return false;
  option_count++;
  return true;
}

static bool load_menu(const char *filename)
{
  FILE *file = fopen(filename, "r");
  if (!file) {
    fprintf(stderr, "Error opening menu file: %s\n", filename);
    return false;
  }

  char line[256];
  while (fgets(line, sizeof line, file) && option_count < MAX_OPTIONS - 3) {
    line[strcspn(line, "\r\n")] = 0;
    if (!*line) continue;
    if (!add_option(line)) { fclose(file); return false; }
    printf("Loaded menu option [%d]: %s\n", option_count - 1, line);
  }
  fclose(file);

  return add_option("Joystick Mapper") && add_option("Restore") && add_option("Exit");
}

/* ------------------------------------------------------------------ */
/* joystick mapper                                                      */
/* ------------------------------------------------------------------ */

typedef struct {
  char name[32];
  char type;
  int  hat;
  int  value;
  int  inverted;
} MappingEntry;

static const char *mapping_names[] = {
  "a", "b", "x", "y",
  "back", "guide", "start",
  "leftshoulder", "rightshoulder",
  "leftstick", "rightstick",
  "leftx", "lefty", "rightx", "righty",
  "lefttrigger", "righttrigger",
  "dpup", "dpdown", "dpleft", "dpright"
};

static const char *mapping_show_names[] = {
  "a", "b", "x", "y",
  "select", "guide", "start",
  "l1", "r1",
  "L stick (pressed)", "R stick (pressed)",
  "L stick horizontal", "L stick vertical",
  "R stick horizontal", "R stick vertical",
  "l2", "r2",
  "up", "down", "left", "right"
};

#define MAPPING_COUNT  ((int)(sizeof(mapping_names) / sizeof(mapping_names[0])))
#define BA_INDEX        0
#define BB_INDEX        1
#define LSTICKH_INDEX  11
#define LSTICKV_INDEX  12
#define RSTICKH_INDEX  13
#define RSTICKV_INDEX  14

static int key_map[MAX_KEY];
static int abs_map[MAX_ABS];
static int abs_max[MAX_ABS];
static int abs_min[MAX_ABS];

static int normalize_axis(int value, int min, int max)
{
  if (max == min) return 0;
  float scaled = (2.0f * (value - min) / (float)(max - min)) - 1.0f;
  return (int)(scaled * 32767);
}

static int open_joystick_device(void)
{
  for (int i = 0; i < 32; i++) {
    char path[64];
    snprintf(path, sizeof path, "/dev/input/event%d", i);
    int fd = open(path, O_RDONLY | O_NONBLOCK);
    if (fd < 0) continue;

    unsigned long evbit[NBITS(EV_MAX)] = {0};
    if (ioctl(fd, EVIOCGBIT(0, sizeof evbit), evbit) < 0 ||
        !test_bit(EV_ABS, evbit) || !test_bit(EV_KEY, evbit)) {
      close(fd);
      continue;
    }
    printf("Using input device: %s\n", path);
    return fd;
  }
  printf("No suitable joystick device found\n");
  return -1;
}

/* GODOT: map evdev codes to godot indexes */
static void setup_joypad_properties(int fd)
{
  for (int i = 0; i < MAX_KEY; i++) key_map[i] = -1;
  for (int i = 0; i < MAX_ABS; i++) abs_map[i] = -1;
  if (fd < 0) return;

  unsigned long keybit[NBITS(KEY_MAX)] = {0};
  unsigned long absbit[NBITS(ABS_MAX)] = {0};
  if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof keybit), keybit) < 0 ||
      ioctl(fd, EVIOCGBIT(EV_ABS, sizeof absbit), absbit) < 0) {
    perror("ioctl EVIOCGBIT");
    return;
  }

  int num_buttons = 0;
  for (int code = BTN_JOYSTICK; code < KEY_MAX; ++code)
    if (test_bit(code, keybit)) key_map[code] = num_buttons++;
  for (int code = BTN_MISC; code < BTN_JOYSTICK; ++code)
    if (test_bit(code, keybit)) key_map[code] = num_buttons++;

  int num_axes = 0;
  for (int code = 0; code < ABS_MISC; ++code) {
    if (code == ABS_HAT0X) { code = ABS_HAT3Y; continue; }   /* skip hats */
    if (test_bit(code, absbit)) {
      struct input_absinfo info;
      if (ioctl(fd, EVIOCGABS(code), &info) < 0) continue;
      abs_map[code] = num_axes++;
      abs_min[code] = info.minimum;
      abs_max[code] = info.maximum;
    }
  }
}

static void draw_prompt(Ui *ui, int i, const char *prompt)
{
  ui_clear(ui);
  if (i > 1) ui_text(ui, ui->font, "Press B to skip", MARGIN, 15, WHITE, 0);
  ui_text(ui, ui->font, prompt, MARGIN, 40, WHITE, 0);
  SDL_RenderPresent(ui->renderer);
}

static void draw_confirm(Ui *ui, int i, const char *info)
{
  ui_clear(ui);
  ui_text(ui, ui->font, info, MARGIN, 15, WHITE, 0);
  ui_text(ui, ui->font, i < 2 ? "Press same input to confirm," : "Press A to confirm,", MARGIN, 70, WHITE, 0);
  ui_text(ui, ui->font, i < 2 ? "any other to retry" : "B to retry", MARGIN, 90, WHITE, 0);
  SDL_RenderPresent(ui->renderer);
}

static int wait_for_input(Ui *ui, int i, int b_button, int fd, MappingEntry *m, const char *prompt)
{
  struct input_event ev;
  draw_prompt(ui, i, prompt);
  for (;;) {
    SDL_PumpEvents();
    while (read(fd, &ev, sizeof ev) == (ssize_t)sizeof ev) {
      if (ev.type == EV_KEY && ev.value == 1 && ev.code < MAX_KEY) {
        if (i > 1 && key_map[ev.code] == b_button) return 0;
        m->value = key_map[ev.code];
        m->type  = 'b';
        return 1;
      }
      if (ev.type == EV_ABS && (ev.code == ABS_HAT0X || ev.code == ABS_HAT0Y) && ev.value != 0) {
        m->hat  = 0;
        m->type = 'h';
        if (ev.code == ABS_HAT0X) m->value = ev.value < 0 ? SDL_HAT_LEFT : SDL_HAT_RIGHT;
        else                      m->value = ev.value < 0 ? SDL_HAT_UP   : SDL_HAT_DOWN;
        return 1;
      }
      if (ev.type == EV_ABS && ev.code < MAX_ABS && abs_map[ev.code] >= 0) {
        int v = normalize_axis(ev.value, abs_min[ev.code], abs_max[ev.code]);
        if (abs(v) > 8000) {
          m->value    = abs_map[ev.code];
          m->type     = 'a';
          m->inverted = v > 0;
          return 1;
        }
      }
    }
    SDL_Delay(10);
  }
}

static int confirm_input(Ui *ui, int i, const char *info, int input_value, int fd, int a_button, int b_button)
{
  struct input_event ev;
  draw_confirm(ui, i, info);
  for (;;) {
    SDL_PumpEvents();
    while (read(fd, &ev, sizeof ev) == (ssize_t)sizeof ev) {
      if (ev.type != EV_KEY || ev.value != 1 || ev.code >= MAX_KEY) continue;
      if (i < 2) return key_map[ev.code] == input_value;
      if (key_map[ev.code] == a_button) return 1;
      if (key_map[ev.code] == b_button) return 0;
    }
    SDL_Delay(10);
  }
}

static int wait_for_input_SDL(Ui *ui, int i, int b_button, SDL_JoystickID id, MappingEntry *m, const char *prompt)
{
  SDL_Event e;
  while (SDL_PollEvent(&e));
  draw_prompt(ui, i, prompt);
  for (;;) {
    if (!SDL_WaitEventTimeout(&e, 100)) continue;
    if (e.type == SDL_QUIT) exit(0);
    if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE) return 0;
    if (e.type == SDL_JOYBUTTONDOWN && e.jbutton.which == id) {
      if (i > 1 && e.jbutton.button == b_button) return 0;
      m->value = e.jbutton.button;
      m->type  = 'b';
      return 1;
    }
    if (e.type == SDL_JOYAXISMOTION && e.jaxis.which == id && abs(e.jaxis.value) > 8000) {
      m->value    = e.jaxis.axis;
      m->inverted = e.jaxis.value > 0;
      m->type     = 'a';
      return 1;
    }
    if (e.type == SDL_JOYHATMOTION && e.jhat.which == id && e.jhat.value != SDL_HAT_CENTERED) {
      m->value = e.jhat.value;
      m->hat   = e.jhat.hat;
      m->type  = 'h';
      return 1;
    }
  }
}

static int confirm_input_SDL(Ui *ui, int i, const char *info, int input_value, SDL_JoystickID id, int a_button, int b_button)
{
  SDL_Event e;
  while (SDL_PollEvent(&e));
  draw_confirm(ui, i, info);
  for (;;) {
    if (!SDL_WaitEventTimeout(&e, 100)) continue;
    if (e.type == SDL_QUIT) exit(0);
    if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE) return 0;
    if (e.type != SDL_JOYBUTTONDOWN || e.jbutton.which != id) continue;
    if (i < 2) return e.jbutton.button == input_value;
    if (e.jbutton.button == a_button) return 1;
    if (e.jbutton.button == b_button) return 0;
  }
}

static void save_mapping(Ui *ui, const char *filename, const char *name, const char *guid,
                         MappingEntry *m, int count)
{
  FILE *f = fopen(filename, "w");
  if (!f) { ui_message(ui, "Failed to save mapping file.", 2000); return; }

  fprintf(f, "%s,%s", guid, name ? name : "UnknownController");
  for (int i = 0; i < count; i++) {
    if (!m[i].name[0]) continue;
    if (m[i].type == 'h')      fprintf(f, ",%s:%c%d.%d", m[i].name, m[i].type, m[i].hat, m[i].value);
    else if (m[i].inverted)    fprintf(f, ",%s:%c%d~",   m[i].name, m[i].type, m[i].value);
    else                       fprintf(f, ",%s:%c%d",    m[i].name, m[i].type, m[i].value);
  }
  fprintf(f, ",platform:Linux\n");
  fclose(f);
  ui_message(ui, "Mapping saved to controller.map", 3000);
}

static void prompt_for(int i, char *out, size_t n)
{
  switch (i) {
    case LSTICKH_INDEX: snprintf(out, n, "Move L stick to the LEFT"); break;
    case LSTICKV_INDEX: snprintf(out, n, "Move L stick UP"); break;
    case RSTICKH_INDEX: snprintf(out, n, "Move R stick to the LEFT"); break;
    case RSTICKV_INDEX: snprintf(out, n, "Move R stick UP"); break;
    default:            snprintf(out, n, "Press input for %s:", mapping_show_names[i]);
  }
}

static void describe(int i, const MappingEntry *m, char *out, size_t n)
{
  if (m->type == 'h')
    snprintf(out, n, "Detected %c%d.%d for %s", m->type, m->hat, m->value, mapping_show_names[i]);
  else
    snprintf(out, n, "Detected %c%d%s for %s", m->type, m->value, m->inverted ? "~" : "", mapping_show_names[i]);
}

/* shared mapping loop; godot uses evdev (fd >= 0), SDL uses the joystick id */
static void run_mapper(Ui *ui, int fd, SDL_JoystickID id, MappingEntry *m)
{
  int a_button = -1, b_button = -1;
  for (int i = 0; i < MAPPING_COUNT; i++) {
    for (;;) {
      char prompt[128], info[128];
      prompt_for(i, prompt, sizeof prompt);
      memset(&m[i], 0, sizeof m[i]);

      int got = fd >= 0 ? wait_for_input(ui, i, b_button, fd, &m[i], prompt)
                        : wait_for_input_SDL(ui, i, b_button, id, &m[i], prompt);
      if (!got) {
        if (i < 2) continue;              /* 'a' and 'b' are mandatory */
        m[i].name[0] = '\0';
        break;
      }
      describe(i, &m[i], info, sizeof info);
      snprintf(m[i].name, sizeof m[i].name, "%s", mapping_names[i]);
      if (i == BA_INDEX) a_button = m[i].value;
      if (i == BB_INDEX) b_button = m[i].value;

      int ok = fd >= 0 ? confirm_input(ui, i, info, m[i].value, fd, a_button, b_button)
                       : confirm_input_SDL(ui, i, info, m[i].value, id, a_button, b_button);
      if (ok) break;
    }
  }
}

static void joystick_mapper_godot(Ui *ui)
{
  int fd = open_joystick_device();
  if (fd < 0) { ui_message(ui, "No joystick detected.", 2000); return; }
  setup_joypad_properties(fd);

  char name[128] = "UnknownController", guid[64];
  struct input_id id;
  ioctl(fd, EVIOCGNAME(sizeof name), name);
  ioctl(fd, EVIOCGID, &id);
  snprintf(guid, sizeof guid, "%04x%04x%04x%04x%04x%04x%04x%04x",
           BSWAP16(id.bustype), 0, BSWAP16(id.vendor), 0,
           BSWAP16(id.product), 0, BSWAP16(id.version), 0);

  MappingEntry m[MAPPING_COUNT];
  run_mapper(ui, fd, 0, m);
  save_mapping(ui, "controller.map", name, guid, m, MAPPING_COUNT);
  close(fd);
}

static void joystick_mapper_SDL(Ui *ui)
{
  if (SDL_NumJoysticks() < 1) { ui_message(ui, "No joystick detected.", 2000); return; }
  SDL_Joystick *joy = SDL_JoystickOpen(0);
  if (!joy) { ui_message(ui, "Failed to open joystick.", 2000); return; }

  char guid[64];
  SDL_JoystickGetGUIDString(SDL_JoystickGetGUID(joy), guid, sizeof guid);

  MappingEntry m[MAPPING_COUNT];
  run_mapper(ui, -1, SDL_JoystickInstanceID(joy), m);
  save_mapping(ui, "controller.map", SDL_JoystickName(joy), guid, m, MAPPING_COUNT);
  SDL_JoystickClose(joy);
}

/* ------------------------------------------------------------------ */
/* trace mode (real-time progress window)                               */
/* ------------------------------------------------------------------ */

typedef struct {
  char  lines[TRACE_LINES][TRACE_LINE_LEN];
  int   first, count;          /* ring buffer */
  char  cur[TRACE_LINE_LEN];   /* line being written (no '\n' yet) */
  size_t cur_len;
  char  title[TRACE_LINE_LEN];
  char  status[TRACE_LINE_LEN];
  char  error[TRACE_LINE_LEN];
  float progress;              /* <0 = hidden */
  bool  ended;
} Trace;

static void trace_push(Trace *t, const char *s)
{
  int idx;
  if (t->count < TRACE_LINES) idx = (t->first + t->count++) % TRACE_LINES;
  else { idx = t->first; t->first = (t->first + 1) % TRACE_LINES; }
  snprintf(t->lines[idx], TRACE_LINE_LEN, "%s", s);
}

/* last "NN%" / "NN.N%" in s, or -1 */
static float find_percent(const char *s)
{
  float found = -1;
  for (const char *p = strchr(s, '%'); p; p = strchr(p + 1, '%')) {
    const char *b = p;
    while (b > s && ((b[-1] >= '0' && b[-1] <= '9') || b[-1] == '.' || b[-1] == ',')) b--;
    if (b == p) continue;
    char num[16];
    size_t n = (size_t)(p - b) < sizeof num - 1 ? (size_t)(p - b) : sizeof num - 1;
    memcpy(num, b, n); num[n] = 0;
    for (char *c = num; *c; c++) if (*c == ',') *c = '.';
    float v = strtof(num, NULL);
    if (v >= 0 && v <= 100) found = v;
  }
  return found;
}

/* curl's "#####   45.2%" -> "45.2%": drop the hash bar */
static void strip_hashes(char *s)
{
  char *w = s;
  for (char *r = s; *r; r++) if (*r != '#') *w++ = *r;
  *w = 0;
  char *b = s;
  while (*b == ' ') b++;
  memmove(s, b, strlen(b) + 1);
}

/* handle a completed line (final = ended by '\n') or a live '\r' line */
static void trace_line(Trace *t, char *s, bool final)
{
  if (!strcmp(s, "__END__"))                 { t->ended = true; return; }
  if (!strncmp(s, "__ERROR__", 9))           { snprintf(t->error,  sizeof t->error,  "%s", s[9] == ' ' ? s + 10 : s + 9); return; }
  if (!strncmp(s, "@TITLE ", 7))             { snprintf(t->title,  sizeof t->title,  "%s", s + 7); return; }
  if (!strncmp(s, "@STATUS ", 8))            { snprintf(t->status, sizeof t->status, "%s", s + 8); return; }
  if (!strncmp(s, "@PROGRESS ", 10))         { t->progress = strtof(s + 10, NULL); return; }

  float p = find_percent(s);
  if (p >= 0) t->progress = p;
  if (strchr(s, '#')) strip_hashes(s);
  if (final && *s) {
    printf("%s\n", s);
    trace_push(t, s);
  }
}

/* feed raw bytes from the file */
static void trace_feed(Trace *t, const char *buf, size_t n)
{
  for (size_t i = 0; i < n && !t->ended; i++) {
    char c = buf[i];
    if (c == '\n') {
      t->cur[t->cur_len] = 0;
      trace_line(t, t->cur, true);
      t->cur_len = 0;
    } else if (c == '\r') {
      /* progress style: evaluate what we have, then rewrite the line */
      t->cur[t->cur_len] = 0;
      trace_line(t, t->cur, false);
      t->cur_len = 0;
    } else if (t->cur_len < TRACE_LINE_LEN - 1) {
      t->cur[t->cur_len++] = c;
    }
  }
  t->cur[t->cur_len] = 0;
  /* live view of the partial line (e.g. curl progress before the next '\r') */
  if (t->cur_len) {
    float p = find_percent(t->cur);
    if (p >= 0) t->progress = p;
  }
}

static void trace_render(Ui *ui, Trace *t, Uint32 ticks)
{
  static const char *spin[] = {"|", "/", "-", "\\"};
  ui_clear(ui);

  int y = MARGIN;
  char head[TRACE_LINE_LEN + 8];
  snprintf(head, sizeof head, "%s %s", t->error[0] ? "!" : spin[(ticks / 150) % 4],
           t->title[0] ? t->title : "Working...");
  y += ui_text(ui, ui->font, head, MARGIN, y, YELLOW, SCREEN_WIDTH - 2 * MARGIN) + 6;

  if (t->status[0])
    y += ui_text(ui, ui->small, t->status, MARGIN, y, WHITE, SCREEN_WIDTH - 2 * MARGIN) + 4;

  if (t->progress >= 0) {
    SDL_Rect frame = {MARGIN, y, SCREEN_WIDTH - 2 * MARGIN, 18};
    float p = t->progress > 100 ? 100 : t->progress;
    SDL_Rect fill = {frame.x + 2, frame.y + 2, (int)((frame.w - 4) * p / 100.0f), frame.h - 4};
    SDL_SetRenderDrawColor(ui->renderer, 255, 255, 255, 255);
    SDL_RenderDrawRect(ui->renderer, &frame);
    SDL_SetRenderDrawColor(ui->renderer, 255, 255, 0, 255);
    SDL_RenderFillRect(ui->renderer, &fill);
    y += frame.h + 2;
    char pct[16];
    snprintf(pct, sizeof pct, "%.1f%%", p);
    y += ui_text(ui, ui->small, pct, MARGIN, y, WHITE, 0) + 4;
  }

  int bottom = SCREEN_HEIGHT - MARGIN;
  if (t->error[0]) {
    bottom -= TTF_FontHeight(ui->font);
    ui_text(ui, ui->font, t->error, MARGIN, bottom, RED, SCREEN_WIDTH - 2 * MARGIN);
  }

  /* log: newest lines at the bottom, as many as fit */
  int lh = TTF_FontLineSkip(ui->small);
  int fit = (bottom - y) / lh;
  if (fit > t->count) fit = t->count;
  int ly = bottom - fit * lh;
  for (int i = t->count - fit; i < t->count; i++) {
    const char *s = t->lines[(t->first + i) % TRACE_LINES];
    ui_text(ui, ui->small, s, MARGIN, ly, i == t->count - 1 ? WHITE : GREY, SCREEN_WIDTH - 2 * MARGIN);
    ly += lh;
  }

  SDL_RenderPresent(ui->renderer);
}

static int trace_mode(Ui *ui, const char *path, const char *title, pid_t watch_pid)
{
  static Trace t;
  memset(&t, 0, sizeof t);
  t.progress = -1;
  if (title) snprintf(t.title, sizeof t.title, "%s", title);
  snprintf(t.status, sizeof t.status, "Waiting for %s", path);

  int   fd = -1;
  off_t pos = 0;
  ino_t ino = 0;
  Uint32 error_at = 0;
  SDL_Event e;

  while (!t.ended) {
    while (SDL_PollEvent(&e)) if (e.type == SDL_QUIT) t.ended = true;

    /* (re)open the file: it may not exist yet, or may have been recreated */
    struct stat st;
    if (stat(path, &st) == 0) {
      if (fd < 0 || st.st_ino != ino) {
        if (fd >= 0) close(fd);
        fd = open(path, O_RDONLY);
        ino = st.st_ino;
        pos = 0;
        if (t.status[0] && !strncmp(t.status, "Waiting for ", 12)) t.status[0] = 0;
      }
      if (fd >= 0 && st.st_size < pos) pos = 0;           /* truncated */
    }

    if (fd >= 0) {
      char buf[4096];
      ssize_t n;
      while (!t.ended && (n = pread(fd, buf, sizeof buf, pos)) > 0) {
        pos += n;
        trace_feed(&t, buf, (size_t)n);
      }
    }

    if (watch_pid > 0 && kill(watch_pid, 0) != 0 && errno == ESRCH) {
      printf("[trace] pid %d is gone, closing\n", (int)watch_pid);
      if (!t.error[0]) break;
    }

    if (t.error[0]) {
      if (!error_at) { error_at = SDL_GetTicks(); fprintf(stderr, "[trace] ERROR: %s\n", t.error); }
      else if (SDL_GetTicks() - error_at > ERROR_HOLD_MS) break;
    }

    trace_render(ui, &t, SDL_GetTicks());
    SDL_Delay(33);
  }

  if (t.ended && !t.error[0]) {
    t.progress = t.progress >= 0 ? 100 : -1;
    trace_render(ui, &t, SDL_GetTicks());
    ui_wait(300);
  }
  if (fd >= 0) close(fd);
  return t.error[0] ? 1 : 0;
}

/* ------------------------------------------------------------------ */
/* main menu                                                            */
/* ------------------------------------------------------------------ */

typedef struct { SDL_Texture *tex[2]; int w, h; } ItemTex;

static void render_menu(Ui *ui, ItemTex *items, int selected, int *scroll)
{
  int visible = (SCREEN_HEIGHT - MARGIN) / ITEM_HEIGHT;
  if (selected < *scroll) *scroll = selected;
  if (selected >= *scroll + visible) *scroll = selected - visible + 1;

  ui_clear(ui);
  int y = MARGIN;
  for (int i = *scroll; i < option_count && i < *scroll + visible; i++) {
    SDL_Texture *t = items[i].tex[i == selected];
    if (t) {
      SDL_Rect dst = {MARGIN, y, items[i].w, items[i].h};
      SDL_RenderCopy(ui->renderer, t, NULL, &dst);
    }
    y += ITEM_HEIGHT;
  }
  SDL_RenderPresent(ui->renderer);
}

static void build_items(Ui *ui, ItemTex *items)
{
  for (int i = 0; i < option_count; i++) {
    for (int s = 0; s < 2; s++) {
      SDL_Surface *surf = TTF_RenderUTF8_Blended(ui->font, menu_options[i], s ? YELLOW : WHITE);
      items[i].tex[s] = NULL;
      if (!surf) continue;
      items[i].tex[s] = SDL_CreateTextureFromSurface(ui->renderer, surf);
      items[i].w = surf->w;
      items[i].h = surf->h;
      SDL_FreeSurface(surf);
    }
  }
}

static void free_items(ItemTex *items)
{
  for (int i = 0; i < option_count; i++)
    for (int s = 0; s < 2; s++)
      if (items[i].tex[s]) SDL_DestroyTexture(items[i].tex[s]);
}

static int run_menu(Ui *ui, bool godot)
{
  /* dev/test: LAUNCH_MENU_AUTOSELECT=<line of menu.items, 0-based> skips the UI */
  const char *auto_sel = getenv("LAUNCH_MENU_AUTOSELECT");
  if (auto_sel && *auto_sel) {
    int n = atoi(auto_sel);
    if (n >= 0 && n < option_count - 3) {
      printf("[MENU] autoselect: %s\n", menu_options[n]);
      ui_message(ui, menu_options[n], 500);
      return n + 2;
    }
  }

  static ItemTex items[MAX_OPTIONS];
  build_items(ui, items);

  int selected = 0, scroll = 0, exitcode = 0;
  bool running = true, dirty = true;
  Uint32 ignore_until = SDL_GetTicks() + 200;     /* swallow the key that launched us */
  SDL_Event e;

  while (running) {
    if (dirty) { render_menu(ui, items, selected, &scroll); dirty = false; }
    if (!SDL_WaitEventTimeout(&e, 250)) continue;

    do {
      if (e.type == SDL_QUIT) { running = false; break; }
      if (e.type == SDL_WINDOWEVENT) { dirty = true; continue; }
      if (e.type != SDL_KEYDOWN || SDL_GetTicks() < ignore_until) continue;

      switch (e.key.keysym.sym) {
        case SDLK_UP:
          selected = (selected - 1 + option_count) % option_count; dirty = true; break;
        case SDLK_DOWN:
          selected = (selected + 1) % option_count; dirty = true; break;
        case SDLK_RETURN:
        case SDLK_KP_ENTER: {
          if (e.key.repeat) break;
          const char *opt = menu_options[selected];
          if (!strcmp(opt, "Joystick Mapper")) {
            if (godot) joystick_mapper_godot(ui); else joystick_mapper_SDL(ui);
            ignore_until = SDL_GetTicks() + 300;
          } else if (!strcmp(opt, "Restore")) {
            if (remove("controller.map") == 0 || errno == ENOENT)
              ui_message(ui, "controller.map removed", 2000);
            else
              ui_message(ui, "error restoring mapping", 2000);
            ignore_until = SDL_GetTicks() + 300;
          } else if (!strcmp(opt, "Exit")) {
            exitcode = 0;
            running = false;
          } else {
            printf("[MENU] You selected: %s\n", opt);
            exitcode = selected + 2;
            running = false;
          }
          dirty = true;
          break;
        }
        default: break;
      }
    } while (running && SDL_PollEvent(&e));
  }

  free_items(items);
  ui_message(ui, "Loading", 300);
  return exitcode;
}

/* ------------------------------------------------------------------ */

int main(int argc, char *argv[])
{
  setvbuf(stdout, NULL, _IONBF, 0);
  setvbuf(stderr, NULL, _IONBF, 0);

  bool godot = false, trace = false;
  const char *menu_file = NULL, *font_file = NULL, *show = NULL;
  const char *trace_file = TRACE_FILE, *title = NULL;
  pid_t watch_pid = 0;

  for (int i = 1; i < argc; i++) {
    const char *a = argv[i];
    bool has_next = i + 1 < argc;
    if      (!strcmp(a, "--godot"))                    godot = true;
    else if (!strcmp(a, "--trace"))                    trace = true;
    else if (!strcmp(a, "--show")       && has_next)   show = argv[++i];
    else if (!strcmp(a, "--trace-file") && has_next)   trace_file = argv[++i];
    else if (!strcmp(a, "--title")      && has_next)   title = argv[++i];
    else if (!strcmp(a, "--pid")        && has_next)   watch_pid = (pid_t)atoi(argv[++i]);
    else if (!strcmp(a, "--version"))                { printf("launch_menu %s\n", VERSION); return 0; }
    else if (a[0] == '-' && a[1] == '-')             { fprintf(stderr, "ERR: bad option %s\n", a); return 1; }
    else if (!menu_file)                               menu_file = a;
    else if (!font_file)                               font_file = a;
  }

  if (!menu_file || !font_file) {
    printf("Usage: %s <menu.items> <font.ttf> [--godot] [--show msg] "
           "[--trace [--trace-file F] [--title T] [--pid N]]\n", argv[0]);
    return 1;
  }
  printf("launch_menu %s: menu=%s font=%s godot=%d trace=%d show=%s\n",
         VERSION, menu_file, font_file, godot, trace, show ? show : "");

  if (!trace && !show && !load_menu(menu_file)) return 1;

  if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK | SDL_INIT_TIMER) != 0 || TTF_Init() != 0) {
    fprintf(stderr, "Initialization failed: %s\n", SDL_GetError());
    return 1;
  }

  Ui ui = {0};
  ui.window = SDL_CreateWindow("Launch Menu", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                               SCREEN_WIDTH, SCREEN_HEIGHT, SDL_WINDOW_BORDERLESS);
  if (ui.window) ui.renderer = SDL_CreateRenderer(ui.window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
  if (ui.window && !ui.renderer) ui.renderer = SDL_CreateRenderer(ui.window, -1, 0);
  ui.font  = TTF_OpenFont(font_file, FONT_SIZE);
  ui.small = TTF_OpenFont(font_file, FONT_SIZE_SMALL);
  if (!ui.window || !ui.renderer || !ui.font || !ui.small) {
    fprintf(stderr, "Setup failed: %s\n", SDL_GetError());
    return 1;
  }
  if (SDL_RenderSetLogicalSize(ui.renderer, SCREEN_WIDTH, SCREEN_HEIGHT) != 0)
    fprintf(stderr, "RenderSetLogicalSize: %s\n", SDL_GetError());

  int rc;
  if (show) {
    ui_message(&ui, show, 3000);
    rc = 0;
  } else if (trace) {
    rc = trace_mode(&ui, trace_file, title, watch_pid);
  } else {
    if (godot) { int fd = open_joystick_device(); setup_joypad_properties(fd); if (fd >= 0) close(fd); }
    rc = run_menu(&ui, godot);
  }

  for (int i = 0; i < option_count; i++) free(menu_options[i]);
  TTF_CloseFont(ui.small);
  TTF_CloseFont(ui.font);
  SDL_DestroyRenderer(ui.renderer);
  SDL_DestroyWindow(ui.window);
  TTF_Quit();
  SDL_Quit();
  return rc;
}
