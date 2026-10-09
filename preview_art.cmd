@echo off
cd /d "%~dp0"
if not exist ".tools\godot\Godot_v4.7.2-stable_win64.exe" (
  echo Godot executable missing.
  pause
  exit /b 1
)
start "" ".tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." -- --art-preview
