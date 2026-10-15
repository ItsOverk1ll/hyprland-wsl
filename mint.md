# Linux Mint 22.3

Mint has no WSL image and no Hyprland package of its own. It comes from its Docker image, and
Hyprland from a third-party PPA. With a second PPA for a newer Mesa it renders on the GPU as
smoothly as Arch.

The two PPAs are not part of Mint and are not checked by this project:

- [`ppa:cppiber/hyprland`](https://launchpad.net/~cppiber/+archive/ubuntu/hyprland): Hyprland. It
  also upgrades a few system libraries (libinput, libxkbcommon, libdisplay-info).
- [`ppa:kisak/kisak-mesa`](https://launchpad.net/~kisak/+archive/ubuntu/kisak-mesa): Mesa 26 for
  the GPU. Mint's own Mesa (25.2) leaves the picture blank on the GPU; without this PPA Hyprland
  renders on the CPU.

## With the menu

`hyprland-wsl` → **+ New distro** → **Linux Mint 22.3**, then the form. It asks about the PPAs.

## One command

```powershell
& "$env:LOCALAPPDATA\hyprland-wsl\repo\windows\new-distro.ps1" -Distro mint -Name mint -User me -AllowPpa
```

## By hand

Mint's image has several layers, which have to be merged into one before import. In PowerShell,
in a clone of hyprland-wsl, with any existing WSL distro for the merge:

```powershell
.\tools\Get-DockerRootfs.ps1 -Image linuxmintd/mint22.3-amd64 -OutDir C:\WSL\images\mint
wsl -u root -- bash tools/merge-layers.sh /mnt/c/WSL/images/mint /mnt/c/WSL/images/mint/rootfs.tar.gz
wsl --import mint C:\WSL\mint C:\WSL\images\mint\rootfs.tar.gz
wsl -d mint -u root
```

(The menu, which may run with no distro installed yet, imports the first layer as a
throwaway distro for the merge instead.)

The image is Mint's package build environment and still identifies as Ubuntu. Inside, as root,
install Mint's base packages first, then as [Kali](kali.md#by-hand) with the PPAs allowed:

```sh
apt-get update
apt-get install -y --allow-downgrades base-files=$(apt-cache madison base-files | awk '/mint/ {print $3; exit}') \
    mintsystem mintsources mint-mirrors
apt-get install -y git sudo
useradd -m -s /bin/bash -G sudo me && passwd me
printf '[user]\ndefault=me\n' >> /etc/wsl.conf
git clone https://github.com/ItsOverk1ll/hyprland-wsl /opt/hyprland-wsl-src
HYPRLAND_PPA=1 HYPRLAND_MESA_PPA=1 HYPR_USER=me bash /opt/hyprland-wsl-src/install.sh
exit
```

Then `wsl -t mint` and `.\windows\hyprland-wsl.cmd -Distro mint`.

## Notes

- This gives Mint's package base, not the Cinnamon desktop of an installed Mint.
- The image's only regular user is called `ubuntu`; without `HYPR_USER` the installer would pick
  it and the prompt would read `ubuntu@...`. `cat /etc/os-release` tells you which distro a
  session really is.
- The `mint23-amd64` image is a pre-release without a package repository. Use 22.3.
- Its wayvnc (0.7.2) is old and works harder than on the others (about 86 % of one core to send
  a fully changing screen, against about 25 %).
- Its Xwayland has no `-glamor off`; hyprland-wsl uses `-shm` there. The Mesa PPA brings a newer
  Xwayland that has it.
