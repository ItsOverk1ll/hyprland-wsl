# Troubleshooting

Problems that came up while this was built and tested, with their causes. Entries marked
*(expected)* describe likely situations that were not reproduced.

## Where to look

| What | Where |
| --- | --- |
| Launcher logs: `hyprland.log`, `wayvnc.log`, `viewer.log`, `scale.log` | `/tmp/hyprland-wsl/` |
| The failed GPU attempt, if the launcher fell back to the CPU | `/tmp/hyprland-wsl/hyprland-gpu.log` |
| Hyprland's own log | `/run/user/<uid>/hypr/<long name>/hyprland.log` |
| Hyprland crash reports | `~/.cache/hyprland/` of the Hyprland user |

The first line the launcher prints says what is drawing:

```
Hyprland is running at 1920x1080, rendering on the GPU (VNC on 127.0.0.1:5900).
```

Hyprland 0.53 (Ubuntu 26.04) writes almost nothing to its log unless the config has:

```
debug {
    disable_logs = false
}
```

## Installing

**`error: keyring is not writable` (Arch)**
The pacman keyring of a fresh image is not initialised. `pacman-key --init && pacman-key --populate`,
then retry. The installer does this itself; the message appears when installing `git` beforehand.

**`error: command failed to execute correctly` during pacman's hooks**
Comes from a systemd hook ("user@0.service is not active"). Harmless; the install continues.

**`this release of ... has no hyprland package`**
The distro release does not package Hyprland. On Ubuntu 24.04-based releases the installer offers
a PPA; see the README. Elsewhere there is no supported route yet.

**`not adding the PPA; rerun with HYPRLAND_PPA=1 to allow it`**
The installer was not run from a terminal, so it could not ask. Rerun as
`HYPRLAND_PPA=1 ./install.sh` if you accept the PPA.

**`Mesa 25 is too old for GPU rendering; Hyprland would render on the CPU.`**
Ubuntu 24.04-based releases. The installer offers a second PPA with a current Mesa; answer yes,
or rerun as `HYPRLAND_MESA_PPA=1 ./install.sh`. Declining is fine: everything works, drawn by
the CPU.

**`no patch in patches/ applies to aquamarine X.Y.Z`**
The distro has an aquamarine version the patches were not written for. This needs a new patch;
please report the version.

**`the WSL kernel has no vgem module`**
Run `wsl --update` in Windows, then `wsl --shutdown`, and try again.

**`error: Hyprland did not generate a config`, or `unable to execute /usr/bin/env: Permission denied`**
The root directory of the distro is readable by root only, which happens with a root filesystem
built by hand. The current installer repairs it (`warning: / has mode 700 ...`). By hand:
`chmod 755 /`.

**The install takes tens of minutes**
The distro's disk is on a hard disk. Package installation in WSL is very slow there. Move the
distro to an SSD: `wsl --export`, `wsl --unregister`, then `wsl --import` to a folder on the SSD.

## Starting

**`the patched aquamarine is for 'X' but 'Y' is installed; rerun install.sh`**
A system update changed aquamarine. Rerun `./install.sh`; it rebuilds the patched copy.

**`Hyprland is already running for <user>`**
A session is running, or a process from an earlier one is left over:
`pkill -9 -u <user> -x Hyprland`, then start again.

**`Hyprland did not start on the GPU; trying the CPU`**
The Direct3D 12 driver could not start, and the session continues on the CPU.
`/tmp/hyprland-wsl/hyprland-gpu.log` has the failed attempt. Things to check: `ls -l /dev/dxg`
(it must exist and be readable by the Hyprland user), `ls /usr/lib/wsl/lib` (WSL's Direct3D
libraries), and that the GPU driver on Windows is current. `--software` skips the attempt.

**`Mesa NN is older than 26; rendering on the CPU`**
See the Mesa entry under Installing. `--gpu` forces the GPU anyway; with Mesa 25.2 that gives a
blank viewer.

**`Hyprland did not start, see /tmp/hyprland-wsl/hyprland.log`**
Read that log and Hyprland's own log. `no allocator available` means Hyprland runs with the
system's unpatched aquamarine, or was started directly instead of through `hyprland-wsl`; rerun
`./install.sh`.

**`wayvnc did not start`** *(expected)*
Most likely the port is taken, for example by another session. Use `--port` with a free port.
All WSL distros share their ports, so two distros cannot both use 5900.

**`Something already answers on port 5900`** (Windows-side launcher)
A session is still running, in this distro or another one. Close its viewer, or stop it with
`wsl -d <distro> -u root pkill -x Hyprland`, or pass `-Port`.

**`WSLg display not found`**
WSLg is not running or not installed. Run `wsl --update`, or start with `--no-viewer` and connect
a VNC client on Windows to `127.0.0.1:5900`.

## Running

**The viewer is blank or grey, but the session runs**
Seen in GPU mode with Mesa 25.2 (Linux Mint 22.3 as shipped): Hyprland runs and takes input, and
no picture arrives. Upgrade Mesa (see Installing) or start with `--software`.

**A black square sits on the mouse pointer (Windows viewer)**
The server sends the viewer a pointer image that is fully transparent, and Windows draws such a
cursor as a black square. The current `windows\hyprland-wsl.ps1` asks the viewer for its dot
cursor instead; update the clone. What remains is a small dot at the pointer's tip.

**X11 apps do not open in GPU mode**
Xwayland's own GPU drawing makes it exit at start here, so the launcher runs it with
`-glamor off` or `-shm`. If an X11 app reports `Can't open display`, look at
`/tmp/hyprland-wsl/hyprland.log` for Xwayland's message and report it.

**The Windows key does nothing, or opens the Start menu**
In the WSLg window, Windows handles that key before WSL sees it; the installed config therefore
uses ALT as the main modifier. For a real SUPER key, start the session with
`windows\hyprland-wsl.cmd` (full screen, keyboard captured) and run `hyprland-wsl set-mod SUPER`
once inside the distro. In the Windows viewer the keyboard is only captured in full screen.

**Stuck in the full-screen viewer**
Press Ctrl+Alt+Enter to leave full screen (TigerVNC 1.16; older versions used an F8 menu).
The main modifier plus M ends the session, which also closes the viewer.

**A key does not do what you expect**
The installed config is Hyprland's default one: main modifier plus Q opens a terminal, C closes
the window, M exits, V toggles floating. Change them in `~/.config/hypr/hyprland.lua`.

**`sudo` asks for a password that does not exist**
The user the installer creates has no password and is not in the sudo group. From Windows:
`wsl -d <distro> -u root passwd <user>` and `wsl -d <distro> -u root usermod -aG sudo <user>`
(`wheel` on Arch-based distros).

**High CPU use**
- The launcher says "rendering on the CPU": that is the cost of drawing without a GPU. A smaller
  screen, and turning off blur and animations in the Hyprland config, help the most.
- For the first 20 seconds or so after starting: start-up notices are animating.
- wayvnc near 100 % of one core: it encodes on one thread, and old versions (0.7 on Linux Mint)
  work much harder than new ones. A smaller screen or a lower `--fps` reduces it.
- Otherwise the session should idle near zero. If it does not, check which process is busy with
  `top`.

**Slow or choppy**
Check the launcher's first line. On the GPU, the remaining cost is VNC: every frame is copied,
encoded and sent, so a smaller screen is smoother than a larger one. On the CPU, see above.

**Typing gives the wrong characters**
Hyprland uses its own keyboard layout, US by default; the Windows layout is not passed through.
Set the layout in the Hyprland config (`kb_layout` in the `input` section).

**Two notices at the top right on every start**
"Hyprland was started without start-hyprland" and "hyprland-guiutils is not installed". Both are
harmless here.

**Two Hyprland processes**
On Debian-family distros a second, small Hyprland process is the seat helper of libseat. It is
normal, and the launcher removes it on shutdown.

## Imported distros (CachyOS, Linux Mint)

**`wsl --import` fails with a timeout**
Happens when WSL is busy with heavy disk work. Run it again.

**After an import, non-root users can run nothing (`Permission denied` on every command)**
The root directory of the imported filesystem has the wrong mode. As root in the distro:
`chmod 755 /`. `tools/merge-layers.sh` sets this correctly, and the installer repairs it.

**The Mint instance says it is Ubuntu**
Expected until Mint's base packages are installed; see the README.

**`The repository 'http://packages.linuxmint.com alfa Release' no longer has a Release file`**
That is the Mint 23 pre-release image. Use `linuxmintd/mint22.3-amd64`.
