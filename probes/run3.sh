#!/bin/bash
HERE=$(cd "$(dirname "$0")" && pwd)
D=/tmp/gfxprobe
cc -O2 -o $D/gfxprobe "$HERE/gfxprobe.c" $(pkg-config --cflags --libs libdrm gbm egl glesv2) || exit 1
f() { grep -E '^####|allocation|handed|handing|export|GL_RENDERER|eglCreateImage|render target|pixels|mmap|texture:|FAIL|warning'; }
echo "#### vgem buffer allocated by the software driver, imported by D3D12 in another process"
PROBE_HANDOVER=d3d12 $D/gfxprobe $D/primary surfaceless 2>&1 | f
echo "#### control: same handover, software driver on both sides"
PROBE_HANDOVER=llvmpipe $D/gfxprobe $D/primary surfaceless 2>&1 | f
echo "#### D3D12-allocated buffer imported by the software driver"
GALLIUM_DRIVER=d3d12 PROBE_HANDOVER=llvmpipe $D/gfxprobe $D/primary surfaceless 2>&1 | f
