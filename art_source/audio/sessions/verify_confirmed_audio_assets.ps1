$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDir '../../..')).Path
$manifestPath = Join-Path $projectRoot 'assets/audio/manifests/audio_asset_manifest.csv'
$qaPath = Join-Path $projectRoot 'assets/audio/manifests/audio_asset_qa.csv'
$playlistPath = Join-Path $projectRoot 'assets/audio/manifests/final_audio_review.m3u8'
$ffmpeg = (Get-ChildItem -LiteralPath (Join-Path $projectRoot 'art_source/audio/tools/ffmpeg') -Recurse -Filter 'ffmpeg.exe' | Select-Object -First 1).FullName
$ffprobe = (Get-ChildItem -LiteralPath (Join-Path $projectRoot 'art_source/audio/tools/ffmpeg') -Recurse -Filter 'ffprobe.exe' | Select-Object -First 1).FullName

function Resolve-ProjectPath([string]$RelativePath) {
    return Join-Path $projectRoot ($RelativePath -replace '/', '\')
}

function Probe-Audio([string]$Path) {
    $jsonText = & $ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,sample_rate,channels -show_entries format=duration -of json -- $Path
    if ($LASTEXITCODE -ne 0) { throw "FFprobe failed: $Path" }
    return ($jsonText | Out-String | ConvertFrom-Json)
}

function Measure-PeakDb([string]$Path) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $ffmpeg -hide_banner -nostats -i $Path -af volumedetect -f null NUL 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($exitCode -ne 0) { throw "Peak scan failed: $Path" }
    $match = [regex]::Match($output, 'max_volume:\s*(-?inf|[-+0-9.]+) dB')
    if (-not $match.Success) { throw "Peak result missing: $Path" }
    if ($match.Groups[1].Value -eq '-inf') { return -999.0 }
    return [double]::Parse($match.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
}

$manifest = Import-Csv -LiteralPath $manifestPath -Encoding UTF8
if ($manifest.Count -ne 102) { throw "Manifest must contain 102 rows; found $($manifest.Count)." }

$runtimeFiles = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'assets/audio') -Recurse -File | Where-Object Extension -in '.wav', '.ogg'
$masterFiles = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'art_source/audio/masters') -Recurse -Filter '*.wav' -File
if ($runtimeFiles.Count -ne 102) { throw "Expected 102 runtime audio files; found $($runtimeFiles.Count)." }
if ($masterFiles.Count -ne 102) { throw "Expected 102 master WAV files; found $($masterFiles.Count)." }

$qaRows = @()
foreach ($row in $manifest) {
    $runtimePath = Resolve-ProjectPath $row.relative_path
    $masterPath = Resolve-ProjectPath $row.master_path
    if (-not (Test-Path -LiteralPath $runtimePath)) { throw "Missing runtime file: $runtimePath" }
    if (-not (Test-Path -LiteralPath $masterPath)) { throw "Missing master file: $masterPath" }
    $probe = Probe-Audio $runtimePath
    $stream = $probe.streams[0]
    $duration = [double]::Parse([string]$probe.format.duration, [Globalization.CultureInfo]::InvariantCulture)
    $peakDb = Measure-PeakDb $runtimePath
    $expectedExtension = $(if ($row.loop -eq 'true' -or $row.category -match '^bgm_') { '.ogg' } else { '.wav' })
    $extensionOk = [System.IO.Path]::GetExtension($runtimePath).ToLowerInvariant() -eq $expectedExtension
    $rateOk = [string]$stream.sample_rate -eq '48000'
    $channelsOk = [string]$stream.channels -eq $row.channels
    $durationOk = [math]::Abs($duration - [double]::Parse($row.duration_seconds, [Globalization.CultureInfo]::InvariantCulture)) -lt 0.02
    $peakOk = $peakDb -le -0.5
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $decodeOutput = & $ffmpeg -hide_banner -loglevel error -i $runtimePath -f null NUL 2>&1 | Out-String
        $decodeExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    $decodeOk = $decodeExitCode -eq 0
    $status = $(if ($extensionOk -and $rateOk -and $channelsOk -and $durationOk -and $peakOk -and $decodeOk) { 'pass' } else { 'fail' })
    $qaRows += [pscustomobject][ordered]@{
        asset_id = $row.asset_id
        relative_path = $row.relative_path
        status = $status
        duration_seconds = $duration.ToString('0.000', [Globalization.CultureInfo]::InvariantCulture)
        codec = [string]$stream.codec_name
        sample_rate_hz = [string]$stream.sample_rate
        channels = [string]$stream.channels
        peak_db = $peakDb.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)
        extension_ok = $extensionOk.ToString().ToLowerInvariant()
        duration_ok = $durationOk.ToString().ToLowerInvariant()
        sample_rate_ok = $rateOk.ToString().ToLowerInvariant()
        channels_ok = $channelsOk.ToString().ToLowerInvariant()
        peak_headroom_ok = $peakOk.ToString().ToLowerInvariant()
        decode_ok = $decodeOk.ToString().ToLowerInvariant()
    }
}

$playlistEntries = Get-Content -LiteralPath $playlistPath -Encoding UTF8 | Where-Object { $_ -and -not $_.StartsWith('#') }
$missingPlaylistEntries = @()
foreach ($entry in $playlistEntries) {
    $candidate = Join-Path (Split-Path $playlistPath -Parent) ($entry -replace '/', '\')
    if (-not (Test-Path -LiteralPath $candidate)) { $missingPlaylistEntries += $entry }
}
if ($playlistEntries.Count -ne 102) { throw "Review playlist must contain 102 entries; found $($playlistEntries.Count)." }
if ($missingPlaylistEntries.Count -gt 0) { throw "Review playlist has missing entries: $($missingPlaylistEntries -join ', ')" }

$qaRows | Export-Csv -LiteralPath $qaPath -NoTypeInformation -Encoding utf8
$failed = @($qaRows | Where-Object status -ne 'pass')
if ($failed.Count -gt 0) {
    $failed | Format-Table -AutoSize | Out-String | Write-Host
    throw "$($failed.Count) runtime assets failed QA."
}

Write-Host "QA passed: 102 runtime assets, 102 masters, 102 playlist entries."
Write-Host "Peak range: $((($qaRows | ForEach-Object { [double]$_.peak_db }) | Measure-Object -Minimum).Minimum) dB to $((($qaRows | ForEach-Object { [double]$_.peak_db }) | Measure-Object -Maximum).Maximum) dB."
Write-Host "QA report: assets/audio/manifests/audio_asset_qa.csv"
