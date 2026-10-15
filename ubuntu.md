# Ubuntu 26.04

Ubuntu 26.04 works, with an older Hyprland (0.53.3) than the other distros, and it is the least
smooth of them. Arch, CachyOS or Kali are better choices if you have no reason to use Ubuntu.

## With the launcher

`hyprland-wsl` → **+ New distro** → **Ubuntu 26.04**, then the form.

## One command

```powershell
& "$env:LOCALAPPDATA\hyprland-wsl\launcher\new-distro.ps1" -Distro ubuntu -Name ubuntu -User me
```

## By hand

As [Kali](kali.md#by-hand), starting with:

```powershell
wsl --install Ubuntu-26.04 --name ubuntu --location C:\WSL\ubuntu --no-launch
wsl -d ubuntu -u root
```

## Notes

- Hyprland 0.53.3 uses the `hyprland.conf` config format, not Lua, and logs nothing unless asked
  to (see [troubleshooting](https://github.com/ItsOverk1ll/hyprland-wsl/blob/main/docs/troubleshooting.md)).
- Its aquamarine (0.10.0) needs its own patch file; the installer picks it.
- On the GPU at 1920x1080: 64 updates a second with a full-screen 3D scene, 50 with a scrolling
  terminal, 39 with four apps at once. On the CPU it is close to unusable at that size (3 to 4
  updates a second). The other distros hold 60 on the GPU.
- A likely reason: aquamarine 0.10's headless output does not pace its frames, so Hyprland
  redraws as fast as it can. Not confirmed.
- The monitor is called `HEADLESS-2`, not `HEADLESS-1`; hyprland-wsl asks Hyprland for the name.
- Ubuntu 24.04 has no Hyprland package; it should behave like [Linux Mint 22.3](mint.md), with
  the same PPAs, but is untested.
