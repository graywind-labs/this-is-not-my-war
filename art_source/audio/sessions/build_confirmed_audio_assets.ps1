param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDir '../../..')).Path
$reviewsRoot = Join-Path $projectRoot 'art_source/audio/reviews'
$mastersRoot = Join-Path $projectRoot 'art_source/audio/masters'
$runtimeRoot = Join-Path $projectRoot 'assets/audio'
$manifestRoot = Join-Path $runtimeRoot 'manifests'
$ffmpeg = (Get-ChildItem -LiteralPath (Join-Path $projectRoot 'art_source/audio/tools/ffmpeg') -Recurse -Filter 'ffmpeg.exe' | Select-Object -First 1).FullName
$ffprobe = (Get-ChildItem -LiteralPath (Join-Path $projectRoot 'art_source/audio/tools/ffmpeg') -Recurse -Filter 'ffprobe.exe' | Select-Object -First 1).FullName

if (-not $ffmpeg -or -not (Test-Path -LiteralPath $ffmpeg)) {
    throw 'Portable FFmpeg was not found under art_source/audio/tools/ffmpeg.'
}
if (-not $ffprobe -or -not (Test-Path -LiteralPath $ffprobe)) {
    throw 'Portable FFprobe was not found under art_source/audio/tools/ffmpeg.'
}

function To-ProjectRelativePath([string]$Path) {
    $absolute = [System.IO.Path]::GetFullPath($Path)
    $rootWithSeparator = $projectRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $absolute.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside project root: $absolute"
    }
    $relative = $absolute.Substring($rootWithSeparator.Length)
    return $relative.Replace('\', '/')
}

function Get-ProbeValue([string]$Path, [string]$Entry) {
    $value = & $ffprobe -v error -select_streams a:0 -show_entries $Entry -of default=noprint_wrappers=1:nokey=1 -- $Path
    if ($LASTEXITCODE -ne 0) {
        throw "FFprobe failed for $Path"
    }
    return ($value | Select-Object -First 1).Trim()
}

function Get-DurationSeconds([string]$Path) {
    $raw = Get-ProbeValue $Path 'format=duration'
    return [double]::Parse($raw, [Globalization.CultureInfo]::InvariantCulture)
}

function Get-TrimSpec([string]$FileName) {
    $spec = [ordered]@{ Start = 0.0; Duration = $null; Description = 'full_source' }
    switch -Regex ($FileName) {
        '^04_blacksmith_hammer_anvil_' { $spec.Duration = 5.0; $spec.Description = '00:00-00:05'; break }
        '^08_stable_horse_snorts_' { $spec.Start = 1.0; $spec.Description = '00:01-end'; break }
        '^01_female_none_three_hm_' { $spec.Duration = 1.0; $spec.Description = '00:00-00:01'; break }
        '^04_female_afraid_breathing_' { $spec.Duration = 2.0; $spec.Description = '00:00-00:02'; break }
        '^06_male_surprised_set_' { $spec.Start = 1.0; $spec.Duration = 1.0; $spec.Description = '00:01-00:02'; break }
        '^12_horse_gallop_foley_' { $spec.Duration = 10.0; $spec.Description = '00:00-00:10'; break }
        '^06_chapel_church_bell_' { $spec.Duration = 5.0; $spec.Description = '00:00-00:05'; break }
        '^09_drinking_sip_swallow_' { $spec.Duration = 1.0; $spec.Description = '00:00-00:01'; break }
        '^06_enemy_hit_impacts_' { $spec.Duration = 1.0; $spec.Description = '00:00-00:01'; break }
    }
    return [pscustomobject]$spec
}

function Get-RuntimeSubdirectory([string]$Usage) {
    switch -Regex ($Usage) {
        '^bgm_menu$' { return 'music/menu' }
        '^bgm_day_night$' { return 'music/day' }
        '^bgm_battle$' { return 'music/combat' }
        '^ambience_(day|night)_loop$' { return 'ambience/time_of_day' }
        '^ambience_' { return 'ambience/local_emitters' }
        '^ui_' { return 'ui' }
        '^work_garden_' { return 'work/garden' }
        '^work_dining_hall_|^daily_eating_|^daily_drinking_' { return 'work/dining_hall' }
        '^work_stable_' { return 'work/stable' }
        '^work_tavern_' { return 'work/tavern' }
        '^work_blacksmith_' { return 'work/blacksmith' }
        '^work_workshop_' { return 'work/workshop' }
        '^work_training_' { return 'work/training' }
        '^work_clinic_' { return 'work/clinic' }
        '^chapel_' { return 'work/chapel' }
        '^work_repair_' { return 'work/construction' }
        '^npc_emotion_' { return 'voice/emotions' }
        '^combat_.*hurt_voice$' { return 'voice/combat_grunts' }
        '^foley_run_' { return 'foley/footsteps' }
        '^horse_run$' { return 'foley/horses' }
        '^merchant_cart_' { return 'world/merchant' }
        '^world_battle_alert_' { return 'world/bell' }
        '^world_door_' { return 'world/doors' }
        '^meteor_' { return 'abilities/meteor' }
        '^combat_.*(whoosh|projectile)' { return 'combat/projectiles' }
        '^combat_.*impact$|^combat_hit_|^combat_unconscious_|^combat_horse_death$' { return 'combat/impacts' }
        '^ballista_heavy_bolt_impact$' { return 'combat/impacts' }
        '^combat_ballista_release$|^arrow_tower_release$' { return 'combat/defense_devices' }
        '^combat_(sword|polearm|bow|hand_crossbow)' { return 'combat/weapons' }
        '^combat_.*structure_|^wood_structure_|^stone_structure_' { return 'combat/structures' }
        'stinger$' { return 'combat/stingers' }
        '^combat_wood_damage_' { return 'combat/structures' }
        '^combat_stone_structure_' { return 'combat/structures' }
        '^combat_ballista_bolt_' { return 'combat/impacts' }
        default { throw "No runtime directory mapping for usage: $Usage" }
    }
}

function Get-BaseName([string]$Usage, [int]$VariantIndex, [int]$VariantCount) {
    $semantic = $Usage -replace '_random$', '' -replace '_random_one_shot$', ''
    if ($semantic -eq 'bgm_day_night') {
        $base = 'music_day_night'
    } elseif ($semantic.StartsWith('bgm_')) {
        $base = 'music_' + $semantic.Substring(4)
    } elseif ($semantic.StartsWith('npc_emotion_')) {
        $base = 'voice_emotion_' + $semantic.Substring(12)
    } elseif ($semantic -match '^combat_.*hurt_voice$') {
        $base = 'voice_' + $semantic
    } else {
        $base = 'sfx_' + $semantic
    }
    if ($VariantCount -gt 1) {
        $base += '_{0:d2}' -f $VariantIndex
    }
    return $base + '_v01'
}

function Get-TargetLufs([string]$Usage) {
    switch -Regex ($Usage) {
        '^bgm_' { return -16.0 }
        '^ambience_' { return -23.0 }
        '^work_|^daily_|^chapel_' { return -20.0 }
        '^foley_|^horse_run$|^merchant_cart_' { return -20.0 }
        '^npc_emotion_|hurt_voice$' { return -18.0 }
        '^ui_' { return -18.0 }
        '^world_' { return -18.0 }
        'meteor_|combat_|stinger$|structure_' { return -16.0 }
        default { return -18.0 }
    }
}

function Get-MaxDistance([string]$Usage) {
    switch -Regex ($Usage) {
        '^bgm_|^ui_' { return 0 }
        '^npc_emotion_|^foley_|^horse_run$' { return 18 }
        '^work_|^daily_|^chapel_|^merchant_cart_|^world_door_' { return 28 }
        '^ambience_' { return 45 }
        'meteor_' { return 120 }
        'alert|stinger|collapse' { return 70 }
        '^combat_' { return 40 }
        default { return 40 }
    }
}

function Get-RuntimeFade([string]$Usage, [bool]$Loop) {
    if ($Usage -match '^bgm_') { return [pscustomobject]@{ In = 2000; Out = 2000; Mode = 'baked_each_cycle' } }
    if (-not $Loop) { return [pscustomobject]@{ In = 0; Out = 0; Mode = 'none' } }
    if ($Usage -match '^work_|^daily_|^chapel_') { return [pscustomobject]@{ In = 350; Out = 350; Mode = 'runtime_start_stop' } }
    if ($Usage -match '^ambience_') { return [pscustomobject]@{ In = 1000; Out = 1000; Mode = 'runtime_start_stop' } }
    return [pscustomobject]@{ In = 0; Out = 0; Mode = 'immediate_start_stop' }
}

function Get-PlaybackClass([string]$Usage, [string]$EditInstruction) {
    $loop = ($Usage -match 'loop$|_loop_' -or $Usage -match '^bgm_' -or $Usage -eq 'horse_run' -or $Usage -eq 'merchant_cart_arrival_departure')
    return [pscustomobject]@{
        Loop = $loop
        Channels = $(if ($Usage -match '^bgm_') { 2 } else { 1 })
        RuntimeExtension = $(if ($loop -or $Usage -match '^bgm_') { '.ogg' } else { '.wav' })
    }
}

New-Item -ItemType Directory -Force -Path $mastersRoot, $runtimeRoot, $manifestRoot | Out-Null

$confirmed = @()
$sourceCsvs = Get-ChildItem -LiteralPath $reviewsRoot -Recurse -Filter 'SOURCES.csv' | Sort-Object FullName
foreach ($csv in $sourceCsvs) {
    $packName = Split-Path (Split-Path $csv.FullName -Parent) -Leaf
    $rows = Import-Csv -LiteralPath $csv.FullName -Encoding UTF8
    foreach ($row in ($rows | Where-Object decision -eq 'confirmed')) {
        $sourcePath = Join-Path (Split-Path $csv.FullName -Parent) $row.file
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            throw "Confirmed source file is missing: $sourcePath"
        }
        $confirmed += [pscustomobject]@{
            Pack = $packName
            SourceCsv = $csv.FullName
            SourcePath = $sourcePath
            Row = $row
        }
    }
}

if ($confirmed.Count -ne 90) {
    throw "Expected 90 confirmed source records, found $($confirmed.Count)."
}

$usageCounts = @{}
foreach ($item in $confirmed) {
    $usage = $item.Row.final_usage
    if (-not $usageCounts.ContainsKey($usage)) { $usageCounts[$usage] = 0 }
    $usageCounts[$usage] += 1
}
$usageIndexes = @{}
$manifestRows = @()
$creditRows = @()
$playlistPaths = @()
$processed = 0

foreach ($item in $confirmed) {
    $row = $item.Row
    $usage = $row.final_usage
    if (-not $usageIndexes.ContainsKey($usage)) { $usageIndexes[$usage] = 0 }
    $usageIndexes[$usage] += 1
    $variantIndex = $usageIndexes[$usage]
    $variantCount = $usageCounts[$usage]
    $playback = Get-PlaybackClass $usage $row.edit_instruction
    $runtimeSubdirectory = Get-RuntimeSubdirectory $usage
    $baseName = Get-BaseName $usage $variantIndex $variantCount
    $runtimeDirectory = Join-Path $runtimeRoot $runtimeSubdirectory
    $masterDirectory = Join-Path $mastersRoot $runtimeSubdirectory
    New-Item -ItemType Directory -Force -Path $runtimeDirectory, $masterDirectory | Out-Null
    $masterPath = Join-Path $masterDirectory ($baseName + '.wav')
    $runtimePath = Join-Path $runtimeDirectory ($baseName + $playback.RuntimeExtension)
    $trim = Get-TrimSpec $row.file
    $sourceDuration = Get-DurationSeconds $item.SourcePath
    $trimmedDuration = $sourceDuration - $trim.Start
    if ($null -ne $trim.Duration) { $trimmedDuration = [math]::Min($trimmedDuration, $trim.Duration) }
    if ($trimmedDuration -le 0.05) { throw "Invalid trim duration for $($row.file)" }
    $targetLufs = Get-TargetLufs $usage
    $filters = @()
    if ($usage -match '^bgm_') {
        $fadeDuration = [math]::Min(2.0, [math]::Max(0.1, $trimmedDuration / 4.0))
        $fadeOutStart = [math]::Max(0.0, $trimmedDuration - $fadeDuration)
        $filters += ('afade=t=in:st=0:d={0}' -f $fadeDuration.ToString('0.###', [Globalization.CultureInfo]::InvariantCulture))
        $filters += ('afade=t=out:st={0}:d={1}' -f $fadeOutStart.ToString('0.###', [Globalization.CultureInfo]::InvariantCulture), $fadeDuration.ToString('0.###', [Globalization.CultureInfo]::InvariantCulture))
    }
    $filters += ('loudnorm=I={0}:LRA=11:TP=-2' -f $targetLufs.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture))
    $filterGraph = $filters -join ','
    $masterArgs = @('-hide_banner', '-loglevel', 'error', '-y')
    if ($trim.Start -gt 0) { $masterArgs += @('-ss', $trim.Start.ToString('0.###', [Globalization.CultureInfo]::InvariantCulture)) }
    $masterArgs += @('-i', $item.SourcePath)
    if ($null -ne $trim.Duration) { $masterArgs += @('-t', $trim.Duration.ToString('0.###', [Globalization.CultureInfo]::InvariantCulture)) }
    $masterArgs += @('-vn', '-af', $filterGraph, '-ar', '48000', '-ac', [string]$playback.Channels, '-c:a', 'pcm_s24le', $masterPath)
    & $ffmpeg @masterArgs
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $masterPath)) {
        throw "Master generation failed for $($row.file)"
    }
    $runtimeArgs = @('-hide_banner', '-loglevel', 'error', '-y', '-i', $masterPath, '-vn', '-ar', '48000', '-ac', [string]$playback.Channels)
    if ($playback.RuntimeExtension -eq '.ogg') {
        $runtimeArgs += @('-c:a', 'libvorbis', '-q:a', '5', $runtimePath)
        $runtimeCodec = 'vorbis_q5'
    } else {
        $runtimeArgs += @('-c:a', 'pcm_s16le', $runtimePath)
        $runtimeCodec = 'pcm_s16le'
    }
    & $ffmpeg @runtimeArgs
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $runtimePath)) {
        throw "Runtime generation failed for $($row.file)"
    }
    $runtimeDuration = Get-DurationSeconds $runtimePath
    $sampleRate = Get-ProbeValue $runtimePath 'stream=sample_rate'
    $channels = Get-ProbeValue $runtimePath 'stream=channels'
    $fade = Get-RuntimeFade $usage $playback.Loop
    $sourceHash = (Get-FileHash -LiteralPath $item.SourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $runtimeHash = (Get-FileHash -LiteralPath $runtimePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $assetId = ($baseName -replace '_v01$', '')
    $manifestRows += [pscustomobject][ordered]@{
        asset_id = $assetId
        final_usage = $usage
        relative_path = To-ProjectRelativePath $runtimePath
        master_path = To-ProjectRelativePath $masterPath
        category = $row.category
        variant = $(if ($variantCount -gt 1) { '{0:d2}' -f $variantIndex } else { '01' })
        duration_seconds = $runtimeDuration.ToString('0.000', [Globalization.CultureInfo]::InvariantCulture)
        loop = $playback.Loop.ToString().ToLowerInvariant()
        loop_start_seconds = $(if ($playback.Loop) { '0.000' } else { '' })
        loop_end_seconds = $(if ($playback.Loop) { $runtimeDuration.ToString('0.000', [Globalization.CultureInfo]::InvariantCulture) } else { '' })
        channels = $channels
        sample_rate_hz = $sampleRate
        runtime_codec = $runtimeCodec
        master_format = 'wav_pcm_s24le_48khz'
        target_lufs = $targetLufs.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)
        suggested_gain_db = '0.0'
        suggested_max_distance_m = $(if ((Get-MaxDistance $usage) -eq 0) { '' } else { [string](Get-MaxDistance $usage) })
        runtime_fade_in_ms = [string]$fade.In
        runtime_fade_out_ms = [string]$fade.Out
        fade_mode = $fade.Mode
        source_title = $row.source_title
        source_author = $row.author
        source_url = $row.source_url
        license = $row.license
        review_pack = $item.Pack
        review_source_file = $row.file
        source_sha256 = $sourceHash
        runtime_sha256 = $runtimeHash
        trim_applied = $trim.Description
        playback_rule = $row.edit_instruction
        version = 'v01'
        acceptance_status = 'confirmed'
        build_date = '2026-09-01'
    }
    $creditRows += [pscustomobject][ordered]@{
        asset_id = $assetId
        runtime_path = To-ProjectRelativePath $runtimePath
        source_title = $row.source_title
        author = $row.author
        source_url = $row.source_url
        license = $row.license
        source_file = $row.file
        source_sha256 = $sourceHash
    }
    $playlistPaths += To-ProjectRelativePath $runtimePath
    $processed += 1
    Write-Host ("[{0:d2}/90] {1}" -f $processed, (To-ProjectRelativePath $runtimePath))
}

$manifestPath = Join-Path $manifestRoot 'audio_asset_manifest.csv'
$creditsPath = Join-Path $manifestRoot 'third_party_audio_credits.csv'
$playlistPath = Join-Path $manifestRoot 'final_audio_review.m3u8'
$manifestRows | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding utf8
$creditRows | Export-Csv -LiteralPath $creditsPath -NoTypeInformation -Encoding utf8
$playlistLines = @('#EXTM3U') + ($playlistPaths | ForEach-Object { '../' + ($_ -replace '^assets/audio/', '') })
Set-Content -LiteralPath $playlistPath -Value $playlistLines -Encoding utf8

Write-Host "Generated $processed confirmed runtime assets."
Write-Host "Manifest: $(To-ProjectRelativePath $manifestPath)"
Write-Host "Credits: $(To-ProjectRelativePath $creditsPath)"
Write-Host "Playlist: $(To-ProjectRelativePath $playlistPath)"
