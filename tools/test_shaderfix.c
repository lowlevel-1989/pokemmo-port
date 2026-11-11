/*
 * test_shaderfix.c - checks libshaderfix detection/replacement without the game.
 *
 * Fakes a GL driver: exports glXGetProcAddress / eglGetProcAddress and fake
 * glShaderSource / glCompileShader / glGetShaderiv / glGetShaderInfoLog.
 * Run with LD_PRELOAD=libshaderfix.so so every lookup goes through the hook
 * exactly like SDL3 does in the game (dlsym -> glXGetProcAddress -> glShaderSource).
 *
 *   SHADERFIX_DATA=pokemmo/data/shaders SHADERFIX_DUMP=/tmp/x \
 *   LD_PRELOAD=./libshaderfix.so ./test_shaderfix pokemmo/data/shaders
 *
 * Build: gcc -O1 -rdynamic -o test_shaderfix test_shaderfix.c -ldl
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef void  (*ShaderSourceFn)(unsigned, int, const char *const *, const int *);
typedef void  (*CompileShaderFn)(unsigned);
typedef void *(*GetProcFn)(const char *);

/* ---------------- fake driver ---------------- */

static char *last_src;          /* what reached the "driver" */
static int   last_count;
static int   fail_compile;      /* next compile reports an error */

static void fake_source(unsigned sh, int count, const char *const *str, const int *len)
{
  (void)sh;
  size_t n = 0;
  for (int i = 0; i < count; i++) n += (len && len[i] >= 0) ? (size_t)len[i] : strlen(str[i]);
  free(last_src);
  last_src = malloc(n + 1);
  n = 0;
  for (int i = 0; i < count; i++) {
    size_t l = (len && len[i] >= 0) ? (size_t)len[i] : strlen(str[i]);
    memcpy(last_src + n, str[i], l);
    n += l;
  }
  last_src[n] = 0;
  last_count = count;
}
static void fake_compile(unsigned sh) { (void)sh; }
static void fake_getiv(unsigned sh, unsigned pname, int *out)
{
  (void)sh;
  if (pname == 0x8B81) *out = fail_compile ? 0 : 1;           /* GL_COMPILE_STATUS */
  if (pname == 0x8B84) *out = 32;                              /* GL_INFO_LOG_LENGTH */
}
static void fake_getlog(unsigned sh, int max, int *len, char *log)
{
  (void)sh;
  snprintf(log, (size_t)max, "0:1: L0001 fake error");
  if (len) *len = (int)strlen(log);
}

static void *fake_proc(const char *name)
{
  if (!strcmp(name, "glShaderSource"))     return (void *)fake_source;
  if (!strcmp(name, "glCompileShader"))    return (void *)fake_compile;
  if (!strcmp(name, "glGetShaderiv"))      return (void *)fake_getiv;
  if (!strcmp(name, "glGetShaderInfoLog")) return (void *)fake_getlog;
  return NULL;
}

/* exported (-rdynamic) so the hook finds them through dlsym */
void *glXGetProcAddress(const char *name) { return fake_proc(name); }
void *eglGetProcAddress(const char *name) { return fake_proc(name); }

/* ---------------- helpers ---------------- */

static const char *data_dir;
static int failures, passes;

static char *read_norm(const char *name)
{
  char path[1024];
  snprintf(path, sizeof path, "%s/%s", data_dir, name);
  FILE *f = fopen(path, "rb");
  if (!f) { fprintf(stderr, "cannot read %s\n", path); exit(2); }
  fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
  char *t = malloc((size_t)n + 1);
  if (fread(t, 1, (size_t)n, f) != (size_t)n) exit(2);
  fclose(f);
  size_t w = 0;
  for (long r = 0; r < n; r++) if (t[r] != '\r') t[w++] = t[r];
  while (w && (t[w-1] == '\n' || t[w-1] == ' ' || t[w-1] == '\t')) w--;
  t[w] = 0;
  return t;
}

static char *cat(const char *a, const char *b, const char *c)
{
  char *r = malloc(strlen(a) + strlen(b) + strlen(c) + 1);
  strcpy(r, a); strcat(r, b); strcat(r, c);
  return r;
}

static void check(const char *name, int ok)
{
  printf("%s  %s\n", ok ? "PASS" : "FAIL", name);
  if (ok) passes++; else failures++;
}

static void send(ShaderSourceFn fn, const char *src)
{
  const char *p = src;
  fn(1, 1, &p, NULL);
}

/* ---------------- tests ---------------- */

int main(int argc, char **argv)
{
  data_dir = argc > 1 ? argv[1] : "data/shaders";

  /* the game resolves everything through dlsym, which the preload hooks */
  GetProcFn glx = (GetProcFn)dlsym(RTLD_DEFAULT, "glXGetProcAddress");
  GetProcFn egl = (GetProcFn)dlsym(RTLD_DEFAULT, "eglGetProcAddress");
  check("hook installed: glXGetProcAddress is wrapped", glx && glx != (GetProcFn)glXGetProcAddress);
  check("hook installed: eglGetProcAddress is wrapped", egl && egl != (GetProcFn)eglGetProcAddress);
  if (!glx || !egl) return 1;

  ShaderSourceFn  src  = (ShaderSourceFn)glx("glShaderSource");
  CompileShaderFn comp = (CompileShaderFn)glx("glCompileShader");
  ShaderSourceFn  esrc = (ShaderSourceFn)egl("glShaderSource");
  check("glShaderSource (GLX) is wrapped", src && src != fake_source);
  check("glCompileShader (GLX) is wrapped", comp && comp != fake_compile);
  check("glShaderSource (EGL) is wrapped", esrc && esrc != fake_source);

  char *dv = read_norm("default.vertex.glsl");
  char *df = read_norm("default.fragment.glsl");
  char *pv = read_norm("depth.vertex.glsl");
  char *pf = read_norm("depth.fragment.glsl");
  char *twl = read_norm("twl.fragment.glsl");

  const char *prefix = "#define fogFlag\n#define numBones 32\n";

  /* 1-2: built-in ambient-light shaders -> default.* with the game's #defines kept */
  send(src, "#define fogFlag\n#define numBones 32\nattribute vec3 a_position;\nvarying vec3 v_ambientLight;\n"
            "void main(){ v_ambientLight = vec3(1.0); gl_Position = vec4(a_position,1.0); }\n");
  check("built-in VS with v_ambientLight -> prefix + default.vertex.glsl",
        !strcmp(last_src, cat(prefix, dv, "\n")));

  send(src, "#define fogFlag\n#define numBones 32\nvarying vec3 v_ambientLight;\n"
            "void main(){ gl_FragColor = vec4(v_ambientLight,1.0); }\n");
  check("built-in FS with v_ambientLight -> prefix + default.fragment.glsl",
        !strcmp(last_src, cat(prefix, df, "\n")));

  /* 3-4: built-in depth shaders -> depth.* */
  send(src, "#define fogFlag\n#define numBones 32\n#ifdef PackedDepthFlag\nvarying float v_depth;\n#endif\n"
            "void main(){ gl_Position = vec4(0.0); }\n");
  check("built-in VS with PackedDepthFlag -> prefix + depth.vertex.glsl",
        !strcmp(last_src, cat(prefix, pv, "\n")));

  send(src, "#define fogFlag\n#define numBones 32\n#ifdef PackedDepthFlag\n#endif\n"
            "void main(){ gl_FragColor = vec4(1.0); }\n");
  check("built-in FS with PackedDepthFlag -> prefix + depth.fragment.glsl",
        !strcmp(last_src, cat(prefix, pf, "\n")));

  /* 5: unrelated built-in shader passes through untouched (same chunks) */
  {
    const char *parts[] = {"uniform mat4 u_projTrans;\n", "void main(){ gl_Position = vec4(0.0); }\n"};
    src(1, 2, parts, NULL);
    check("unrelated built-in shader is untouched (chunks preserved)",
          last_count == 2 && !strcmp(last_src, "uniform mat4 u_projTrans;\nvoid main(){ gl_Position = vec4(0.0); }\n"));
  }

  /* 6: one of the data/shaders files (with #defines in front) is left alone */
  {
    char *s = cat("#define LOWP lowp\n", twl, "\n");
    send(src, s);
    check("data/shaders file (twl.fragment) is untouched", !strcmp(last_src, s));
  }

  /* 7: a data/shaders file that uses v_ambientLight -> WARNING + replaced by default.
   *    The runner puts bad.fragment.glsl (with v_ambientLight) in the data dir. */
  {
    char *bad = read_norm("bad.fragment.glsl");
    send(src, cat("#define fogFlag\n", bad, "\n"));
    check("data/shaders file using v_ambientLight -> default.fragment.glsl",
          !strcmp(last_src, cat("#define fogFlag\n", df, "\n")));
  }

  /* 8: detection works across several chunks with explicit lengths */
  {
    const char *parts[] = {"#define fogFlag\nvarying vec3 v_amb", "ientLight;XXXX", "\nvoid main(){ gl_Position = vec4(0.0); }\n"};
    int lens[] = {(int)strlen(parts[0]), 10, -1};
    src(1, 3, parts, lens);
    check("multi-chunk source with lengths is joined and detected",
          !strcmp(last_src, cat("#define fogFlag\n", dv, "\n")));
  }

  /* 9: EGL side (what gl4es sends to libmali) is never replaced */
  {
    const char *s = "varying vec3 v_ambientLight;\nvoid main(){ gl_FragColor = vec4(1.0); }\n";
    send(esrc, s);
    check("EGL side is only dumped, never replaced", !strcmp(last_src, s));
  }

  /* 10: a compile failure is reported (checked by the runner on stderr) */
  fail_compile = 1;
  comp(7);
  fail_compile = 0;
  check("compile with error returns without crashing", 1);

  printf("\n%d passed, %d failed\n", passes, failures);
  return failures ? 1 : 0;
}
