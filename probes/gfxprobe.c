// gfxprobe: what can a DRM node allocate, and what can an EGL driver do with it?
//   gfxprobe <alloc-node|none> <gbm:NODE | dev:N | surfaceless> [bench WxH]
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/mman.h>
#include <xf86drm.h>
#include <gbm.h>
#include <drm_fourcc.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES3/gl3.h>
#include <GLES2/gl2ext.h>

#ifndef EGL_DRM_RENDER_NODE_FILE_EXT
#define EGL_DRM_RENDER_NODE_FILE_EXT 0x3377
#endif

static int has(const char* list, const char* name) { return list && strstr(list, name) != NULL; }
static double now_ms(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1000.0 + t.tv_nsec / 1e6;
}
static void show(const char* label, const char* list, const char** names) {
    printf("  %s:", label);
    for (; *names; names++)
        printf(" %s=%s", *names, has(list, *names) ? "yes" : "NO");
    printf("\n");
}

static GLuint shader(GLenum type, const char* src) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, NULL);
    glCompileShader(s);
    GLint ok = 0;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[512];
        glGetShaderInfoLog(s, sizeof log, NULL, log);
        printf("  shader compile failed: %s\n", log);
    }
    return s;
}

int main(int argc, char** argv) {
    if (argc < 3) return 2;
    const char* node = argv[1];
    const char* mode = argv[2];
    int         BW = 0, BH = 0;
    if (argc >= 5 && !strcmp(argv[3], "bench")) sscanf(argv[4], "%dx%d", &BW, &BH);
    setvbuf(stdout, NULL, _IONBF, 0);

    const int          W = 1280, H = 720;
    struct gbm_device* gbm = NULL;
    struct gbm_bo*     bo  = NULL;
    int                dfd = -1;
    uint32_t           stride = 0;
    uint64_t           mod = DRM_FORMAT_MOD_INVALID;

    printf("== allocation on %s\n", node);
    if (getenv("PROBE_FD")) {
        dfd = atoi(getenv("PROBE_FD"));
        stride = (uint32_t)atoi(getenv("PROBE_STRIDE"));
        mod = DRM_FORMAT_MOD_LINEAR;
        printf("  using dmabuf fd %d handed over by the allocating process\n", dfd);
    } else if (strcmp(node, "none")) {
        int fd = open(node, O_RDWR | O_CLOEXEC);
        if (fd < 0) { printf("  open: FAIL %s\n", strerror(errno)); return 1; }
        drmVersion* v = drmGetVersion(fd);
        uint64_t    prime = 0, dumb = 0, tl = 0;
        drmGetCap(fd, DRM_CAP_PRIME, &prime);
        drmGetCap(fd, DRM_CAP_DUMB_BUFFER, &dumb);
        drmGetCap(fd, DRM_CAP_SYNCOBJ_TIMELINE, &tl);
        printf("  driver=%s nodetype=%s prime_export=%d prime_import=%d dumb=%d syncobj_timeline=%d\n", v ? v->name : "?",
               drmGetNodeTypeFromFd(fd) == DRM_NODE_PRIMARY ? "primary" : "render", !!(prime & DRM_PRIME_CAP_EXPORT), !!(prime & DRM_PRIME_CAP_IMPORT), (int)dumb, (int)tl);
        gbm = gbm_create_device(fd);
        if (!gbm) { printf("  gbm_create_device: FAIL\n"); return 1; }
        printf("  gbm backend=%s\n", gbm_device_get_backend_name(gbm));
        // What aquamarine does for an output buffer: XRGB8888, RENDERING|SCANOUT, modifier list {LINEAR}.
        uint64_t lin = DRM_FORMAT_MOD_LINEAR;
        uint32_t flags = GBM_BO_USE_RENDERING | GBM_BO_USE_SCANOUT;
        errno = 0;
        bo = gbm_bo_create_with_modifiers2(gbm, W, H, GBM_FORMAT_XRGB8888, &lin, 1, flags);
        printf("  gbm_bo_create_with_modifiers2(LINEAR, RENDERING|SCANOUT): %s%s%s\n", bo ? "ok" : "FAIL", bo ? "" : " ", bo ? "" : strerror(errno));
        struct { const char* n; uint32_t f; } tries[] = {{"RENDERING|SCANOUT|LINEAR", flags | GBM_BO_USE_LINEAR}, {"RENDERING|SCANOUT", flags},
                                                         {"RENDERING|LINEAR", GBM_BO_USE_RENDERING | GBM_BO_USE_LINEAR}, {"RENDERING", GBM_BO_USE_RENDERING}};
        for (int i = 0; i < 4; i++) {
            errno = 0;
            struct gbm_bo* t = gbm_bo_create(gbm, W, H, GBM_FORMAT_XRGB8888, tries[i].f);
            printf("  gbm_bo_create(%s): %s\n", tries[i].n, t ? "ok" : "FAIL");
            if (t && !bo) bo = t;
            else if (t) gbm_bo_destroy(t);
        }
        if (bo) {
            dfd    = gbm_bo_get_fd_for_plane(bo, 0);
            stride = gbm_bo_get_stride_for_plane(bo, 0);
            mod    = gbm_bo_get_modifier(bo);
            printf("  export as dmabuf: %s (fd %d, stride %u, modifier 0x%llx, planes %d)\n", dfd >= 0 ? "ok" : "FAIL", dfd, stride, (unsigned long long)mod,
                   gbm_bo_get_plane_count(bo));
            uint32_t s2 = 0;
            void*    md = NULL;
            void*    p  = gbm_bo_map(bo, 0, 0, W, H, GBM_BO_TRANSFER_READ_WRITE, &s2, &md);
            printf("  CPU map: %s\n", p ? "ok" : "FAIL");
            if (p) {
                memset(p, 0x11, (size_t)s2 * H);
                gbm_bo_unmap(bo, md);
            }
        }
        if (getenv("PROBE_HANDOVER") && dfd >= 0) {
            char a[32], b[32];
            snprintf(a, sizeof a, "%d", dfd);
            snprintf(b, sizeof b, "%u", stride);
            fcntl(dfd, F_SETFD, 0);
            setenv("PROBE_FD", a, 1);
            setenv("PROBE_STRIDE", b, 1);
            setenv("GALLIUM_DRIVER", getenv("PROBE_HANDOVER"), 1);
            unsetenv("PROBE_HANDOVER");
            printf("  handing the buffer to a new process that uses the %s driver\n", getenv("GALLIUM_DRIVER"));
            char* args[] = {argv[0], "none", (char*)mode, NULL};
            execv("/proc/self/exe", args);
        }
    } else
        printf("  skipped\n");

    printf("== EGL (%s)\n", mode);
    const char* cext = eglQueryString(EGL_NO_DISPLAY, EGL_EXTENSIONS);
    const char* cnames[] = {"EGL_EXT_platform_device", "EGL_KHR_platform_gbm", "EGL_MESA_platform_surfaceless", "EGL_EXT_device_query", "EGL_EXT_device_enumeration", NULL};
    show("client", cext, cnames);

    PFNEGLQUERYDEVICESEXTPROC       qdev = (void*)eglGetProcAddress("eglQueryDevicesEXT");
    PFNEGLQUERYDEVICESTRINGEXTPROC  qstr = (void*)eglGetProcAddress("eglQueryDeviceStringEXT");
    PFNEGLGETPLATFORMDISPLAYEXTPROC gpd  = (void*)eglGetProcAddress("eglGetPlatformDisplayEXT");
    EGLDeviceEXT                    devs[16];
    EGLint                          ndev = 0;
    if (qdev && qdev(16, devs, &ndev)) {
        for (int i = 0; i < ndev; i++) {
            const char* de = qstr(devs[i], EGL_EXTENSIONS);
            const char* f  = has(de, "EGL_EXT_device_drm") ? qstr(devs[i], EGL_DRM_DEVICE_FILE_EXT) : NULL;
            const char* r  = has(de, "EGL_EXT_device_drm_render_node") ? qstr(devs[i], EGL_DRM_RENDER_NODE_FILE_EXT) : NULL;
            printf("  device %d: drm=%s render=%s exts=%s\n", i, f ? f : "-", r ? r : "-", de ? de : "");
        }
    } else
        printf("  no EGL device enumeration\n");

    EGLDisplay dpy = EGL_NO_DISPLAY;
    if (!strncmp(mode, "gbm:", 4)) {
        int efd = open(mode + 4, O_RDWR | O_CLOEXEC);
        if (efd < 0) { printf("  open %s: FAIL %s\n", mode + 4, strerror(errno)); return 1; }
        struct gbm_device* eg = gbm_create_device(efd);
        if (!eg) { printf("  gbm device for EGL: FAIL\n"); return 1; }
        dpy = gpd(EGL_PLATFORM_GBM_KHR, eg, NULL);
    } else if (!strncmp(mode, "dev:", 4)) {
        int n = atoi(mode + 4);
        if (n >= ndev) { printf("  no device %d\n", n); return 0; }
        dpy = gpd(EGL_PLATFORM_DEVICE_EXT, devs[n], NULL);
    } else
        dpy = gpd(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, NULL);

    EGLint maj = 0, min = 0;
    if (dpy == EGL_NO_DISPLAY || !eglInitialize(dpy, &maj, &min)) { printf("  eglInitialize: FAIL 0x%x\n", eglGetError()); return 1; }
    const char* dext = eglQueryString(dpy, EGL_EXTENSIONS);
    printf("  EGL %d.%d, vendor %s\n", maj, min, eglQueryString(dpy, EGL_VENDOR));
    const char* dnames[] = {"EGL_KHR_surfaceless_context", "EGL_KHR_no_config_context", "EGL_EXT_image_dma_buf_import ", "EGL_EXT_image_dma_buf_import_modifiers",
                            "EGL_KHR_image_base", "EGL_KHR_fence_sync", "EGL_ANDROID_native_fence_sync", "EGL_MESA_image_dma_buf_export", "EGL_KHR_wait_sync", NULL};
    show("display", dext, dnames);

    eglBindAPI(EGL_OPENGL_ES_API);
    EGLint     a32[] = {EGL_CONTEXT_MAJOR_VERSION, 3, EGL_CONTEXT_MINOR_VERSION, 2, EGL_NONE};
    EGLint     a30[] = {EGL_CONTEXT_MAJOR_VERSION, 3, EGL_CONTEXT_MINOR_VERSION, 0, EGL_NONE};
    EGLContext ctx   = eglCreateContext(dpy, EGL_NO_CONFIG_KHR, EGL_NO_CONTEXT, a32);
    const char* cv   = "3.2";
    if (ctx == EGL_NO_CONTEXT) { ctx = eglCreateContext(dpy, EGL_NO_CONFIG_KHR, EGL_NO_CONTEXT, a30); cv = "3.0"; }
    if (ctx == EGL_NO_CONTEXT) { printf("  GLES3 context without a config: FAIL 0x%x\n", eglGetError()); return 1; }
    if (!eglMakeCurrent(dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, ctx)) { printf("  make current without a surface: FAIL 0x%x\n", eglGetError()); return 1; }
    const char* gext = (const char*)glGetString(GL_EXTENSIONS);
    printf("  context %s, surfaceless: ok\n  GL_RENDERER: %s\n  GL_VERSION: %s\n", cv, glGetString(GL_RENDERER), glGetString(GL_VERSION));
    const char* gnames[] = {"GL_EXT_texture_format_BGRA8888", "GL_EXT_read_format_bgra", "GL_OES_EGL_image ", "GL_OES_EGL_image_external", NULL};
    show("GL", gext, gnames);

    // Milestone: draws at all.
    GLuint fb, tx;
    glGenFramebuffers(1, &fb);
    glGenTextures(1, &tx);
    glBindTexture(GL_TEXTURE_2D, tx);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 64, 64, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glBindFramebuffer(GL_FRAMEBUFFER, fb);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tx, 0);
    glClearColor(0.0f, 1.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    unsigned char px[4] = {0};
    glReadPixels(1, 1, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, px);
    printf("== draw into its own texture: %s (read back %d,%d,%d,%d)\n", px[1] == 255 && px[0] == 0 ? "ok" : "FAIL", px[0], px[1], px[2], px[3]);

    // Milestone: use the other device's buffer.
    printf("== import the allocated buffer\n");
    if (dfd >= 0) {
        PFNEGLCREATEIMAGEKHRPROC                      mkimg = (void*)eglGetProcAddress("eglCreateImageKHR");
        PFNGLEGLIMAGETARGETRENDERBUFFERSTORAGEOESPROC rbimg = (void*)eglGetProcAddress("glEGLImageTargetRenderbufferStorageOES");
        PFNGLEGLIMAGETARGETTEXTURE2DOESPROC           tximg = (void*)eglGetProcAddress("glEGLImageTargetTexture2DOES");
        EGLint                                        at[32];
        int                                           n = 0;
        at[n++] = EGL_WIDTH; at[n++] = W;
        at[n++] = EGL_HEIGHT; at[n++] = H;
        at[n++] = EGL_LINUX_DRM_FOURCC_EXT; at[n++] = DRM_FORMAT_XRGB8888;
        at[n++] = EGL_DMA_BUF_PLANE0_FD_EXT; at[n++] = dfd;
        at[n++] = EGL_DMA_BUF_PLANE0_OFFSET_EXT; at[n++] = 0;
        at[n++] = EGL_DMA_BUF_PLANE0_PITCH_EXT; at[n++] = stride;
        if (has(dext, "EGL_EXT_image_dma_buf_import_modifiers") && mod != DRM_FORMAT_MOD_INVALID) {
            at[n++] = EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT; at[n++] = (EGLint)(mod & 0xffffffff);
            at[n++] = EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT; at[n++] = (EGLint)(mod >> 32);
        }
        at[n++] = EGL_NONE;
        EGLImageKHR img = mkimg ? mkimg(dpy, EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT, NULL, at) : EGL_NO_IMAGE_KHR;
        printf("  eglCreateImage from dmabuf: %s (egl error 0x%x)\n", img != EGL_NO_IMAGE_KHR ? "ok" : "FAIL", eglGetError());
        if (img != EGL_NO_IMAGE_KHR) {
            GLuint rb, fb2;
            glGenRenderbuffers(1, &rb);
            glBindRenderbuffer(GL_RENDERBUFFER, rb);
            rbimg(GL_RENDERBUFFER, img);
            GLenum e1 = glGetError();
            glGenFramebuffers(1, &fb2);
            glBindFramebuffer(GL_FRAMEBUFFER, fb2);
            glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, rb);
            GLenum st = glCheckFramebufferStatus(GL_FRAMEBUFFER);
            printf("  as render target: %s (gl error 0x%x, framebuffer status 0x%x)\n", st == GL_FRAMEBUFFER_COMPLETE && !e1 ? "ok" : "FAIL", e1, st);
            if (st == GL_FRAMEBUFFER_COMPLETE) {
                glViewport(0, 0, W, H);
                glClearColor(1.0f, 0.0f, 0.0f, 1.0f);
                glClear(GL_COLOR_BUFFER_BIT);
                glFinish();
                uint32_t s2 = 0;
                void*    md = NULL;
                uint8_t* p  = bo ? gbm_bo_map(bo, 0, 0, W, H, GBM_BO_TRANSFER_READ, &s2, &md) : NULL;
                if (p) {
                    uint8_t* q = p + (size_t)s2 * (H / 2) + 4 * (W / 2);
                    printf("  drawn pixels arrive in the allocator's memory: %s (B,G,R,X = %d,%d,%d,%d; expected 0,0,255)\n", q[2] == 255 && q[0] == 0 && q[1] == 0 ? "ok" : "FAIL", q[0],
                           q[1], q[2], q[3]);
                    gbm_bo_unmap(bo, md);
                }
                // Same check without going through any driver: map the dmabuf itself.
                uint8_t* raw = mmap(NULL, (size_t)stride * H, PROT_READ, MAP_SHARED, dfd, 0);
                if (raw == MAP_FAILED)
                    printf("  direct mmap of the dmabuf: FAIL %s\n", strerror(errno));
                else {
                    uint8_t* q = raw + (size_t)stride * (H / 2) + 4 * (W / 2);
                    printf("  pixels in the dmabuf's own memory (no driver involved): %s (B,G,R,X = %d,%d,%d,%d)\n", q[2] == 255 && q[0] == 0 && q[1] == 0 ? "ok" : "NOT THERE", q[0], q[1],
                           q[2], q[3]);
                }
            }
            GLuint t2;
            glGenTextures(1, &t2);
            glBindTexture(GL_TEXTURE_2D, t2);
            tximg(GL_TEXTURE_2D, img);
            printf("  as texture: %s\n", glGetError() == GL_NO_ERROR ? "ok" : "FAIL");
        }
    } else
        printf("  skipped (nothing allocated)\n");

    // The fence calls Hyprland asserts on.
    printf("== sync fences\n");
    PFNEGLCREATESYNCKHRPROC            mksync = (void*)eglGetProcAddress("eglCreateSyncKHR");
    PFNEGLDUPNATIVEFENCEFDANDROIDPROC  dupfd  = (void*)eglGetProcAddress("eglDupNativeFenceFDANDROID");
    PFNEGLWAITSYNCKHRPROC              wsync  = (void*)eglGetProcAddress("eglWaitSyncKHR");
    PFNEGLCLIENTWAITSYNCKHRPROC        cwsync = (void*)eglGetProcAddress("eglClientWaitSyncKHR");
    printf("  functions present: eglCreateSyncKHR=%s eglDupNativeFenceFDANDROID=%s eglWaitSyncKHR=%s\n", mksync ? "yes" : "NO", dupfd ? "yes" : "NO", wsync ? "yes" : "NO");
    if (mksync) {
        glBindFramebuffer(GL_FRAMEBUFFER, fb);
        glClear(GL_COLOR_BUFFER_BIT);
        EGLSyncKHR s = mksync(dpy, EGL_SYNC_FENCE_KHR, NULL);
        printf("  plain fence: %s\n", s != EGL_NO_SYNC_KHR ? "ok" : "FAIL");
        if (s != EGL_NO_SYNC_KHR && cwsync) {
            glFlush();
            printf("  wait on it: 0x%x (0x30f6 = signalled)\n", cwsync(dpy, s, 0, 1000000000));
        }
        glClear(GL_COLOR_BUFFER_BIT);
        EGLSyncKHR n = mksync(dpy, EGL_SYNC_NATIVE_FENCE_ANDROID, NULL);
        printf("  native fence: %s (egl error 0x%x)\n", n != EGL_NO_SYNC_KHR ? "ok" : "FAIL", eglGetError());
        if (n != EGL_NO_SYNC_KHR && dupfd) {
            glFlush();
            int f = dupfd(dpy, n);
            printf("  export native fence as fd: %s (fd %d)\n", f >= 0 ? "ok" : "FAIL", f);
        }
    }

    if (BW > 0) {
        printf("== speed at %dx%d (25 texture samples per pixel, like a blur pass)\n", BW, BH);
        static const char* VS = "#version 300 es\nout vec2 uv;void main(){vec2 p=vec2(float((gl_VertexID<<1)&2),float(gl_VertexID&2));uv=p;gl_Position=vec4(p*2.0-1.0,0.0,1.0);}";
        static const char* FS = "#version 300 es\nprecision mediump float;in vec2 uv;out vec4 o;uniform sampler2D t;void main(){vec4 s=vec4(0.0);for(int y=-2;y<=2;y++)for(int "
                                "x=-2;x<=2;x++)s+=texture(t,uv+vec2(float(x),float(y))/512.0);o=s/25.0;}";
        GLuint             pr = glCreateProgram();
        glAttachShader(pr, shader(GL_VERTEX_SHADER, VS));
        glAttachShader(pr, shader(GL_FRAGMENT_SHADER, FS));
        glLinkProgram(pr);
        glUseProgram(pr);
        GLuint   src, dst, bfb, vao;
        uint8_t* pat = malloc(1024 * 1024 * 4);
        for (int i = 0; i < 1024 * 1024 * 4; i++) pat[i] = (uint8_t)(i * 37);
        glGenTextures(1, &src);
        glBindTexture(GL_TEXTURE_2D, src);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 1024, 1024, 0, GL_RGBA, GL_UNSIGNED_BYTE, pat);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glGenTextures(1, &dst);
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, dst);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, BW, BH, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, src);
        glGenFramebuffers(1, &bfb);
        glBindFramebuffer(GL_FRAMEBUFFER, bfb);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, dst, 0);
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);
        glViewport(0, 0, BW, BH);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        glFinish();
        const int N  = 10;
        double    t0 = now_ms();
        for (int i = 0; i < N; i++) {
            glDrawArrays(GL_TRIANGLES, 0, 3);
            glFinish();
        }
        double   t1  = now_ms();
        uint8_t* out = malloc((size_t)BW * BH * 4);
        glReadPixels(0, 0, BW, BH, GL_RGBA, GL_UNSIGNED_BYTE, out);
        double t2 = now_ms();
        for (int i = 0; i < 5; i++) {
            glDrawArrays(GL_TRIANGLES, 0, 3);
            glReadPixels(0, 0, BW, BH, GL_RGBA, GL_UNSIGNED_BYTE, out);
        }
        double t3 = now_ms();
        printf("  draw: %.1f ms per frame\n  draw + copy the whole frame back to RAM: %.1f ms per frame\n  gl error 0x%x, sample pixel %d,%d,%d\n", (t1 - t0) / N, (t3 - t2) / 5,
               glGetError(), out[0], out[1], out[2]);
    }
    return 0;
}
