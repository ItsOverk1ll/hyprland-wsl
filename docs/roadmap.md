# Status and roadmap

Where the project stands and what is still to do. Last updated 2026-10-11.

## Works

- Hyprland in a window on the Windows desktop, on Arch, CachyOS, Kali, Ubuntu 26.04 and
  Linux Mint 22.3.
- One installer for pacman- and apt-based distros, one launcher.
- Clean shutdown when the viewer is closed.

## Known gaps

| Gap | Notes |
| --- | --- |
| Keyboard and mouse verified on Ubuntu only | Typing, the mouse and opening several terminals work through the viewer on Ubuntu 26.04. The other distros use the same launcher but were not tried by hand. |
| Small on high-resolution displays | On a 4K display the window and its text are small. Scaling is not handled yet. |
| XWayland apps are unverified | Hyprland reports XWayland starting in the session; no X11 app was run. |
| Software rendering only | No GPU acceleration. |
| Fixed screen size | Chosen at launch; resizing the viewer window does not resize Hyprland. |
| Keyboard layout | Not taken from Windows; has to be set in the Hyprland config. |
| Start-up notices | Two harmless notices on every start. |

## To do

Distros:

- [ ] Ubuntu 24.04 (expected to work like Mint 22.3)
- [ ] Debian
- [ ] Fedora (needs a dnf branch)
- [ ] openSUSE Tumbleweed (needs a zypper branch)

Testing:

- [x] Real typing and mouse use through the viewer on Ubuntu 26.04
- [ ] The same on Arch, CachyOS, Kali and Mint, including the window appearing on the desktop
- [ ] An XWayland app
- [ ] Installing and launching as a non-root user (all tests ran as root)
- [ ] `git clone` inside the distro, as the README describes
- [ ] The `tools/` command lines exactly as written in the README
- [ ] Clean-instance installer runs for CachyOS and Mint

Features:

- [ ] A Windows shortcut or `.cmd` to launch a session
- [ ] One-line install once the repository is public
- [ ] Resizable screen
- [ ] Sensible size and scale on high-resolution displays
- [ ] A starter config shared by all distros
- [ ] GPU acceleration, if a route exists

Project:

- [ ] Choose a license
- [ ] Report the aquamarine fixes upstream, which would make the patched build unnecessary
- [ ] Decide on the PPA: keep it opt-in, or stop recommending it
- [ ] Decide whether the Arch installer may run a full system upgrade without asking
- [ ] Remove or trim the working notes (`claude-context.md`, `dev-log/`) before going public
