/*
 * shaderfix.c - LD_PRELOAD that replaces libGDX's built-in shaders inside the
 * PokeMMO binary with your own versions from data/shaders.
 *
 * For every shader the game sends to glShaderSource:
 *   1. It is dumped once to shaderfix_dump/<GLX|EGL>_<hash>.glsl
 *   2. If it comes from a file in data/shaders  -> left untouched,
 *      unless it uses v_ambientLight: then a WARNING is logged and it is
 *      replaced by default.<vertex|fragment>.glsl to avoid the libmali error
 *   3. Otherwise it is a built-in shader:
 *        uses v_ambientLight  -> replaced by data/shaders/default.<vertex|fragment>.glsl
 *        uses PackedDepthFlag -> replaced by data/shaders/depth.<vertex|fragment>.glsl
 *   The #define lines the game puts in front are always kept.
 *
 * Environment (optional):
 *   SHADERFIX_DATA=/path   shader folder (default: data/shaders)
 *   SHADERFIX_DUMP=/path   dump folder (default: shaderfix_dump), "off" disables it
 *
 * Build: gcc -O2 -shared -fPIC -o libshaderfix.so shaderfix.c -ldl
 */
#define _GNU_SOURCE
#include <dirent.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#define LOG(...) fprintf(stderr, "[shaderfix] " __VA_ARGS__)

typedef void  (*ShaderSourceFn)(unsigned, int, const char *const *, const int *);
typedef void  (*CompileShaderFn)(unsigned);
typedef void  (*GetShaderivFn)(unsigned, unsigned, int *);
typedef void  (*GetShaderInfoLogFn)(unsigned, int, int *, char *);
typedef void *(*GetProcFn)(const char *);
typedef void *(*DlsymFn)(void *, const char *);

/* ---------- files in data/shaders ---------- */

#define MAX_FILES 128
static struct { char *name, *text; size_t len; int warned; } files[MAX_FILES];
static int n_files;

/* drop \r and trailing whitespace, in place */
static size_t normalize(char *s, size_t n)
{
    size_t w = 0;
    for (size_t r = 0; r < n; r++) if (s[r] != '\r') s[w++] = s[r];
    while (w && (s[w - 1] == '\n' || s[w - 1] == ' ' || s[w - 1] == '\t')) w--;
    s[w] = '\0';
    return w;
}

static void load_files(void)
{
    static int done;
    if (done) return;
    done = 1;

    const char *dir = getenv("SHADERFIX_DATA");
    if (!dir || !*dir) dir = "data/shaders";
    DIR *d = opendir(dir);
    if (!d) { LOG("cannot open %s, nothing will be replaced\n", dir); return; }

    struct dirent *e;
    while ((e = readdir(d)) && n_files < MAX_FILES) {
        size_t l = strlen(e->d_name);
        if (l < 5 || strcmp(e->d_name + l - 5, ".glsl")) continue;
        char path[1024];
        snprintf(path, sizeof path, "%s/%s", dir, e->d_name);
        FILE *f = fopen(path, "rb");
        if (!f) continue;
        fseek(f, 0, SEEK_END);
        long n = ftell(f);
        fseek(f, 0, SEEK_SET);
        char *t = n > 0 ? malloc((size_t)n + 1) : NULL;
        if (t && fread(t, 1, (size_t)n, f) == (size_t)n) {
            files[n_files].name = strdup(path);
            files[n_files].text = t;
            files[n_files].len  = normalize(t, (size_t)n);
            n_files++;
        } else free(t);
        fclose(f);
    }
    closedir(d);
    LOG("%d shaders loaded from %s\n", n_files, dir);
}

/* index of the data/shaders file that the source ends with, or -1 */
static int find_file(const char *src, size_t n)
{
    for (int i = 0; i < n_files; i++)
        if (files[i].len && files[i].len <= n &&
            !memcmp(src + n - files[i].len, files[i].text, files[i].len)) return i;
    return -1;
}

/* index of the data/shaders file with this name, or -1 */
static int find_name(const char *name)
{
    for (int i = 0; i < n_files; i++)
        if (!strcmp(strrchr(files[i].name, '/') + 1, name)) return i;
    return -1;
}

/* length of the leading #define / #version / blank lines */
static size_t prefix_len(const char *s)
{
    const char *p = s;
    while (*p) {
        const char *l = p;
        while (*l == ' ' || *l == '\t') l++;
        if (*l != '\n' && strncmp(l, "#define", 7) && strncmp(l, "#version", 8)) break;
        const char *nl = strchr(p, '\n');
        if (!nl) break;
        p = nl + 1;
    }
    return (size_t)(p - s);
}

/* ---------- dump ---------- */

static void dump(const char *tag, const char *text, size_t n)
{
    const char *dir = getenv("SHADERFIX_DUMP");
    if (dir && !strcmp(dir, "off")) return;
    if (!dir || !*dir) dir = "shaderfix_dump";
    mkdir(dir, 0755);

    uint64_t h = 0xcbf29ce484222325ULL;                         /* FNV-1a hash */
    for (size_t i = 0; i < n; i++) { h ^= (unsigned char)text[i]; h *= 0x100000001b3ULL; }

    char path[1024];
    snprintf(path, sizeof path, "%s/%s_%016llx.glsl", dir, tag, (unsigned long long)h);
    struct stat st;
    if (!stat(path, &st)) return;                               /* already dumped */
    FILE *f = fopen(path, "wb");
    if (f) { fwrite(text, 1, n, f); fclose(f); LOG("dump: %s\n", path); }
}

/* ---------- shader wrappers ---------- */

/* slot 0 = GLX: what the game sends (before gl4es) -> may be replaced
 * slot 1 = EGL: what reaches the GLES driver       -> dump + compile errors only */
static struct {
    const char        *tag;
    ShaderSourceFn     source;
    CompileShaderFn    compile;
    GetShaderivFn      getiv;
    GetShaderInfoLogFn getlog;
} slot[2] = { { "GLX", 0, 0, 0, 0 }, { "EGL", 0, 0, 0, 0 } };

/* the replacement text (prefix + your file) for a built-in shader, or NULL */
static char *replacement(unsigned sh, const char *src, size_t n)
{
    int f = find_file(src, n);
    if (f >= 0) {                                   /* one of your data/shaders files */
        if (!strstr(src, "v_ambientLight")) return NULL;
        if (!files[f].warned) {                     /* it would fail: use default instead */
            files[f].warned = 1;
            LOG("WARNING: %s uses v_ambientLight and will fail on libmali, loading default instead\n",
                files[f].name);
        }
    }

    int vs = strstr(src, "gl_Position") != NULL;
    const char *want = strstr(src, "v_ambientLight")  ? (vs ? "default.vertex.glsl" : "default.fragment.glsl")
                     : strstr(src, "PackedDepthFlag") ? (vs ? "depth.vertex.glsl"   : "depth.fragment.glsl")
                     : NULL;
    if (!want) return NULL;

    int r = find_name(want);
    if (r < 0) {
        LOG("WARNING: shader %u needs data/shaders/%s, not found; left untouched\n", sh, want);
        return NULL;
    }

    size_t p = prefix_len(src);
    char *out = malloc(p + files[r].len + 2);
    if (!out) return NULL;
    memcpy(out, src, p);
    memcpy(out + p, files[r].text, files[r].len);
    strcpy(out + p + files[r].len, "\n");
    LOG("shader %u: replaced by %s\n", sh, files[r].name);
    dump("GLX_replaced", out, strlen(out));
    return out;
}

static void shader_source(int si, unsigned sh, int count, const char *const *str, const int *len)
{
    load_files();

    /* join all chunks into one string */
    size_t n = 0;
    for (int i = 0; i < count; i++) n += (len && len[i] >= 0) ? (size_t)len[i] : strlen(str[i]);
    char *src = malloc(n + 1);
    if (!src) { slot[si].source(sh, count, str, len); return; }
    n = 0;
    for (int i = 0; i < count; i++) {
        size_t l = (len && len[i] >= 0) ? (size_t)len[i] : strlen(str[i]);
        memcpy(src + n, str[i], l);
        n += l;
    }
    n = normalize(src, n);
    dump(slot[si].tag, src, n);

    char *out = si == 0 ? replacement(sh, src, n) : NULL;
    if (out) { const char *p = out; slot[si].source(sh, 1, &p, NULL); free(out); }
    else       slot[si].source(sh, count, str, len);
    free(src);
}

static void compile_shader(int si, unsigned sh)
{
    slot[si].compile(sh);
    int ok = 1, n = 0;
    if (!slot[si].getiv) return;
    slot[si].getiv(sh, 0x8B81 /* GL_COMPILE_STATUS */, &ok);
    if (ok) return;
    LOG("%s COMPILE FAILED for shader %u\n", slot[si].tag, sh);
    slot[si].getiv(sh, 0x8B84 /* GL_INFO_LOG_LENGTH */, &n);
    char *log = (n > 1 && slot[si].getlog) ? malloc((size_t)n) : NULL;
    if (log) { slot[si].getlog(sh, n, NULL, log); LOG("%s\n", log); free(log); }
}

static void glx_source(unsigned a, int b, const char *const *c, const int *d) { shader_source(0, a, b, c, d); }
static void egl_source(unsigned a, int b, const char *const *c, const int *d) { shader_source(1, a, b, c, d); }
static void glx_compile(unsigned a) { compile_shader(0, a); }
static void egl_compile(unsigned a) { compile_shader(1, a); }

/* ---------- dlsym hook ---------- */

static DlsymFn real_dlsym;
static GetProcFn real_glx, real_glx_arb, real_egl;

/* swap glShaderSource / glCompileShader for our wrappers */
static void *wrap(int si, const char *name, void *p, GetProcFn gp, void *handle)
{
    int src = !strcmp(name, "glShaderSource")  || !strcmp(name, "glShaderSourceARB");
    int cmp = !strcmp(name, "glCompileShader") || !strcmp(name, "glCompileShaderARB");
    if (!p || (!src && !cmp)) return p;

    if (!slot[si].getiv)
        slot[si].getiv = (GetShaderivFn)(gp ? gp("glGetShaderiv") : real_dlsym(handle, "glGetShaderiv"));
    if (!slot[si].getlog)
        slot[si].getlog = (GetShaderInfoLogFn)(gp ? gp("glGetShaderInfoLog") : real_dlsym(handle, "glGetShaderInfoLog"));

    if (src) { slot[si].source  = (ShaderSourceFn)p;  return si ? (void *)egl_source  : (void *)glx_source; }
    slot[si].compile = (CompileShaderFn)p;
    return si ? (void *)egl_compile : (void *)glx_compile;
}

static void *my_glx(const char *n)     { return wrap(0, n, real_glx(n),     real_glx,     NULL); }
static void *my_glx_arb(const char *n) { return wrap(0, n, real_glx_arb(n), real_glx_arb, NULL); }
static void *my_egl(const char *n)     { return wrap(1, n, real_egl(n),     real_egl,     NULL); }

/* the only exported symbol: SDL3 gets every GL function through dlsym */
void *dlsym(void *handle, const char *name)
{
    if (!real_dlsym) real_dlsym = (DlsymFn)dlvsym(RTLD_NEXT, "dlsym", "GLIBC_2.34");
    if (!real_dlsym) real_dlsym = (DlsymFn)dlvsym(RTLD_NEXT, "dlsym", "GLIBC_2.17");
    if (!real_dlsym) return NULL;

    void *p = real_dlsym(handle, name);
    if (!p) return p;
    if (!strcmp(name, "glXGetProcAddress"))    { real_glx     = (GetProcFn)p; return (void *)my_glx; }
    if (!strcmp(name, "glXGetProcAddressARB")) { real_glx_arb = (GetProcFn)p; return (void *)my_glx_arb; }
    if (!strcmp(name, "eglGetProcAddress"))    { real_egl     = (GetProcFn)p; return (void *)my_egl; }

    /* direct lookups on libGL / gl4es (desktop GL side) */
    Dl_info info;
    if (dladdr(p, &info) && info.dli_fname) {
        const char *b = strrchr(info.dli_fname, '/');
        b = b ? b + 1 : info.dli_fname;
        if (!strncmp(b, "libGL.", 6) || !strncmp(b, "libGLX", 6) || strstr(b, "gl4es"))
            return wrap(0, name, p, NULL, handle);
    }
    return p;
}
