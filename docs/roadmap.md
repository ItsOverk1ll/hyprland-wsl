# Status and roadmap

Where the project stands and what is still to do. Last updated 2026-10-13.

## Works

Checked on Arch, CachyOS, Kali and Mint with clean installs on 2026-10-13, by scripts (a VNC
client, `hyprctl`, screenshots). The owner then used all four through the Windows viewer the
same day: it looks right, keyboard and tiling work, Arch felt "super smooth", and CachyOS and
Mint "both work great". Everything
below holds on Arch, CachyOS, Kali, and on Mint once Mesa has been upgraded (the installer
offers that).

- Hyprland on its own headless backend, with no second compositor underneath.
- Rendering on the GPU through Mesa's Direct3D 12 driver, chosen automatically, with the CPU as
  fallback (`--software` forces it; if the GPU attempt fails to start, the launcher retries on
  the CPU).
- 60 updates a second at 1920x1080 at a scripted VNC client, with the whole screen changing.
- Wayland apps, including OpenGL apps drawing on the GPU (glmark2), a GTK app (Thunar), and X11
  apps through XWayland (xclock, glxgears).
- Keyboard through VNC (Super+Q opens a terminal), screen size and scale at launch.
- One installer for pacman- and apt-based distros, one launcher, a Windows-side launcher.
- Clean shutdown.
- Omarchy 4.0.4 in an Arch instance, installed by `windows\install-omarchy.ps1` (see [omarchy.md](omarchy.md)).

Ubuntu 26.04 passes the same checks from a clean install, with lower frame rates (see the gaps).

## Known gaps

| Gap | Notes |
| --- | --- |
| Pointer in the Windows viewer | Hyprland draws the pointer into the picture and shares only a transparent pointer image, which Windows draws as a black square. A small library loaded into wayvnc sends a one-pixel pointer instead, so one black pixel remains at the tip; the owner confirmed on 2026-10-15 that the pointer looks right. Gone entirely only with a viewer of our own, or if Hyprland shared its themed pointers. |
| Slower with many tiles | Reported by the owner on Kali at 2560x1440; not measured. wayvnc encodes on one thread and is the first suspect. |
| Frame rate at TigerVNC's viewer | Not measured: neither the Windows nor the Linux viewer reports one, and the Windows one would not close on request. While it was connected, wayvnc used about two thirds of one core at 1920x1080 with the whole screen changing. |
| Windows key capture is unconfirmed | As before: needs a real keyboard. |
| Mint needs a second PPA for the GPU | Its Mesa 25.2 leaves the viewer blank in GPU mode. Mesa 26.2 from `ppa:kisak/kisak-mesa` fixes it; the installer asks before adding it. What exactly is broken in 25.2 was not looked into. Mint's old wayvnc also uses about 86 % of one core at 1920x1080 with the whole screen changing, so it has little headroom above that size. |
| Chromium needs `--disable-gpu` in GPU mode | It wants scanout buffers from GBM, which the Direct3D 12 driver does not provide. Found on Omarchy; applies to every distro. The Omarchy script sets the flag; elsewhere it is manual. |
| Omarchy is only script-tested | Start-up, shell, terminal, menus, file manager and browser were checked by screenshots. Audio, the lock screen, `omarchy update` and theme switching were not tried. |
| GPU coverage | One NVIDIA card. Other vendors, and machines where WSL has no GPU, are untested; the "no GPU" case was only simulated by making `/dev/dxg` unreadable. |
| Xwayland draws on the CPU in GPU mode | Its own GPU path makes it exit at start, so it is run with `-glamor off`. Cause not investigated. |
| waybar did not appear | Started in the test session and showed nothing. Not investigated; it may only need its usual configuration. |
| Ubuntu 26.04 is less smooth | 64 and 50 updates a second on the GPU in the two frame-rate tests, 39 with four apps at once, and 3 to 4 on the CPU. Its aquamarine 0.10 does not pace headless frames, which is the suspect. Low priority. |
| Fixed screen size | Chosen at launch. |
| Keyboard layout | Not taken from Windows. |
| Start-up notices | Two harmless notices on every start. |
| VNC | Still a copy and an encode per frame. A purpose-built Windows client is the idea for later. |

## To do

Next:

- [x] Someone looks at it in the Windows viewer (Kali, Arch, CachyOS and Mint, 2026-10-13)
- [ ] Still unseen: the WSLg window, and the Windows key as modifier
- [x] Rerun Arch, CachyOS and Mint with this version
- [x] Mint on the GPU: works with Mesa 26 from the kisak-mesa PPA, offered by the installer
- [x] Rewrite `manual-setup.md` and `troubleshooting.md`
- [ ] Higher targets than 1920x1080 at 60: 2560x1440 and 3840x2160 through the real viewer

Distros:

- [ ] Ubuntu 24.04, Debian
- [ ] Fedora (needs a dnf branch), openSUSE Tumbleweed (needs a zypper branch)

Features:

- [ ] A Windows client of our own in place of VNC (shared frames, keyboard capture in a window,
      resizing, keyboard layout, clipboard)
- [ ] Decide the default main modifier: ALT (works everywhere) or SUPER (needs the Windows viewer)
- [ ] A Start menu or desktop shortcut
- [ ] One-line install once the repository is public
- [ ] A starter config shared by all distros
- [ ] A Hyprland-like tiling window manager for native Windows apps (separate, later)

Project:

- [x] Merge the headless stack into `main` (2026-10-13)
- [ ] Choose a license
- [ ] Report the headless-backend change to hyprwm/aquamarine
- [ ] Decide on the PPA, and on the unprompted `pacman -Syu`
- [ ] Remove or trim the working notes (`claude-context.md`, `dev-log/`) before going public
