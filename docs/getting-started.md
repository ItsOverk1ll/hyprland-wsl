# Getting started

This guide is for you if you have never used Linux or a terminal. It takes you from this page
to a Linux desktop running on your Windows PC, in about 15 minutes. Windows stays exactly as it
is: your games and programs keep working, and you can go back and forth.

## What this is

**Hyprland** is a modern Linux desktop: windows that arrange themselves in tiles, smooth
animations, everything reachable from the keyboard. Normally you would need to install Linux
on your PC to use it.

**hyprland-wsl** runs it inside Windows instead, using **WSL**, the part of Windows that runs
Linux. You get a full-screen Linux desktop that you can leave at any moment with one key
combination. Nothing about Windows is replaced.

> 📷 *Screenshot placeholder: the Hyprland desktop in full screen, with a terminal and a browser.*

## What you need

- **Windows 11**, or **Windows 10 version 22H2**. To check: press **Win+R**, type `winver`,
  press Enter.
- **Virtualization switched on.** Most PCs have it on already. If it is off, the installer tells
  you, and how to switch it on.
- **About 5 GB of free disk space** for one Linux system (11 GB for Omarchy).
- **An internet connection.**
- **A graphics card is not required.** With one (any recent NVIDIA, AMD or Intel graphics
  works), the desktop runs smoothly on it. Without one, it still runs, but slower.

## Install it

1. Open the **Start menu**, type **PowerShell**, and click **Windows PowerShell**. A window with
   white text on a blue or black background opens.

   > 📷 *Screenshot placeholder: the Start menu with "PowerShell" typed in.*

2. Copy this line, click into the PowerShell window, right-click to paste it, and press Enter:

   ```powershell
   irm https://raw.githubusercontent.com/ItsOverk1ll/hyprland-wsl/main/windows/bootstrap.ps1 | iex
   ```

3. It first lists what it will change on your PC. Then it checks everything and installs what
   is missing. You do not need to answer anything except two questions:
   - **If WSL is not on your PC yet**, Windows asks for permission ("Do you want to allow this
     app to make changes?"): click **Yes**. Then **restart your PC**, open PowerShell again and
     paste the same line again. It carries on where it stopped.
   - **"Also put a shortcut on the desktop?"**: type `y` and Enter if you want one, or just
     press Enter.

   > 📷 *Screenshot placeholder: the installer's first screen, listing what it changes.*

4. At the end, a menu opens. Choose **+ New distro** with the arrow keys and press Enter.

## Choose a Linux system

A Linux system (a "distro") is what the desktop runs on. The list shows one as
**Recommended**: **Arch Linux**. Choose it unless you have a reason to pick another.

> 📷 *Screenshot placeholder: the "New distro" list with Arch Linux marked Recommended.*

Then a short form asks for a few things. Press Enter to keep the suggestion shown in brackets:

| It asks | What to type |
| --- | --- |
| Name | a name for this Linux system; the suggestion is fine |
| Folder | where it is stored; the suggestion is fine |
| User | your user name in Linux, in small letters |
| Password | a password for Linux. Type it twice; nothing appears while you type, which is normal. You need it when Linux asks for permission to change something. |
| Hostname | the computer's name in Linux; the suggestion is fine |
| Main key | press Enter for SUPER (the Windows key) |
| Default | press Enter |
| Start it | press Enter |

It then installs, showing one line per step with how long it takes, about 3 to 5 minutes in
all. If something goes wrong, it says what in one sentence and what to try.

> 📷 *Screenshot placeholder: the install steps.*

**Omarchy** is a complete, ready-made desktop with menus, themes and apps. If you choose it,
the form is skipped: Omarchy asks its own questions (keyboard, account, time zone) in the same
window. It takes about 10 minutes.

## What you will see

Before the desktop opens the first time, a short card shows the keys you need. Then your screen
turns into the Linux desktop.

> 📷 *Screenshot placeholder: the keyboard card.*
> 📷 *Screenshot placeholder: the empty desktop right after it starts.*

## Keyboard basics

The **Windows key** is Linux's main key here. The ones to know:

| Keys | What it does |
| --- | --- |
| **Ctrl+Alt+Enter** | leave full screen, to get back to Windows. Press it again to return. |
| **Win+Q** | open a terminal (Omarchy: **Win+Enter**) |
| **Win+C** | close a window (Omarchy: **Win+W**) |
| **Win+1** … **Win+0** | switch between workspaces, like separate desktops |
| **Win+M** | end the session (Omarchy: **Power Off** in its menu, **Win+Space**) |

Closing the viewer window also ends the session. To see the card again: open the menu, select
your Linux system and press **Ctrl+K**.

## Every time after

Open the **Start menu** and click your Linux system's entry, for example **Arch Linux
(arch)** or **Omarchy**. Or open **Hyprland on WSL** for the menu, where you can also add more
systems.

> 📷 *Screenshot placeholder: the Start menu entries.*

## Removing it

- **One Linux system:** open **Hyprland on WSL**, select the system, press **Ctrl+D**, and type
  its name to confirm. Everything in it is deleted.
- **hyprland-wsl itself:** in the same menu, choose **Uninstall hyprland-wsl** at the bottom. It
  removes the menu, the Start menu entries and the files it downloaded. Your Linux systems are
  kept unless you removed them first.
- WSL, PowerShell 7 and fzf, which the installer may have added, stay installed. Remove them in
  Windows' **Settings → Apps → Installed apps** if you want.

## If something goes wrong

- **The installer stopped with a message.** Do what the message says, then paste the same line
  again. Running it again is always safe.
- **The screen is black or frozen.** Press **Ctrl+Alt+Enter** to get back to Windows, close the
  viewer window, and start the system again from the Start menu.
- **Anything else:** [open an issue](https://github.com/ItsOverk1ll/hyprland-wsl/issues). If an
  install failed, attach the log file whose path it showed.
