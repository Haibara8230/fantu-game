@echo off
cd /d "%~dp0"
set "TASK_GODOT=.tools\godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%TASK_GODOT%" (
  echo Godot executable missing.
  exit /b 1
)
rem Outer time limits in seconds; the slowest test takes about 40 seconds.
set "TASK_TEST_SECONDS=180"
set "TASK_IMPORT_SECONDS=600"
call :godot "%TEMP%\fantu_import.log" %TASK_IMPORT_SECONDS% --headless --path . --import
if "%errorlevel%"=="124" (
  type "%TEMP%\fantu_import.log"
  echo Resource import timed out
  exit /b 1
)
for %%T in (core_smoke world_smoke events_smoke region_smoke growth_smoke arsenal_smoke society_smoke ui_smoke presentation_smoke sect_smoke) do (
  call :run %%T || exit /b 1
)
exit /b 0

rem Runs one test; fails on a non-zero exit, on a timeout, or on any script error in its output,
rem because Godot keeps running after a script error.
:run
set "TASK_LOG=%TEMP%\fantu_%1.log"
call :godot "%TASK_LOG%" %TASK_TEST_SECONDS% --headless --path . --script res://tests/%1.gd
set "TASK_CODE=%errorlevel%"
type "%TASK_LOG%"
if "%TASK_CODE%"=="124" (
  echo %1 timed out
  exit /b 1
)
if not "%TASK_CODE%"=="0" exit /b 1
findstr /C:"SCRIPT ERROR" "%TASK_LOG%" >nul && (
  echo Script errors in %1
  exit /b 1
)
exit /b 0

rem Runs Godot with the given log file, time limit and arguments; see tests\run_godot.ps1.
:godot
set "TASK_GODOT_LOG=%~1"
set "TASK_GODOT_SECONDS=%2"
shift
shift
set "TASK_GODOT_ARGS="
:godot_args
if "%~1"=="" goto godot_run
set "TASK_GODOT_ARGS=%TASK_GODOT_ARGS% %1"
shift
goto godot_args
:godot_run
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_godot.ps1 -Godot "%TASK_GODOT%" -Log "%TASK_GODOT_LOG%" -Seconds %TASK_GODOT_SECONDS% %TASK_GODOT_ARGS%
exit /b %errorlevel%
