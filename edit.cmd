@echo off
cd /d "%~dp0"
if not exist ".tools\godot\Godot_v4.7.2-stable_win64.exe" (
  echo Godot executable missing. Import project.godot in the Godot editor.
  pause
  exit /b 1
)
start "" ".tools\godot\Godot_v4.7.2-stable_win64.exe" --editor --path "%~dp0."
