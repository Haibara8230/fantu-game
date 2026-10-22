param([switch]$VerifyOnly)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $projectRoot.StartsWith('D:\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The image storage target must be in the D-drive project.'
}
$imageTarget = [IO.Path]::GetFullPath((Join-Path $projectRoot '.tmp/imagegen_storage/generated_images'))
if (-not $imageTarget.StartsWith($projectRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Image target escapes the project.'
}
$codexDirectory = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex' }
$imageLink = Join-Path $codexDirectory 'generated_images'
if (-not (Test-Path -LiteralPath $codexDirectory -PathType Container)) {
    throw 'The existing Codex home could not be found; refusing to create another home.'
}
if (-not (Test-Path -LiteralPath $imageLink)) {
    if ($VerifyOnly) { throw 'Image directory redirection has not been configured.' }
    New-Item -ItemType Directory -Path $imageTarget -Force | Out-Null
    # The user explicitly authorized this directory junction. Image bytes go to D:.
    # Existing directories/files are never moved, removed, or replaced.
    New-Item -ItemType Junction -Path $imageLink -Target $imageTarget | Out-Null
}
$linkItem = Get-Item -Force -LiteralPath $imageLink
if ($linkItem.LinkType -ne 'Junction') {
    throw 'The image path is an existing ordinary directory; it has not been modified.'
}
$resolvedTarget = [IO.Directory]::ResolveLinkTarget($imageLink, $true).FullName
if (-not $resolvedTarget.Equals($imageTarget, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unexpected junction target: $resolvedTarget"
}
$probeName = '.redirect_probe.txt'
$probeThroughLink = Join-Path $imageLink $probeName
$probeOnD = Join-Path $imageTarget $probeName
[IO.File]::WriteAllText($probeOnD, 'Generated-image junction verified: image bytes are stored on D:.' )
if (-not (Test-Path -LiteralPath $probeThroughLink -PathType Leaf)) { throw 'D-drive probe is not readable through the junction.' }
if ((Get-FileHash -LiteralPath $probeThroughLink).Hash -ne (Get-FileHash -LiteralPath $probeOnD).Hash) {
    throw 'Junction paths do not expose the same bytes.'
}
$report = [ordered]@{
    verified_at = [DateTime]::UtcNow.ToString('o')
    logical_directory = $imageLink
    physical_directory = $resolvedTarget
    link_type = $linkItem.LinkType
    probe_physical_path = $probeOnD
    probe_method = 'Write directly to D:, read through junction, compare hashes; no C: write calls.'
    verified = $true
    scope = 'Generated image payload storage; Codex application logs/settings are not relocated.'
}
$reportPath = Join-Path $projectRoot '.tmp/imagegen_storage/redirection.json'
$report | ConvertTo-Json | Set-Content -LiteralPath $reportPath -Encoding utf8
$report | ConvertTo-Json
