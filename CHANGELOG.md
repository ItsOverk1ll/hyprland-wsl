# Changelog

What changed, newest first. The project has no version numbers yet, so entries go by date.

## 2026-10-15: Getting started

### Added

- [docs/getting-started.md](docs/getting-started.md), for readers who have never used Linux or a
  terminal: what this is, what you need, the one-line install, what you will see, the keyboard
  basics, and how to remove it, with places for screenshots. Linked first in the README.

## 2026-10-15: The keyboard card

### Added

- **Before a distro's first session, a short keyboard card** in the terminal: Ctrl+Alt+Enter to
  leave full screen, opening a terminal, closing a window, ending the session (Power Off on
  Omarchy), and the main key, read from the distro's own config. Shown once per distro, whether
  the session starts from the menu, a Start menu entry or `hyprland-wsl -Distro`; **Ctrl+K** in
  the menu shows it again. `hyprland-wsl.ps1 -NoKeyCard` skips it.
- `tools/distro-info.sh` reports the main key (`mod=`).

## 2026-10-15: The menu for newcomers

### Added

- **New distro** lists Arch Linux first, marked "Recommended", and gives the others short
  honest notes: "via Docker image", "third-party PPA", "older Hyprland, less smooth", "heavier".
- **Without fzf the menu shows a numbered list** instead of stopping (`2` starts the second
  entry, `2w` in a window, `2t` stops it, `2d` removes it, `r` rescans).
- **Installs show one line per step with a rough time**, and keep everything the tools print in
  a log file (`%LOCALAPPDATA%\hyprland-wsl\logs`). A failed step says in one sentence what went
  wrong and what to try (for example that the chosen folder's drive does not exist, or the drive
  is full), with the log's path, and removes the half-made distro so a retry starts clean.
  `new-distro.ps1 -KeepOnFailure` and `-ShowOutput` are there for looking closer.
- **Removing a distro hyprland-wsl did not create** shows an extra warning that it may hold your
  own files; `remove-distro.ps1` on its own also asks for the name to be typed now.
- **Uninstall hyprland-wsl** in the menu, and `windows\uninstall.ps1`: removes the command, the
  shortcuts, the cache and logs, the downloaded viewer and the downloaded copy of hyprland-wsl.
  Distros are never removed by it.

## 2026-10-15: Start menu entries

### Added

- **"Hyprland on WSL" in the Start menu** opens the menu. `install-command.ps1` (and so the
  one-line install) adds it; `-Desktop` adds a desktop shortcut too, which the bootstrap offers.
- **Every distro made from the menu gets its own Start menu entry**, such as "Arch Linux
  (myarch)" or "Omarchy", with the distro's icon, starting it directly. Removing the distro
  (Ctrl+D or `remove-distro.ps1`) removes its entry, and `install-command.ps1 -Remove` removes
  all of hyprland-wsl's shortcuts.

## 2026-10-15: One-line install for Windows

### Added

- **`windows\bootstrap.ps1`**: `irm https://raw.githubusercontent.com/ItsOverk1ll/hyprland-wsl/main/windows/bootstrap.ps1 | iex`
  in Windows PowerShell 5.1 goes from nothing to the menu. It checks WSL (installs it with
  `wsl --install --no-distribution` and explains the restart; updates an old built-in WSL; sets
  WSL 2 as the default; says how to switch on virtualization when it is off), installs
  PowerShell 7 and fzf with winget, downloads hyprland-wsl to `%LOCALAPPDATA%\hyprland-wsl\repo`
  (git if installed, a zip otherwise; again to update), adds the `hyprland-wsl` command and
  opens the menu. It lists what it may change at the start and what it did change at the end,
  and stops with one plain sentence instead of an error code.

### Fixed

- The menu showed every distro's name as "System.String[]": `remove-distro.ps1`, which the menu
  loads, declared a typed `$Name` parameter that took over the menu's own `$name`. The
  parameter is now `-DistroName` (`-Name` still works).

## 2026-10-15: The menu is back on main

### Changed

- The Windows menu, new and removed distros and the `hyprland-wsl` command are on main again,
  so one download has everything. The Launcher branch now only holds optional extras (a
  Win+Shift+H popup for BetterHotkeys users); nothing on main depends on it.
- The `hyprland-wsl` command opens the menu without arguments and starts a distro with
  `-Distro NAME`; `windows\hyprland-wsl.ps1` itself keeps starting the default distro.

## 2026-10-15: Three branches

### Changed

- **The launcher moved to its own branch,
  [Launcher](https://github.com/ItsOverk1ll/hyprland-wsl/tree/Launcher)**, with a one-line
  installer: the menu, new and removed distros, the `hyprland-wsl` command for Windows and
  Win+Shift+H for BetterHotkeys. It downloads this branch (main) for what it needs.
- **The distro guides moved to
  [Operating-Systems](https://github.com/ItsOverk1ll/hyprland-wsl/tree/Operating-Systems)**: one
  guide per distro, with the notes that were in `docs/distros.md` and `docs/omarchy.md`.
- main is hyprland-wsl itself. `install.sh` no longer adds the Windows command (the launcher's
  installer does), and `windows\hyprland-wsl.ps1` without arguments starts the default distro
  again instead of opening the menu.

## 2026-10-15: New and removed distros from the menu

### Added

- **+ New distro** in the menu: Arch Linux, CachyOS, Kali Linux, Ubuntu 26.04 or Linux Mint
  22.3, with a form for the name, folder, user, password, hostname, main key, default distro
  and starting it when done. It creates the distro (from WSL's catalogue, or from the Docker
  image for CachyOS and Mint, merging Mint's layers in a temporary distro), makes the account
  with sudo, sets the hostname and default user, runs install.sh, and skips the distro's own
  first-run account prompt. Omarchy goes straight to its installer and its own setup.
- `windows\new-distro.ps1`, the same from the command line, and `tools/new-distro-setup.sh`,
  the part that runs inside the new distro.
- **Ctrl+D** in the menu removes a distro completely, after you type its name: the distro
  (`wsl --unregister`), its folder when empty, its Windows Terminal profiles (WSL's and ones
  you made that start it), and the Microsoft Store app it was installed from. Terminal's
  settings are backed up first. `windows\remove-distro.ps1` does the same from the command line.

### Fixed

- With no distros installed, the menu listed words of WSL's "no installed distributions"
  message ("You", "Use", "and") as distros.

## 2026-10-15: A launcher menu

### Added

- **`windows\launcher.cmd`**, a menu of your WSL distros in the terminal (fzf, styled like
  BetterHotkeys' menus and following its theme). It shows each distro's system, Hyprland
  version, user and whether it renders on the GPU; Enter starts it full screen, Ctrl+W in a
  window, Ctrl+T stops it. Distros without hyprland-wsl offer to install it, and a top row
  makes a new Omarchy instance.
- `tools/distro-info.sh`, what the menu asks each distro.
- **`hyprland-wsl` in Windows terminals.** Typed without arguments it opens the menu; with
  `-Distro NAME` and the other options it starts that distro, as `windows\hyprland-wsl.ps1`
  does. `install.sh` (through WSL's Windows interop) and `install-omarchy.ps1` set it up;
  `windows\install-command.ps1` does it by hand and `-Remove` undoes it.

### Changed

- `windows\hyprland-wsl.ps1` (and `.cmd`) with no arguments at all opens the menu instead of
  starting the default distro. `-Distro NAME` starts a distro as before.
- The menu works with a checkout inside a distro (`\\wsl.localhost\...`): what it asks each
  distro goes over stdin, and installs copy the checkout to `%LOCALAPPDATA%` first.

## 2026-10-15: Omarchy's first-boot setup

### Added

- **Omarchy installs like a new machine.** `windows\install-omarchy.ps1` no longer makes an
  account. It installs Omarchy the way its USB stick does "for another owner", and starts it:
  the first start shows Omarchy's own first-boot setup in the terminal (greeting, keyboard,
  account, git identity, hostname, timezone, summary, progress), then the desktop. `-NoSetup
  -User -Password` keeps the old behaviour.
- **`hyprland-wsl first-start`**, a hook for setups that have to run once in a terminal before
  the first session. The Windows launcher calls it before every start; it does nothing once
  the setup is done.
- `install.sh` accepts `HYPR_USER=-`: no user yet.

## 2026-10-15: Power Off, and the pointer square

### Fixed

- **Omarchy's Power Off did nothing.** The session is not a login session, so the system asked
  for a password nothing could show. It now shuts the instance down, the viewer closes, and
  the Windows launcher no longer starts the stopped instance again on its way out.
- **Apps and Power Off in Omarchy after the instance restarted.** The user's systemd session
  can fail to start with a WSL instance ("Device or resource busy"); the launcher now starts
  it when it is configured and missing.
- **The square on the pointer in the Windows viewer.** Measured on Windows: the old setting
  gave a 24x24 solid black cursor, the dot setting a 5x5 dot. wayvnc now sends a one-pixel
  pointer instead (`src/no-cursor-image.c`), on every distro including Mint's and Ubuntu's
  older wayvnc. One black pixel remains at the tip of Hyprland's pointer.
- **Rerunning the Omarchy script on a running instance** restarted the system message bus,
  after which logind stopped answering until the instance was restarted.

### Checked

- Omarchy's screensaver starts after the idle time with the Windows viewer connected and no
  input (tested with the timeout shortened to 20 seconds; Omarchy's own default is 150).

### Added

- The viewer closes when the session ends from inside (`-ReconnectOnError=0`).

## 2026-10-13: Omarchy

### Added

- **Omarchy in WSL.** `windows\install-omarchy.ps1` creates an Arch instance and installs
  [Omarchy](https://omarchy.org) 4.0.4 into it with hyprland-wsl on top: Omarchy's packages,
  its system setup and its per-user setup, without the parts about booting and real hardware.
  The work is done by `tools/omarchy-wsl.sh`. See [docs/omarchy.md](docs/omarchy.md).

### Changed

- **The installer leaves upgrades to Omarchy** where Omarchy is installed. It used to run a
  full `pacman -Syu`, which Omarchy blocks outside `omarchy update`.

### Known limits

- Chromium, and apps built on it, need `--disable-gpu` in GPU mode on every distro. The
  Omarchy script sets it; elsewhere it is a manual step (see troubleshooting).

## 2026-10-13: Hyprland on its own, drawn by the GPU

The stack lost a layer and gained GPU rendering. Hyprland no longer runs inside a second
compositor, and where WSL exposes a GPU it now draws with it.

```
before:  vgem, labwc, Hyprland (CPU), wayvnc, viewer
now:     vgem, Hyprland (GPU or CPU), wayvnc, viewer
```

Measured at 1920x1080 on an RTX 4060 by a scripted VNC client, the same on Arch, CachyOS, Kali
and Mint within one update a second (Ubuntu 26.04 is lower, see the known limits). Drawing on
the CPU was the only way before:

| What is on screen | On the CPU | On the GPU |
| --- | --- | --- |
| A 3D scene filling the screen | 6 updates a second | 60 updates a second |
| A scrolling terminal, full screen | 55 a second, Hyprland using about 2.3 CPU cores | 60 a second, about a sixth of one core |

### Added

- **GPU rendering** through Mesa's Direct3D 12 driver. The launcher chooses it automatically
  when WSL exposes a GPU and Mesa is version 26 or newer, and prints what it chose:
  `Hyprland is running at 1920x1080, rendering on the GPU`. Apps inside the session draw on the
  GPU too.
- **`--software` and `--gpu`** to choose the renderer, and **`--fps N`** for the most frames a
  second sent to the viewer (default 60). On the Windows side: `-Software` and `-Fps`.
- **Automatic fallback.** If Hyprland does not start on the GPU, the launcher starts it on the
  CPU and says so.
- **A current Mesa for Ubuntu 24.04-based distros** (Linux Mint 22.x). Their Mesa 25.2 leaves
  the viewer blank in GPU mode. The installer offers the third-party `ppa:kisak/kisak-mesa`,
  asks first (`HYPRLAND_MESA_PPA=1` answers yes), and upgrades only Mesa's packages.
- **X11 apps in GPU mode.** Xwayland is started so that it works alongside the Direct3D 12
  driver.
- **`tools/vnc-probe.py fps`**: updates per second and how evenly they arrive, measured the way
  a viewer receives them. **`cursor`**: the pointer image a VNC server sends.
- This changelog.

### Changed

- **No host compositor.** aquamarine's headless backend is patched to open the vgem device
  itself (`patches/headless-drm.patch`), which is the one thing labwc was there to provide.
  labwc and wlr-randr are no longer installed or used.
- **The patch is smaller and different.** The fixes for aquamarine's nested Wayland backend are
  gone, because that backend is no longer used.
- **The render node is left alone.** The launcher used to replace `/dev/dri/renderD128` with a
  copy of the primary node. Hyprland is now pointed at the primary node directly.
- **Default screen size** is 1920x1080 (was 1600x900).
- **The viewer may receive 60 frames a second.** wayvnc's own limit of 30 applied before.
- **Docs** rewritten for the new stack: README, how it works, distro notes, setting it up by
  hand, troubleshooting, roadmap.

### Fixed

- **A black square on the mouse pointer** in the Windows viewer. The server sends a fully
  transparent pointer image, which Windows draws as an opaque square; the launcher now asks the
  viewer for its dot cursor instead. A small dot at the pointer's tip remains.
- **Leaving full screen** is Ctrl+Alt+Enter in TigerVNC 1.16. The docs said F8, which was the
  key in older versions.
- **`--scale` on Ubuntu 26.04.** The launcher now asks Hyprland for the monitor's name instead
  of assuming it.
- **The monitor's refresh rate on Ubuntu 26.04** reads 60 Hz. aquamarine 0.10 reported 0.06 Hz
  for a headless output.
- **Installing into a root filesystem that only root can enter** (`/` with mode 700, as a
  hand-built Mint image had). The installer repairs it and says so.

### Removed

- labwc, wlr-randr and the nested-backend patches (`aquamarine-wayland-nested*.patch`).

### Tested

Clean installs on fresh instances of Arch, CachyOS, Kali, Linux Mint 22.3 and Ubuntu 26.04, each
through the full suite: start-up, frame rate on GPU and CPU, X11 apps, the CPU fallback, scale,
several apps at once. Arch, CachyOS, Kali and Mint were also used by hand through the Windows
viewer.

### Known limits

- The picture still goes through VNC: a copy and an encode per frame.
- One NVIDIA card was tested. Other GPUs are untested.
- Ubuntu 26.04, with Hyprland 0.53 and aquamarine 0.10, is less smooth than the others: 50 to
  64 updates a second on the GPU in the same tests, and 3 to 4 on the CPU.
- Linux Mint needs two third-party PPAs for the GPU path, and its old wayvnc (0.7) uses most of
  one CPU core at 1920x1080 when the whole screen changes.
- The frame rate at TigerVNC's own viewer was not measured; it does not report one.

## 2026-10-11: four more distros, keyboard capture, lower CPU use

### Added

- **Kali, Ubuntu 26.04, Linux Mint 22.3 and CachyOS**, next to Arch. One installer for pacman-
  and apt-based distros; a second patch for aquamarine 0.10.
- **Opt-in PPA for Hyprland** on Ubuntu 24.04-based distros (`HYPRLAND_PPA=1`).
- **`tools/Get-DockerRootfs.ps1` and `tools/merge-layers.sh`**: import distros that only publish
  Docker images (CachyOS, Mint) into WSL without Docker.
- **A Windows-side launcher** (`windows\hyprland-wsl.cmd`): a viewer running on Windows, full
  screen, with the whole keyboard captured, so that the Windows key can be Hyprland's modifier.
- **`--scale N`** and **`hyprland-wsl set-mod SUPER|ALT`**.
- **`tools/vnc-probe.py`**: a dependency-free VNC client for scripted tests.
- **`docs/`**: how it works, distro notes, manual setup, troubleshooting, roadmap.

### Changed

- **A private mount namespace** for the session: the patched library is mounted over the system
  one (`LD_LIBRARY_PATH` is ignored for Hyprland on Debian-family distros), and `/tmp/.X11-unix`
  is a fresh directory.
- **wayvnc attaches to Hyprland**, not to the host compositor: keys no longer pass the host's
  own shortcuts, and old host versions no longer render continuously.
- **Mesa's software renderer is capped at 4 threads**, which cut CPU use many times over.
- **Full screen on a scaled display** renders at the unscaled size and lets Windows enlarge it.

### Fixed

- **The viewer window opened inside the session** instead of on the Windows desktop.

## 2026-10-10: first version

- Hyprland on Arch Linux under WSL2: `install.sh`, the `hyprland-wsl` launcher, and a patch for
  aquamarine's nested Wayland backend, with labwc as a headless host and wayvnc plus TigerVNC to
  show the picture.
