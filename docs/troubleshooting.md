# Troubleshooting

> **Not yet updated.** This page still describes the earlier stack, where Hyprland ran nested
> inside labwc (branch `main`). The current stack has no labwc, no `wlr-randr` and no redirected
> render node; see [how-it-works.md](how-it-works.md). The scripts are the reference.

Problems that came up while this was built and tested, with their causes. Entries marked
*(expected)* describe likely situations that were not reproduced.

## Where to look

| What | Where |
| --- | --- |
| Launcher logs: `labwc.log`, `hyprland.log`, `wayvnc.log`, `viewer.log` | `/tmp/hyprland-wsl/` |
| Hyprland's own log | `/run/user/<uid>/hypr/<long name>/hyprland.log` |
| Hyprland crash reports | `~/.cache/hyprland/` of the Hyprland user |

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

**`no patch in patches/ applies to aquamarine X.Y.Z`**
The distro has an aquamarine version the patches were not written for. This needs a new patch;
please report the version.

**`the WSL kernel has no vgem module`**
Run `wsl --update` in Windows, then `wsl --shutdown`, and try again.

**The install takes tens of minutes**
The distro's disk is on a hard disk. Package installation in WSL is very slow there. Move the
distro to an SSD: `wsl --export`, `wsl --unregister`, then `wsl --import` to a folder on the SSD.

## Starting

**`the patched aquamarine is for 'X' but 'Y' is installed; rerun install.sh`**
A system update changed aquamarine. Rerun `./install.sh`; it rebuilds the patched copy.

**`Hyprland is already running for <user>`**
A session is running, or a process from an earlier one is left over:
`pkill -9 -u <user> -x Hyprland`, then start again.

**`host compositor did not start, see /tmp/hyprland-wsl/labwc.log`**
Read that log. `sticky bit not set on /tmp/.X11-unix` followed by `cannot create xwayland server`
means labwc ran outside the launcher's mount namespace, which should not happen with the current
launcher; reinstall it with `./install.sh`.

**`Hyprland did not start, see /tmp/hyprland-wsl/hyprland.log`**
Read that log and Hyprland's own log. Known causes:

- `invalid version for global ...`: the host compositor is older than Hyprland's backend expects.
  The patch handles this; rerun `./install.sh` so the current patch is built.
- `Missing protocols` or `no allocator available`: Hyprland was started without the host
  compositor or without the DRM device, for example by running `Hyprland` directly. Use
  `hyprland-wsl`.

**`wayvnc did not start`** *(expected)*
Most likely the port is taken, for example by another session. Use `--port` with a free port.
All WSL distros share their ports, so two distros cannot both use 5900.

**It says "Hyprland is running" but no window appears on the Windows desktop**
With a launcher from before 2026-10-11 the viewer opened its window inside the Hyprland session
instead of on the desktop. Stop the session with Ctrl+C, update the clone, rerun `./install.sh`
and start again. If it still happens, check `/tmp/hyprland-wsl/viewer.log`, and as a fallback
start with `--no-viewer` and connect a VNC client on Windows.

**`WSLg display not found`**
WSLg is not running or not installed. Run `wsl --update`, or start with `--no-viewer` and connect
a VNC client on Windows to `127.0.0.1:5900`.

## Running

**The window is black, or Hyprland runs but shows nothing**
Hyprland has no monitor. `hyprctl monitors` then shows none, or a monitor of size 0x0. The cause
found in testing was Hyprland using the system's unpatched aquamarine, which the current launcher
prevents. Make sure Hyprland was started with `hyprland-wsl` and not directly, rerun
`./install.sh` so launcher and patched library are current, and start again.

**Hyprland crashes right after starting (Ubuntu 26.04)**
Seen with an earlier version of the aquamarine 0.10 patch. Rerun `./install.sh` from a current
clone.

**The Windows key does nothing, or opens the Start menu**
In the WSLg window, Windows handles that key before WSL sees it; the installed config therefore
uses ALT as the main modifier. For a real SUPER key, start the session with
`windows\hyprland-wsl.cmd` (full screen, keyboard captured) and run `hyprland-wsl set-mod SUPER`
once inside the distro. In the Windows viewer the keyboard is only captured in full screen.

**Stuck in the full-screen viewer**
Press F8 for the viewer's menu, which can leave full screen or quit.

**Alt+Tab, Alt+F4 or the arrow keys with Alt do nothing inside Hyprland**
With a launcher from before 2026-10-11 the host compositor kept those shortcuts for itself.
Update the clone and rerun `./install.sh`.

**High CPU use**
- Ubuntu 26.04: about three cores while a viewer is connected, even with a still picture. Its
  Hyprland (0.53) redraws the screen for every VNC capture. Known and not solved; closing the
  viewer stops it.
- Any distro, for the first 20 seconds or so after starting: start-up notices are animating.
- Otherwise the session should idle near zero. If it does not, check which process is busy with
  `top`, and try a lower `HYPRLAND_WSL_THREADS` (default 4).

**Typing gives the wrong characters**
Hyprland uses its own keyboard layout, US by default; the Windows layout is not passed through.
Set the layout in the Hyprland config (`kb_layout` in the `input` section).

**Two notices at the top right on every start**
"Hyprland was started without start-hyprland" and "hyprland-guiutils is not installed". Both are
harmless here.

**Two Hyprland processes**
On Debian-family distros a second, small Hyprland process is the seat helper of libseat. It is
normal, and the launcher removes it on shutdown.

**Slow or choppy**
Rendering is done on the CPU. A smaller screen (`hyprland-wsl 1280x720`) and turning off blur and
animations in the Hyprland config help the most.

## Imported distros (CachyOS, Linux Mint)

**`wsl --import` fails with a timeout**
Happens when WSL is busy with heavy disk work. Run it again.

**After an import, non-root users can run nothing (`Permission denied` on every command)**
The root directory of the imported filesystem has the wrong mode. As root in the distro:
`chmod 755 /`. `tools/merge-layers.sh` sets this correctly; a tarball built another way may not.

**The Mint instance says it is Ubuntu**
Expected until Mint's base packages are installed; see the README.

**`The repository 'http://packages.linuxmint.com alfa Release' no longer has a Release file`**
That is the Mint 23 pre-release image. Use `linuxmintd/mint22.3-amd64`.
