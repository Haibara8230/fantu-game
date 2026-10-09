@echo off
cd /d "%~dp0"
set "TASK_GODOT=.tools\godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%TASK_GODOT%" (
  echo Godot executable missing.
  exit /b 1
)
"%TASK_GODOT%" --headless --path . --script res://tests/core_smoke.gd
if errorlevel 1 exit /b 1
"%TASK_GODOT%" --headless --path . --script res://tests/world_smoke.gd
if errorlevel 1 exit /b 1
"%TASK_GODOT%" --headless --path . --script res://tests/events_smoke.gd
if errorlevel 1 exit /b 1
"%TASK_GODOT%" --headless --path . --script res://tests/ui_smoke.gd
if errorlevel 1 exit /b 1
"%TASK_GODOT%" --headless --path . --script res://tests/presentation_smoke.gd
if errorlevel 1 exit /b 1
"%TASK_GODOT%" --headless --path . --script res://tests/sect_smoke.gd
exit /b %errorlevel%
