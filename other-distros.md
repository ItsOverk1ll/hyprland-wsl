# Other distros

## A distro you already have

In the menu, select it: one without hyprland-wsl offers to install it (Enter). Or
inside it:

```sh
git clone https://github.com/ItsOverk1ll/hyprland-wsl && cd hyprland-wsl && ./install.sh
```

The installer picks the user Hyprland runs as (the one running it, else the first regular user,
else a new user `hypr`; `HYPR_USER=name` chooses).

## Not covered yet

The installer goes by package family, so other Arch-based and Debian/Ubuntu-based distros may
work. Tried so far:

| Distro | State |
| --- | --- |
| Ubuntu 24.04 | expected to work like [Linux Mint 22.3](mint.md) (same base, same PPAs); untested |
| Debian (`wsl --install Debian`) | not looked at |
| Fedora, openSUSE, AlmaLinux and other RPM-based distros | not supported yet: the installer has no branch for them |
