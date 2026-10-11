# Status and roadmap

Where the project stands and what is still to do. Last updated 2026-10-11.

## Works

- Hyprland in a window on the Windows desktop, on Arch, CachyOS, Kali, Ubuntu 26.04 and
  Linux Mint 22.3.
- One installer for pacman- and apt-based distros, one launcher.
- Keyboard and mouse. Checked by hand in the WSLg window on Ubuntu, and by a scripted VNC client
  on Kali, Ubuntu, Mint and CachyOS (Super+Q opens a terminal, typed text arrives).
- A Windows-side launcher that shows the session with a viewer running on Windows.
- Screen size and scale can be chosen at launch, up to 3840x2160.
- Clean shutdown when the viewer is closed.

## Known gaps

| Gap | Notes |
| --- | --- |
| Windows key capture is unconfirmed | The Windows-side launcher starts the viewer full screen with system-key capture switched on. That the Windows key really reaches Hyprland has to be confirmed at a real keyboard. |
| High CPU on Ubuntu 26.04 | About three cores while a viewer is connected. Hyprland 0.53 redraws for every capture. |
| XWayland apps are unverified | Hyprland reports XWayland starting in the session; no X11 app was run. |
| Software rendering only | No GPU acceleration. Smooth at 2560x1440 (about 33 updates a second during animations, 18 ms from key press to screen, measured through VNC). At 3840x2160 the renderer is saturated and it lags, so real 4K needs GPU acceleration. Full screen on a 4K display therefore renders at the 100 % size and lets Windows enlarge it. |
| Fixed screen size | Chosen at launch; resizing the viewer window does not resize Hyprland. |
| Keyboard layout | Not taken from Windows; has to be set in the Hyprland config. |
| Start-up notices | Two harmless notices on every start. |
| No mouse pointer in the captured picture | The viewer draws its own pointer. Whether that looks right in every viewer is unchecked. |

## To do

Distros:

- [ ] Ubuntu 24.04 (expected to work like Mint 22.3)
- [ ] Debian
- [ ] Fedora (needs a dnf branch)
- [ ] openSUSE Tumbleweed (needs a zypper branch)

Testing:

- [x] Real typing and mouse use through the WSLg window on Ubuntu 26.04
- [x] Scripted keyboard test through VNC on Kali, Ubuntu, Mint, CachyOS
- [ ] The Windows key through the Windows-side launcher, at a real keyboard
- [ ] The WSLg window appearing on the desktop on Arch, CachyOS, Kali and Mint (confirmed on Ubuntu)
- [ ] An XWayland app
- [ ] Installing and launching as a non-root user (all tests ran as root)
- [ ] `git clone` inside the distro, as the README describes
- [ ] The `tools/` command lines exactly as written in the README
- [ ] Clean-instance installer runs for CachyOS and Mint

Features:

- [x] A Windows-side launcher (`windows\hyprland-wsl.cmd`)
- [x] Size and scale for high-resolution displays
- [ ] Decide the default main modifier: ALT (works everywhere) or SUPER (needs the Windows viewer)
- [ ] A Start menu or desktop shortcut that runs the Windows-side launcher
- [ ] One-line install once the repository is public
- [ ] Resizable screen
- [ ] A starter config shared by all distros
- [ ] Fix or work around the Ubuntu CPU use (newer Hyprland or wayvnc there)
- [ ] GPU acceleration, if a route exists

Project:

- [ ] Choose a license
- [ ] Report the aquamarine fixes upstream, which would make the patched build unnecessary
- [ ] Decide on the PPA: keep it opt-in, or stop recommending it
- [ ] Decide whether the Arch installer may run a full system upgrade without asking
- [ ] Remove or trim the working notes (`claude-context.md`, `dev-log/`) before going public
