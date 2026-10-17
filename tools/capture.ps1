# Layout screenshots without disturbing the player: copies the project to a work folder, adds an
# override.cfg that opens the window off-screen without focus and with a user dir of its own, then runs
# tools/capture_screens.gd at each size. Usage: tools\capture.ps1 -Out <dir> [-Work <dir>] [-Sizes 1920x1080,2560x1440]
param(
	[Parameter(Mandatory)][string]$Out,
	[string]$Work = "$env:TEMP\fantu_capture",
	[string[]]$Sizes = @("1920x1080", "2560x1440"),
	[string[]]$Only = @()
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $root ".tools\godot\Godot_v4.7.2-stable_win64_console.exe"
# Avoid copying editor locks and caches; bounded retries keep a background capture from hanging.
$resolvedRoot = [IO.Path]::GetFullPath($root).TrimEnd('\')
$resolvedWork = [IO.Path]::GetFullPath($Work).TrimEnd('\')
if ($resolvedWork -eq $resolvedRoot -or $resolvedRoot.StartsWith($resolvedWork + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Capture work directory must be separate from the project and its ancestors."
}
if (Test-Path -LiteralPath $resolvedWork) {
    if ((Get-Item -LiteralPath $resolvedWork -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Capture work directory cannot be a reparse point."
    }
}
robocopy $root $resolvedWork /MIR /R:1 /W:1 /XD .git builds .tools .godot .idea /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Capture copy failed: robocopy exit $LASTEXITCODE" }
$override = @"
[application]
config/use_custom_user_dir=true
config/custom_user_dir_name="fantu_capture"
[display]
window/size/no_focus=true
window/size/borderless=true
window/size/initial_position_type=0
window/size/initial_position=Vector2i(-9000, -9000)
"@
# Without a byte-order mark: Windows PowerShell's UTF8 writes one, and Godot then ignores the whole
# file — the window opens on screen and the player's own user dir is used.
[IO.File]::WriteAllText((Join-Path $Work "override.cfg"), $override, [Text.UTF8Encoding]::new($false))
& $godot --headless --path $Work --import 2>&1 | Out-Null
foreach ($size in $Sizes) {
	$dir = Join-Path $Out $size
	New-Item -ItemType Directory -Force $dir | Out-Null
	& $godot --path $Work --position -9000,-9000 --script res://tools/capture_screens.gd -- $dir $size ($Only -join ",") 2>&1 | Select-String -Pattern "CAPTURE|ERROR|SCRIPT" | ForEach-Object { $_.Line }
}
