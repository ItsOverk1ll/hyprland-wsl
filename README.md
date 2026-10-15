# hyprland-wsl

Run [Hyprland](https://hypr.land) inside WSL2, in a window on the Windows desktop.

Hyprland does not run under WSL out of the box: WSL has no display device it can drive, and
WSLg's compositor lacks the protocols Hyprland needs to run nested. This repository makes
Hyprland run on a screen in memory instead, drawn by the GPU where WSL exposes one, and shows
that screen in a window.

The aim is to support all major Linux distributions under WSL2.

## Branches

| Branch | What it is |
| --- | --- |
| **main** (this one) | hyprland-wsl: the installer, the Windows menu and `hyprland-wsl` command, new and removed distros, the viewer script, Omarchy's installer |
| [**Launcher**](https://github.com/ItsOverk1ll/hyprland-wsl/tree/Launcher) | optional ways to open the menu, such as a Win+Shift+H popup for BetterHotkeys users |
| [**Operating-Systems**](https://github.com/ItsOverk1ll/hyprland-wsl/tree/Operating-Systems) | step-by-step guides for installing each distro with hyprland-wsl |


## Documentation

- [How it works](docs/how-it-works.md): why Hyprland needs help under WSL and what each part does
- [Distro guides](https://github.com/ItsOverk1ll/hyprland-wsl/tree/Operating-Systems): installing each distro, with its notes (Operating-Systems branch)
- [Setting it up by hand](docs/manual-setup.md): the installer and launcher as individual steps
- [Troubleshooting](docs/troubleshooting.md): error messages and what to do about them
- [Omarchy](https://github.com/ItsOverk1ll/hyprland-wsl/blob/Operating-Systems/omarchy.md): DHH's Hyprland distribution in a WSL instance
- [Status and roadmap](docs/roadmap.md): what works, known gaps, what is planned
- [Changelog](CHANGELOG.md): what changed and when

## Supported distros

Tested on 2026-10-13 with WSL 2.5.9, each with a clean install:

| Distro | Hyprland | Comes from | Notes |
| --- | --- | --- | --- |
| Arch Linux | 0.56.2 | distro repos | GPU |
| CachyOS | 0.56.2 | distro repos | GPU; no WSL image, imported from its Docker image |
| Kali Linux (rolling) | 0.56.2 | distro repos | GPU |
| Ubuntu 26.04 | 0.53.3 | distro repos | GPU; older Hyprland with the `hyprland.conf` config format, and less smooth than the others |
| Linux Mint 22.3 | 0.56.2 | third-party PPA | GPU with a newer Mesa from a second PPA, otherwise CPU; no WSL image; Mint has no Hyprland package of its own |

[Omarchy](https://github.com/ItsOverk1ll/hyprland-wsl/blob/Operating-Systems/omarchy.md) 4.0.4 runs too, in an Arch instance, with its own installer script.

Other Arch-based and Debian/Ubuntu-based distros may work, since the installer goes by package
family, but only the ones above were tried. Ubuntu 24.04 should behave like Mint 22.3 (same base)
and is untested. Fedora and openSUSE are not supported yet.

How to install each of them, from nothing: the [guides on the Operating-Systems branch](https://github.com/ItsOverk1ll/hyprland-wsl/tree/Operating-Systems).

## Requirements

- Windows 11 (or Windows 10 with WSLg) and a current WSL: `wsl --update`
- One of the distros above, for example `wsl --install archlinux`, `wsl --install kali-linux` or
  `wsl --install Ubuntu-26.04`

## Install

Inside the distro:

```sh
git clone https://github.com/ItsOverk1ll/hyprland-wsl
cd hyprland-wsl
./install.sh
```

If `git` is missing: `pacman -Sy --needed git` on Arch-based distros (on a fresh Arch image run
`pacman-key --init && pacman-key --populate` first), `apt install git` on the others.

The installer:

- installs Hyprland, foot, wayvnc, TigerVNC's viewer and a build toolchain. On Arch-based
  distros this is a full system upgrade (`pacman -Syu`), because Arch does not support installing
  onto a partly updated system.
- picks the user Hyprland runs as (the invoking user, else the first regular user, else a new
  user `hypr`; override with `HYPR_USER=name ./install.sh`)
- builds a patched copy of aquamarine, in the version the distro ships, into `/opt/hyprland-wsl`
  (the system package is untouched)
- installs the `hyprland-wsl` launcher into `/usr/local/bin`
- writes a default Hyprland config if there is none, with ALT as the main modifier and foot as
  the terminal

A user the installer creates has no password and no `sudo` rights. To have them inside the
session, run `passwd hypr` and `usermod -aG sudo hypr` as root (`wheel` on Arch-based distros).

### The PPAs on Ubuntu 24.04-based distros

Linux Mint 22.x and Ubuntu 24.04 have no `hyprland` package. The installer then offers to add the
third-party PPA [`ppa:cppiber/hyprland`](https://launchpad.net/~cppiber/+archive/ubuntu/hyprland)
and asks first. That PPA is not part of the distro and is not run or checked by this project; it
also replaces a few system libraries (libinput, libxkbcommon and others) with newer builds. To
allow it without the question: `HYPRLAND_PPA=1 ./install.sh`.

Their Mesa (25.2) is also too old for GPU rendering: the viewer stays blank. Where WSL exposes a
GPU, the installer offers a second third-party PPA,
[`ppa:kisak/kisak-mesa`](https://launchpad.net/~kisak/+archive/ubuntu/kisak-mesa), and moves
Mesa's packages to its version (26.2 when tested). The same cautions apply. Without it Hyprland
renders on the CPU. To allow it without the question: `HYPRLAND_MESA_PPA=1 ./install.sh`.

## Use

```sh
hyprland-wsl                    # 1920x1080 window
hyprland-wsl 1600x900           # another size
hyprland-wsl 2560x1440 --scale 1.25 # larger screen, everything drawn a quarter bigger
hyprland-wsl --software         # draw on the CPU even if a GPU is available
hyprland-wsl --fps 30           # send the viewer at most 30 frames a second (default 60)
hyprland-wsl --no-viewer        # no window; connect a VNC client to 127.0.0.1:5900
hyprland-wsl --port 5901
```

It draws on the GPU when WSL exposes one (`/dev/dxg`) and the distro's Mesa has the Direct3D 12
driver and is version 26 or newer, otherwise on the CPU, and says which when it starts:

```
Hyprland is running at 1920x1080, rendering on the GPU (VNC on 127.0.0.1:5900).
```

From Windows: `wsl -d <distro> hyprland-wsl`

Closing the viewer window, or Ctrl+C, shuts everything down. Logs are in `/tmp/hyprland-wsl`.

### Full screen with the whole keyboard, including the Windows key

The window above is shown by WSLg, and Windows handles the Windows key, Alt+Tab and similar
keys before WSLg sees them. To give Hyprland the whole keyboard, use the launcher on the Windows
side instead. It starts the session and shows it with a VNC viewer that runs on Windows itself,
full screen, with the keyboard captured:

```powershell
.\windows\hyprland-wsl.cmd -Distro <distro>              # full screen, keyboard captured
hyprland-wsl -Distro <distro>                           # the same, from any terminal once the command is set up
.\windows\hyprland-wsl.cmd -Distro <distro> -Windowed    # in a window
.\windows\hyprland-wsl.cmd -Distro <distro> -Native      # full screen, every pixel rendered
.\windows\hyprland-wsl.cmd -Distro <distro> -Software    # draw on the CPU
```

On a scaled display, full screen renders at the size Windows calls 100 % and Windows enlarges
the picture: a 3840x2160 display at 150 % gets a 2560x1440 Hyprland. `-Native` renders every
pixel instead, which is sharper; on the CPU that is too slow for comfortable use at 3840x2160.

Then switch Hyprland's main modifier to the Windows key, once, inside the distro:

```sh
hyprland-wsl set-mod SUPER       # back with: hyprland-wsl set-mod ALT
```

- Press **Ctrl+Alt+Enter** to leave or enter full screen (TigerVNC 1.16; older versions used an F8 menu).
- Closing the viewer ends the session.
- The first run downloads TigerVNC's standalone viewer (about 24 MB, checked for a valid
  signature) to `%LOCALAPPDATA%\hyprland-wsl`. An installed TigerVNC is used instead if present.
- `-Size 2560x1440`, `-Scale 1.5` and `-Port` override the defaults.
- A few keys never leave Windows, such as Ctrl+Alt+Del and Win+L.

### A menu of your distros

Type `hyprland-wsl` in any Windows terminal (PowerShell, cmd, Windows Terminal). It opens a
menu that lists every WSL distro, shows which ones have hyprland-wsl and what they render on,
and starts the one you pick:

```powershell
hyprland-wsl
```

`bootstrap.ps1` and `install-omarchy.ps1` set the command up; without them, run
`.\windows\install-command.ps1` once (it adds `%LOCALAPPDATA%\hyprland-wsl\bin` to your user
PATH; `-Remove` takes it away). `.\windows\launcher.cmd` opens the same menu without it.

| Key | Action |
| --- | --- |
| Enter | start full screen (on a distro without hyprland-wsl: offer to install it) |
| Ctrl+W | start in a window |
| Ctrl+T | stop the distro |
| Ctrl+D | remove the distro completely (asks you to type its name first; see below) |
| Ctrl+R | rescan every distro |
| Esc | close |

The top row, **+ New distro**, installs a new one with Hyprland. Pick Arch Linux, CachyOS, Kali
Linux, Ubuntu 26.04 or Linux Mint 22.3, then fill in a short form: name, folder for its disk,
user name, password, hostname, main key (SUPER or ALT), whether it becomes WSL's default distro,
and whether to start it when done. The user gets sudo with that password. CachyOS and Mint come
from their Docker images (see [Distros without a WSL image](#distros-without-a-wsl-image)); for
Mint the form also asks about the two PPAs it needs. Picking **Omarchy** asks nothing: it
installs into the next free name (`omarchy`, `omarchy2`, ...) under `C:\WSL` and opens
Omarchy's own setup.

New distros get their folder under `C:\WSL` unless the `HYPRLAND_WSL_DISTROS` environment
variable names another place, for example a separate drive:
`[Environment]::SetEnvironmentVariable('HYPRLAND_WSL_DISTROS', 'P:\WSL', 'User')`.

Removing a distro deletes its disk (`wsl --unregister`), its folder when nothing else is in it,
its Windows Terminal profiles (the one WSL made and any you made yourself that start it with
`-d NAME`, `--distribution NAME` or `-Distro NAME`), and the Microsoft Store app it came from, if
any. The menu lists all of it before you confirm. Terminal's settings are backed up to
`%LOCALAPPDATA%\hyprland-wsl\backups` first. Without the menu: `.\windows\remove-distro.ps1 -Name NAME`.
emove-distro.ps1 -Name NAME`.

The same works without the menu:

```powershell
.\windows\new-distro.ps1 -Distro arch -Name myarch -User me -Hostname myarch   # asks for the password
```

The menu needs PowerShell 7 and fzf (`winget install Microsoft.PowerShell` and
`winget install junegunn.fzf`). It looks at each distro once, by starting it, and remembers the
answer in `%LOCALAPPDATA%\hyprland-wsl\distros.json`. Its colours follow the current
BetterHotkeys theme when that is installed, and Omarchy's Hackerman otherwise.

Default keys (the installed config uses ALT as the main modifier, because the WSLg window
cannot pass the Windows key; with `set-mod SUPER` read ALT as the Windows key):

| Keys | Action |
| --- | --- |
| ALT+Q | terminal |
| ALT+C | close window |
| ALT+V | toggle floating |
| ALT+arrow keys | move focus |
| ALT+1..0 | switch workspace |
| ALT+M | exit Hyprland |

## Distros without a WSL image

CachyOS and Linux Mint are not in `wsl --list --online`. Both publish Docker images, which can be
imported into WSL without Docker: `tools/Get-DockerRootfs.ps1` downloads an image's layers and
`tools/merge-layers.sh` merges several into one. The [CachyOS](https://github.com/ItsOverk1ll/hyprland-wsl/blob/Operating-Systems/cachyos.md) and
[Linux Mint](https://github.com/ItsOverk1ll/hyprland-wsl/blob/Operating-Systems/mint.md) guides walk through it; the menu's **+ New distro** does it for you.

## How it works

```
VNC viewer (a WSLg window, or a viewer on Windows itself)
   └─ wayvnc              captures Hyprland, sends input to it
Hyprland, on its headless backend, with patched aquamarine
   └─ your apps
```

- **vgem**, a virtual DRM device in the WSL kernel, is the device Hyprland allocates its buffers
  on. It has no display and does no drawing.
- **aquamarine** (Hyprland's backend library) is patched so that its headless backend opens that
  device; unpatched, it has none and Hyprland cannot start. See [`patches/`](patches/).
- **Mesa** draws: on the GPU through its Direct3D 12 driver, or on the CPU.
- Hyprland runs in a **private mount namespace**. In it the patched aquamarine is mounted over
  the system one (an `LD_LIBRARY_PATH` is ignored on distros that give Hyprland a file
  capability), and `/tmp/.X11-unix` is a fresh directory (WSLg's one makes Xwayland setup fail).
- **wayvnc** attaches to Hyprland and TigerVNC's viewer shows it, either inside WSL (displayed
  by WSLg) or on Windows itself. Keyboard and mouse go back the same way.

More in [docs/how-it-works.md](docs/how-it-works.md).

## Performance

Measured on 2026-10-13 on Kali, with an RTX 4060, at 1920x1080, by a scripted VNC client counting
the updates it receives. Arch, CachyOS and Mint (with Mesa 26) gave the same figures within one
update a second. Ubuntu 26.04, with its older Hyprland, reached 64 and 50 on the GPU and is very
slow on the CPU:

| What is on screen | GPU | CPU |
| --- | --- | --- |
| A 3D scene filling the screen (glmark2 terrain) | 60 per second, Hyprland at 21 % of one core | 6 per second (the app itself is drawn on the CPU too) |
| A scrolling terminal, full screen | 60 per second, 16 % | 55 per second, 231 % |
| Idle | 0 % | 0 % |

The frame rate at TigerVNC's own viewer has not been measured; that viewer does not report one.

## Limitations

- The picture goes through VNC, which costs a copy and an encode per frame.
- GPU rendering needs a GPU that WSL exposes and Mesa 26 or newer built with the Direct3D 12
  driver. It was tested with one NVIDIA card only. With Mesa 25.2 (Linux Mint 22.3 as shipped)
  the viewer stays blank in GPU mode, so the launcher uses the CPU there unless Mesa was
  upgraded; `--gpu` overrides that.
- On the CPU, animations and blur cost CPU in proportion to the screen size.
- In the WSLg window on a high-resolution display, things are small unless a larger size and
  `--scale` are given. The Windows-side launcher picks both from the display.
- The screen size is fixed when the session starts.
- The patched aquamarine is tied to the distro's aquamarine version. After a system update that
  changes Hyprland or aquamarine, the launcher says so; rerun `./install.sh` to rebuild. Patches
  exist for aquamarine 0.10.0, 0.14.0 and 0.15.1; for other versions the installer reports
  whether one applies.
- Keyboard layout is whatever Hyprland is configured with; the Windows layout is not passed through.

## Uninstall

```sh
./uninstall.sh
```

Removes the launcher and the patched library. Packages, the user and `~/.config/hypr` stay.
The Windows command is removed with `.\windows\install-command.ps1 -Remove`.
