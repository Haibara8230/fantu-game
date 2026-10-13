# Layout screenshots without disturbing the player: copies the project to a work folder, adds an
# override.cfg that opens the window off-screen without focus and with a user dir of its own, then runs
# tools/capture_screens.gd at each size. Usage: tools\capture.ps1 -Out <dir> [-Work <dir>] [-Sizes 1920x1080,2560x1440]
param(
	[Parameter(Mandatory)][string]$Out,
	[string]$Work = "$env:TEMP\fantu_capture",
	[string[]]$Sizes = @("1920x1080", "2560x1440")
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $root ".tools\godot\Godot_v4.7.2-stable_win64_console.exe"
robocopy $root $Work /MIR /XD .git builds .tools /NFL /NDL /NJH /NJS /NP | Out-Null
@"
[application]
config/use_custom_user_dir=true
config/custom_user_dir_name="fantu_capture"
[display]
window/size/no_focus=true
window/size/borderless=true
window/size/initial_position_type=0
window/size/initial_position=Vector2i(-9000, -9000)
"@ | Set-Content -Encoding UTF8 (Join-Path $Work "override.cfg")
& $godot --headless --path $Work --import 2>&1 | Out-Null
foreach ($size in $Sizes) {
	$dir = Join-Path $Out $size
	New-Item -ItemType Directory -Force $dir | Out-Null
	& $godot --path $Work --script res://tools/capture_screens.gd -- $dir $size 2>&1 | Select-String -Pattern "CAPTURE|ERROR|SCRIPT" | ForEach-Object { $_.Line }
}
