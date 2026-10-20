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
rem Logs stay in the project (.tmp), never on the system drive.
if not exist ".tmp" mkdir ".tmp"
call :godot ".tmp\fantu_import.log" %TASK_IMPORT_SECONDS% --headless --log-file ".tmp\godot_import.log" --path . --import
if "%errorlevel%"=="124" (
  type ".tmp\fantu_import.log"
  echo Resource import timed out
  exit /b 1
)
for %%T in (core_smoke world_smoke events_smoke region_smoke growth_smoke arsenal_smoke society_smoke story_smoke talent_smoke bonds_smoke art_smoke ui_smoke presentation_smoke sect_smoke alchemy_smoke cave_smoke content_smoke duel_moves_smoke layers_smoke polish_smoke experience_smoke zhuji_smoke wucheng_smoke) do (
  call :run %%T || exit /b 1
)
exit /b 0

rem Runs one test; fails on a non-zero exit, on a timeout, or on any script error in its output,
rem because Godot keeps running after a script error.
:run
set "TASK_LOG=.tmp\fantu_%1.log"
call :godot "%TASK_LOG%" %TASK_TEST_SECONDS% --headless --log-file ".tmp\godot_%1.log" --path . --script res://tests/%1.gd
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
