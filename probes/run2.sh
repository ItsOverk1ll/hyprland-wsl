#!/bin/bash
HERE=$(cd "$(dirname "$0")" && pwd)
D=/tmp/gfxprobe
cc -O2 -o $D/gfxprobe "$HERE/gfxprobe.c" $(pkg-config --cflags --libs libdrm gbm egl glesv2) || exit 1
f() { grep -E '^####|allocation|gbm_bo_create|export|GL_RENDERER|eglCreateImage|render target|pixels|mmap|texture:|speed|draw'; }
echo "#### software, vgem primary"; $D/gfxprobe $D/primary gbm:$D/primary 2>&1 | f
echo "#### D3D12 through GBM on vgem"; GALLIUM_DRIVER=d3d12 $D/gfxprobe $D/primary gbm:$D/primary 2>&1 | f
echo "#### D3D12 through EGL device 0 (the vgem device, Hyprland's first choice)"; GALLIUM_DRIVER=d3d12 $D/gfxprobe $D/primary dev:0 bench 2560x1440 2>&1 | f
echo "#### software 4 threads at 2560x1440"; LP_NUM_THREADS=4 $D/gfxprobe $D/primary gbm:$D/primary bench 2560x1440 2>&1 | f
