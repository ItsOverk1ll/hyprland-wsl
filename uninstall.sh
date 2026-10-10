#!/bin/bash
# Removes what install.sh added, except packages, the user and the Hyprland config.

[ "$(id -u)" = 0 ] || exec sudo -- "$0" "$@"

rm -rf /opt/hyprland-wsl
rm -f /usr/local/bin/hyprland-wsl /etc/hyprland-wsl.conf
echo "Removed the launcher and the patched aquamarine."
echo "Packages, the user and ~/.config/hypr were left in place."
