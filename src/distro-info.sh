#!/bin/sh
# Prints what the Windows-side launcher menu (windows/launcher.ps1) shows about a distro, as
# key=value lines. Read-only.
. /etc/os-release 2>/dev/null
echo "os=${PRETTY_NAME:-${NAME:-unknown}}"
if [ -x /usr/local/bin/hyprland-wsl ]; then
    echo "installed=1"
    HYPR_USER=
    [ -r /etc/hyprland-wsl.conf ] && . /etc/hyprland-wsl.conf
    echo "user=${HYPR_USER:-}"
    [ -x /etc/hyprland-wsl/first-start ] && echo "setup=1"
fi
command -v Hyprland > /dev/null 2>&1 && echo "hyprland=$(Hyprland --version 2> /dev/null | head -n 1 | awk '{print $2}')"
mesa=$(ls /usr/lib/*/libgallium-*.so /usr/lib/libgallium-*.so 2> /dev/null | sed -n 's/.*libgallium-\([0-9.]*\).*/\1/p' | head -n 1)
echo "mesa=${mesa%.}"
[ -e /dev/dxg ] && echo "gpu=1"
[ -f /etc/arch-release ] && echo "family=arch"
[ -f /etc/debian_version ] && echo "family=debian"
command -v omarchy-version > /dev/null 2>&1 && echo "omarchy=1"
exit 0
