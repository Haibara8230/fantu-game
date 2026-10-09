# Runs one headless Godot command for check.cmd with an outer time limit, because a hung Godot
# never reaches a test's own timer. On timeout the whole process tree is killed (the console
# executable starts a child Godot) and the log ends with a TIMEOUT line.
# Exit code: Godot's own, or 124 on timeout.
param(
	[Parameter(Mandatory)][string]$Godot,
	[Parameter(Mandatory)][string]$Log,
	[Parameter(Mandatory)][int]$Seconds,
	[Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$GodotArgs
)
$errors = "$Log.err"
$process = Start-Process -FilePath $Godot -ArgumentList $GodotArgs -NoNewWindow -PassThru `
	-RedirectStandardOutput $Log -RedirectStandardError $errors
$null = $process.Handle  # keeps the exit code readable after the process ends
$finished = $process.WaitForExit($Seconds * 1000)
if (-not $finished) {
	& taskkill.exe /T /F /PID $process.Id 2>&1 | Out-Null
	$process.WaitForExit(10000) | Out-Null
}
# One log for check.cmd to show and scan, as before.
if (Test-Path $errors) {
	Get-Content $errors | Add-Content $Log
	Remove-Item $errors -Force
}
if (-not $finished) {
	Add-Content $Log "TIMEOUT: no exit after $Seconds seconds, process tree killed"
	exit 124
}
exit $process.ExitCode
