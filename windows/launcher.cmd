@echo off
rem Opens the hyprland-wsl launcher menu (launcher.ps1) in this console.
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0launcher.ps1" %*
