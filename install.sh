#!/bin/bash
# Installs Hyprland under WSL2, plus everything needed to show it on the Windows desktop.
# Supports Arch-based distros (pacman) and Debian/Ubuntu-based distros (apt).
# Run from a clone of this repository:  sudo ./install.sh
#
# Environment:
#   HYPR_USER   user that Hyprland runs as (default: the invoking user, else the first
#               regular user, else a new user called "hypr")

set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX=/opt/hyprland-wsl
CONF=/etc/hyprland-wsl.conf

die() { echo "error: $*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

if [ "$(id -u)" != 0 ]; then
    command -v sudo >/dev/null || die "run this as root (sudo is not installed)"
    exec sudo env HYPR_USER="${HYPR_USER:-$USER}" "$0" "$@"
fi

step "Checking the environment"
. /etc/os-release
case " $ID ${ID_LIKE:-} " in
    *" arch "*) FAMILY=arch ;;
    *" debian "*|*" ubuntu "*) FAMILY=debian ;;
    *) die "unsupported distro '$ID'; supported are Arch-based and Debian/Ubuntu-based ones" ;;
esac
echo "$PRETTY_NAME ($FAMILY family)"
grep -qi microsoft /proc/version || die "this does not look like WSL2"
ls "$HERE"/patches/headless-drm*.patch >/dev/null 2>&1 && [ -f "$HERE/hyprland-wsl" ] ||
    die "run install.sh from a clone of the repository"
modinfo vgem >/dev/null 2>&1 || die "the WSL kernel has no vgem module; update WSL with 'wsl --update'"
[ -d /mnt/wslg ] || echo "warning: WSLg not found; the viewer window will not work, use 'hyprland-wsl --no-viewer'"

# Ubuntu 24.04 and what is built on it (Linux Mint 22.x) have no hyprland package. A
# third-party PPA has one; it is only added with the user's consent.
add_ppa() {
    local ppa=cppiber/hyprland series=${UBUNTU_CODENAME:-} answer=${HYPRLAND_PPA:-} fp
    local url=https://ppa.launchpadcontent.net/$ppa/ubuntu
    [ -n "$series" ] && curl -fsI "$url/dists/$series/Release" >/dev/null 2>&1 ||
        die "this release of $NAME has no hyprland package, and no PPA is known for it"
    echo "This release of $NAME has no hyprland package."
    echo "The third-party PPA ppa:$ppa (not part of $NAME, not checked by this project) provides one."
    if [ -z "$answer" ] && [ -t 0 ]; then
        read -r -p "Add that PPA and install Hyprland from it? [y/N] " answer
    fi
    case $answer in
        1|y|Y|yes) ;;
        *) die "not adding the PPA; rerun with HYPRLAND_PPA=1 to allow it" ;;
    esac
    fp=$(curl -fsSL "https://api.launchpad.net/1.0/~${ppa%/*}/+archive/ubuntu/${ppa#*/}" |
        sed -n 's/.*"signing_key_fingerprint": "\([0-9A-F]*\)".*/\1/p')
    [ -n "$fp" ] || die "could not look up the PPA's signing key"
    mkdir -p /etc/apt/keyrings
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x$fp" -o /etc/apt/keyrings/hyprland-wsl-ppa.asc
    echo "deb [signed-by=/etc/apt/keyrings/hyprland-wsl-ppa.asc] $url $series main" \
        > /etc/apt/sources.list.d/hyprland-wsl-ppa.list
    apt-get update
    apt-cache show hyprland >/dev/null 2>&1 || die "the PPA did not provide a hyprland package"
}

step "Installing packages"
case $FAMILY in
arch)
    pacman-key --init
    pacman-key --populate
    # A full upgrade, because Arch does not support installing onto a partly updated system.
    pacman -Syu --noconfirm --needed \
        hyprland foot mesa wayvnc tigervnc sudo ttf-dejavu curl \
        base-devel cmake ninja hyprwayland-scanner wayland-protocols
    ;;
debian)
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends curl ca-certificates
    apt-cache show hyprland >/dev/null 2>&1 || add_ppa
    apt-get install -y --no-install-recommends \
        hyprland foot wayvnc tigervnc-viewer sudo fonts-dejavu-core \
        libgl1-mesa-dri libegl1 libgles2 xkb-data \
        curl ca-certificates patch build-essential cmake ninja-build pkg-config \
        hyprwayland-scanner libhyprutils-dev libwayland-dev wayland-protocols libseat-dev \
        libinput-dev libpixman-1-dev libdrm-dev libgbm-dev libudev-dev libdisplay-info-dev \
        hwdata libegl-dev libgles-dev libgl-dev libopengl-dev
    ;;
esac

step "Choosing the user"
U=${HYPR_USER:-${SUDO_USER:-}}
[ "$U" = root ] && U=
[ -n "$U" ] || U=$(awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }' /etc/passwd)
[ -n "$U" ] || U=hypr
if ! id "$U" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$U"
    echo "created user $U"
fi
H=$(getent passwd "$U" | cut -d: -f6)
echo "Hyprland will run as $U"

step "Building the patched aquamarine"
# The patched copy has to be the exact version Hyprland was built against, so the version
# comes from the installed library's file name (libaquamarine.so.X.Y.Z).
syslib=$(ldconfig -p | awk '/libaquamarine\.so\.[0-9]+ / { print $NF; exit }')
[ -n "$syslib" ] || die "libaquamarine is not installed; the hyprland package should have pulled it in"
srcver=$(basename "$(readlink -f "$syslib")")
srcver=${srcver#libaquamarine.so.}
stamp="$srcver $(cat "$HERE"/patches/headless-drm*.patch | sha256sum | cut -d' ' -f1)"
if [ "$(cat $PREFIX/aquamarine/STAMP 2>/dev/null)" = "$stamp" ]; then
    echo "already built for aquamarine $srcver"
else
    build=$(mktemp -d)
    trap 'rm -rf "$build"' EXIT
    curl -fsSL "https://github.com/hyprwm/aquamarine/archive/refs/tags/v$srcver.tar.gz" | tar xz -C "$build"
    src=$build/aquamarine-$srcver
    # The patch exists in one variant per layout of the patched file; use the one that fits.
    applied=
    for p in "$HERE"/patches/headless-drm*.patch; do
        if patch -d "$src" -p1 --dry-run -s -f < "$p" >/dev/null 2>&1; then
            patch -d "$src" -p1 -s < "$p"
            applied=$(basename "$p")
            break
        fi
    done
    [ -n "$applied" ] || die "no patch in patches/ applies to aquamarine $srcver"
    echo "aquamarine $srcver, patched with $applied"
    cmake -S "$src" -B "$src/build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$PREFIX/aquamarine -DCMAKE_INSTALL_LIBDIR=lib
    cmake --build "$src/build"
    rm -rf $PREFIX/aquamarine
    cmake --install "$src/build" > /dev/null
    echo "$srcver" > $PREFIX/aquamarine/VERSION
    echo "$stamp" > $PREFIX/aquamarine/STAMP
fi

step "Installing the launcher"
install -m 755 "$HERE/hyprland-wsl" /usr/local/bin/hyprland-wsl
echo "HYPR_USER=$U" > $CONF

step "Preparing the Hyprland config"
lua=$H/.config/hypr/hyprland.lua
conf=$H/.config/hypr/hyprland.conf
if [ -e "$lua" ] || [ -e "$conf" ]; then
    echo "existing config left untouched"
else
    # Hyprland writes its default config when asked to verify a missing one.
    tmp=$(mktemp -d) && chown "$U": "$tmp"
    sudo -u "$U" env -u WAYLAND_DISPLAY -u DISPLAY HOME="$H" XDG_RUNTIME_DIR="$tmp" \
        sh -c 'cd "$HOME" && Hyprland --verify-config' > /dev/null 2>&1 || true
    rm -rf "$tmp"
    if [ -f "$lua" ]; then
        # Hyprland 0.55 and later: Lua config.
        sed -i -e '/autogenerated = true/d' \
               -e 's/^local terminal    = "kitty"/local terminal    = "foot"/' \
               -e 's/^local mainMod = "SUPER".*/local mainMod = "ALT" -- ALT, because Windows keeps the Windows key for itself/' \
               -e 's/^    scale    = "auto",/    scale    = 1,/' "$lua"
        echo 'hl.on("hyprland.start", function() hl.exec_cmd(terminal) end)' >> "$lua"
        echo "wrote $lua (main modifier: ALT, terminal: foot)"
    elif [ -f "$conf" ]; then
        # Older Hyprland: hyprland.conf.
        sed -i -e '/^autogenerated *= *1/d' \
               -e 's/^\$terminal = kitty/$terminal = foot/' \
               -e 's/^\$mainMod = SUPER.*/$mainMod = ALT # ALT, because Windows keeps the Windows key for itself/' \
               -e 's/^monitor=,preferred,auto,auto/monitor=,preferred,auto,1/' "$conf"
        echo 'exec-once = $terminal' >> "$conf"
        echo "wrote $conf (main modifier: ALT, terminal: foot)"
    else
        die "Hyprland did not generate a config in $H/.config/hypr"
    fi
fi

step "Done"
echo "Start Hyprland with:  hyprland-wsl"
echo "From Windows:         wsl -d ${WSL_DISTRO_NAME:-<distro>} hyprland-wsl"
