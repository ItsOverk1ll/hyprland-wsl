# Status and roadmap

Where the project stands and what is still to do. Last updated 2026-10-13.

## Works

Checked on Arch, CachyOS, Kali and Mint with clean installs on 2026-10-13, by scripts (a VNC
client, `hyprctl`, screenshots); nobody has sat in front of this version yet. Everything below
holds on Arch, CachyOS and Kali. Mint runs on the CPU only (see the gaps).

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

Also tried on Ubuntu 26.04, from a side-by-side build: starts on GPU and CPU.

## Known gaps

| Gap | Notes |
| --- | --- |
| Not seen by a person | Everything above was measured remotely. How it looks and feels in the WSLg window and in the full-screen Windows viewer is unchecked for this version. |
| Frame rate at TigerVNC's viewer | Not measured: neither the Windows nor the Linux viewer reports one, and the Windows one would not close on request. While it was connected, wayvnc used about two thirds of one core at 1920x1080 with the whole screen changing. |
| Windows key capture is unconfirmed | As before: needs a real keyboard. |
| Mint on the GPU | With Mesa 25.2 the viewer stays blank in GPU mode (capture through `wlr-screencopy` is never answered), so the launcher uses the CPU when Mesa is older than 26. Cause not pinned down. On the CPU it gives 53 updates a second with a scrolling terminal and 6 with a full-screen 3D scene. |
| GPU coverage | One NVIDIA card. Other vendors, and machines where WSL has no GPU, are untested; the "no GPU" case was only simulated by making `/dev/dxg` unreadable. |
| Xwayland draws on the CPU in GPU mode | Its own GPU path makes it exit at start, so it is run with `-glamor off`. Cause not investigated. |
| waybar did not appear | Started in the test session and showed nothing. Not investigated; it may only need its usual configuration. |
| Ubuntu 26.04 | Monitor reports 0.06 Hz; slow on the CPU. Low priority. |
| Fixed screen size | Chosen at launch. |
| Keyboard layout | Not taken from Windows. |
| Start-up notices | Two harmless notices on every start. |
| VNC | Still a copy and an encode per frame. A purpose-built Windows client is the idea for later. |
| Docs | `manual-setup.md` and `troubleshooting.md` still describe the earlier stack. |

## To do

Next:

- [ ] Someone looks at it: WSLg window, full-screen Windows viewer, the Windows key
- [x] Rerun Arch, CachyOS and Mint with this version
- [ ] Find out why capture fails on the GPU with Mesa 25.2 (Mint)
- [ ] Rewrite `manual-setup.md` and `troubleshooting.md`
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

- [ ] Merge this branch into `main` once it has been seen working
- [ ] Choose a license
- [ ] Report the headless-backend change to hyprwm/aquamarine
- [ ] Decide on the PPA, and on the unprompted `pacman -Syu`
- [ ] Remove or trim the working notes (`claude-context.md`, `dev-log/`, `probes/`) before going public
