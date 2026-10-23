@echo off
cd /d "%~dp0"
if not exist ".tools\godot\Godot_v4.7.2-stable_win64.exe" (
  echo Godot executable missing.
  pause
  exit /b 1
)
if not exist ".tmp" mkdir ".tmp"
rem Only the user launches this visible preview; automated verification stays headless.
".tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0." --import --log-file "%~dp0.tmp\battle_preview_import.log" >".tmp\battle_preview_import_output.log" 2>&1
start "" ".tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." --log-file "%~dp0.tmp\battle_preview.log" -- --battle-v6-preview
