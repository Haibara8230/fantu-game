@echo off
cd /d "%~dp0"
if not exist ".tmp" mkdir ".tmp"
rem User-only visible preview of the nascent-soul stage (jieying). Automated tests always use --headless.
".tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0." --import --log-file "%~dp0.tmp\nascent_preview_import.log" >".tmp\nascent_preview_import_output.log" 2>&1
if errorlevel 1 exit /b 1
findstr /C:"SCRIPT ERROR" ".tmp\nascent_preview_import_output.log" >nul && exit /b 1
start "" ".tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." --log-file "%~dp0.tmp\nascent_preview.log" -- --nascent-preview
