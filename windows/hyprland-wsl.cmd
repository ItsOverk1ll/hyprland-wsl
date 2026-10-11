@echo off
rem Double-clickable wrapper for hyprland-wsl.ps1. Arguments are passed through, e.g.
rem   hyprland-wsl.cmd -Distro Ubuntu-26.04
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0hyprland-wsl.ps1" %*
if errorlevel 1 pause
