@echo off
cd /d "%~dp0"
set "TASK_GODOT=.tools\godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%TASK_GODOT%" (
  echo Godot executable missing.
  exit /b 1
)
"%TASK_GODOT%" --headless --path . --import >nul 2>&1
for %%T in (core_smoke world_smoke events_smoke region_smoke growth_smoke arsenal_smoke ui_smoke presentation_smoke sect_smoke) do (
  call :run %%T || exit /b 1
)
exit /b 0

rem Runs one test; fails on a non-zero exit or on any script error in its output,
rem because Godot keeps running after a script error.
:run
set "TASK_LOG=%TEMP%\fantu_%1.log"
"%TASK_GODOT%" --headless --path . --script res://tests/%1.gd > "%TASK_LOG%" 2>&1
set "TASK_CODE=%errorlevel%"
type "%TASK_LOG%"
if not "%TASK_CODE%"=="0" exit /b 1
findstr /C:"SCRIPT ERROR" "%TASK_LOG%" >nul && (
  echo Script errors in %1
  exit /b 1
)
exit /b 0
