#!/bin/bash
# Builds gfxprobe in /tmp and runs it against vgem and the D3D12 driver. Changes nothing installed.
HERE=$(cd "$(dirname "$0")" && pwd)
D=/tmp/gfxprobe
mkdir -p $D
. /etc/os-release
echo "##### $PRETTY_NAME, Mesa $(ls /usr/lib/x86_64-linux-gnu/libgallium-*.so /usr/lib/libgallium-*.so 2>/dev/null | head -n 1)"
cc -O2 -o $D/gfxprobe "$HERE/gfxprobe.c" $(pkg-config --cflags --libs libdrm gbm egl glesv2) || exit 1

modprobe vgem || exit 1
# Own device nodes with the real numbers, so a render node left redirected by the launcher does not matter.
card=
for c in /sys/class/drm/card[0-9]*; do
    case $(readlink -f "$c/device") in */vgem) card=$c ;; esac
done
render=$(ls "$card/device/drm" | grep '^renderD' | head -n 1)
IFS=: read -r ma mi < "$card/dev"; rm -f $D/primary; mknod $D/primary c "$ma" "$mi"
IFS=: read -r ma mi < "/sys/class/drm/$render/dev"; rm -f $D/render; mknod $D/render c "$ma" "$mi"
echo "vgem: ${card##*/} ($(cat "$card/dev")) and $render ($(cat /sys/class/drm/$render/dev)); /dev/dri/$render is currently $(stat -c '%t:%T' /dev/dri/$render 2>/dev/null) (hex)"
echo "dxg: $(ls -l /dev/dxg 2>&1)"
echo "d3d12 libs on the loader path: $(ldconfig -p | grep -cE 'libd3d12|libdxcore')"

run() {
    local title=$1; shift
    printf '\n################ %s\n' "$title"
    timeout 120 "$@" 2>&1 | grep -v '^$'
    echo "(exit ${PIPESTATUS[0]})"
}

B="bench ${BENCH:-3840x2160}"
run "1a. vgem primary node, software EGL through GBM on the same node" \
    env LP_NUM_THREADS=4 $D/gfxprobe $D/primary gbm:$D/primary $B
run "1b. vgem render node for everything (what fails without the node trick)" \
    $D/gfxprobe $D/render gbm:$D/render
run "1c. allocate on the primary node, EGL through GBM on the render node" \
    $D/gfxprobe $D/primary gbm:$D/render
run "1d. allocate on the primary node, EGL device 0" \
    $D/gfxprobe $D/primary dev:0
run "1e. allocate on the primary node, EGL device 1" \
    $D/gfxprobe $D/primary dev:1
run "2a. no DRM device, surfaceless EGL, driver left to Mesa" \
    $D/gfxprobe none surfaceless $B
run "2b. no DRM device, surfaceless EGL, D3D12 requested" \
    env GALLIUM_DRIVER=d3d12 $D/gfxprobe none surfaceless $B
run "2c. no DRM device, surfaceless EGL, D3D12 on the NVIDIA adapter" \
    env GALLIUM_DRIVER=d3d12 MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA $D/gfxprobe none surfaceless $B
run "2d. software baseline for speed, 4 threads" \
    env LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe LP_NUM_THREADS=4 $D/gfxprobe none surfaceless $B
run "3a. vgem buffer imported by D3D12 (surfaceless)" \
    env GALLIUM_DRIVER=d3d12 $D/gfxprobe $D/primary surfaceless
run "3b. vgem buffer, EGL through GBM on vgem, D3D12 requested" \
    env GALLIUM_DRIVER=d3d12 $D/gfxprobe $D/primary gbm:$D/primary $B
