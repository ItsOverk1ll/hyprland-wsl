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
| Keyboard and mouse through the viewer are unverified | The viewer connects and shows the screen. Input was only tested by injecting keys on the host side, on Arch. |
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

- [ ] Real typing and mouse use through the viewer on every distro
- [ ] An XWayland app
- [ ] Installing and launching as a non-root user (all tests ran as root)
- [ ] `git clone` inside the distro, as the README describes
- [ ] The `tools/` command lines exactly as written in the README
- [ ] Clean-instance installer runs for CachyOS and Mint

Features:

- [ ] A Windows shortcut or `.cmd` to launch a session
- [ ] One-line install once the repository is public
- [ ] Resizable screen
- [ ] A starter config shared by all distros
- [ ] GPU acceleration, if a route exists

Project:

- [ ] Choose a license
- [ ] Report the aquamarine fixes upstream, which would make the patched build unnecessary
- [ ] Decide on the PPA: keep it opt-in, or stop recommending it
- [ ] Decide whether the Arch installer may run a full system upgrade without asking
- [ ] Remove or trim the working notes (`claude-context.md`, `dev-log/`) before going public
