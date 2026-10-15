@echo off
rem Double-clickable wrapper for hyprland-wsl.ps1. Without arguments it opens the menu of
rem distros; arguments are passed through, e.g.
rem   hyprland-wsl.cmd -Distro Ubuntu-26.04
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0hyprland-wsl.ps1" %*
if errorlevel 1 pause
