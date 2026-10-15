# CachyOS

CachyOS is Arch with its own optimised packages. It has no WSL image, so it comes from its
Docker image, which can be imported into WSL without Docker. After that it behaves like Arch.

## With the launcher

`hyprland-wsl` → **+ New distro** → **CachyOS**, then the form. The launcher downloads the image
itself.

## One command

```powershell
& "$env:LOCALAPPDATA\hyprland-wsl\launcher\new-distro.ps1" -Distro cachyos -Name cachyos -User me
```

## By hand

In PowerShell, in a clone of hyprland-wsl (its `tools\Get-DockerRootfs.ps1` downloads a Docker
image's layers; CachyOS's image has a single layer, which imports as it is):

```powershell
.\tools\Get-DockerRootfs.ps1 -Image cachyos/cachyos -OutDir C:\WSL\images\cachyos
wsl --import cachyos C:\WSL\cachyos C:\WSL\images\cachyos\layer01.tar.gz
wsl -d cachyos -u root
```

Inside, the same steps as [Arch Linux](arch.md#by-hand), from `pacman-key --init` on. Then
`wsl -t cachyos` and `.\windows\hyprland-wsl.cmd -Distro cachyos`. The image folder can be
deleted afterwards.

## Notes

- Hyprland comes from Arch's `extra` repository, Mesa from CachyOS's own.
- The image does not enable systemd. Nothing here needs it.
