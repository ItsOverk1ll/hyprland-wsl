# Kali Linux

Kali rolling has Hyprland in its own repositories, at the same version as Arch, and renders on
the GPU. Kali is heavier in general than the others.

## With the menu

`hyprland-wsl` → **+ New distro** → **Kali Linux**, then the form.

## One command

```powershell
& "$env:LOCALAPPDATA\hyprland-wsl\repo\windows\new-distro.ps1" -Distro kali -Name kali -User me
```

## By hand

In PowerShell:

```powershell
wsl --install kali-linux --name kali --location C:\WSL\kali --no-launch
wsl -d kali -u root
```

Inside, as root (replace `me` with your user name):

```sh
apt-get update && apt-get install -y git sudo
useradd -m -s /bin/bash -G sudo me && passwd me
printf '[user]\ndefault=me\n' >> /etc/wsl.conf
git clone https://github.com/ItsOverk1ll/hyprland-wsl /opt/hyprland-wsl-src
HYPR_USER=me bash /opt/hyprland-wsl-src/install.sh
hyprland-wsl set-mod SUPER      # optional: the Windows key as Hyprland's main key
exit
```

Then `wsl -t kali` and `.\windows\hyprland-wsl.cmd -Distro kali`.

## Notes

- The Hyprland package gives `/usr/bin/Hyprland` the file capability `cap_sys_nice`. That is why
  hyprland-wsl mounts its patched library instead of using `LD_LIBRARY_PATH`; see
  [how it works](https://github.com/ItsOverk1ll/hyprland-wsl/blob/main/docs/how-it-works.md).
- A second small `Hyprland` process is libseat's seat helper. Normal.
- A Kali installed from the Microsoft Store comes with a Store app as well; the menu's
  Ctrl+D removes that too.
