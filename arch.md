# Arch Linux

Arch is the best-supported distro: Hyprland comes from its own repositories at the newest
version, and it renders on the GPU at a steady 60 updates a second at 1920x1080.

## With the menu

`hyprland-wsl` → **+ New distro** → **Arch Linux**, then the form.

## One command

```powershell
& "$env:LOCALAPPDATA\hyprland-wsl\repo\windows\new-distro.ps1" -Distro arch -Name arch -User me
```

Options: `-Location D:\WSL\arch`, `-Hostname`, `-Mod ALT`, `-SetDefault`, `-Start`.

## By hand

In PowerShell:

```powershell
wsl --install archlinux --name arch --location C:\WSL\arch --no-launch
wsl -d arch -u root
```

Inside, as root (replace `me` with your user name):

```sh
pacman-key --init && pacman-key --populate
pacman -Syu --needed --noconfirm git sudo
useradd -m -G wheel me && passwd me
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
printf '[user]\ndefault=me\n' >> /etc/wsl.conf
git clone https://github.com/ItsOverk1ll/hyprland-wsl /opt/hyprland-wsl-src
HYPR_USER=me bash /opt/hyprland-wsl-src/install.sh
hyprland-wsl set-mod SUPER      # optional: the Windows key as Hyprland's main key
exit
```

Then, in PowerShell, restart it and start Hyprland full screen:

```powershell
wsl -t arch
.\windows\hyprland-wsl.cmd -Distro arch     # from a clone of hyprland-wsl on Windows
```

## Notes

- A fresh image needs its pacman keyring initialised before anything can be installed; the
  installer does it too.
- The installer runs a full `pacman -Syu`. Arch does not support installing packages onto a
  system that is only partly up to date.
- Being a rolling release, Hyprland and aquamarine change often. After an update that touches
  either, `hyprland-wsl` asks for `install.sh` to be run again.
- Installing takes under a minute on an NVMe SSD after the downloads.
