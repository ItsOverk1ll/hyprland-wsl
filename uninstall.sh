#!/bin/bash
# Removes what install.sh added, except packages, the user and the Hyprland config.

[ "$(id -u)" = 0 ] || exec sudo -- "$0" "$@"

rm -rf /opt/hyprland-wsl
rm -f /usr/local/bin/hyprland-wsl /etc/hyprland-wsl.conf
echo "Removed the launcher and the patched aquamarine."
echo "Packages, the user and ~/.config/hypr were left in place."
if [ -e /etc/apt/sources.list.d/hyprland-wsl-ppa.list ]; then
    echo "The Hyprland PPA was left in place too, because the installed hyprland package comes from it."
    echo "To drop it: rm /etc/apt/sources.list.d/hyprland-wsl-ppa.list /etc/apt/keyrings/hyprland-wsl-ppa.asc"
fi
