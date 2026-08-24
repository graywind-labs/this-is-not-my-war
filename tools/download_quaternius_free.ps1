param(
    [string[]]$Slugs = @(
        "medieval-village-megakit",
        "fantasy-props-megakit",
        "universal-base-characters",
        "modular-character-outfits-fantasy",
        "universal-animation-library-2",
        "stylized-nature-megakit"
    ),
    [int]$ChunkSizeMb = 16,
    [string]$ProxyUri = "http://127.0.0.1:7897"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$downloadDir = [IO.Path]::GetFullPath((Join-Path $projectRoot "art_source\downloads\quaternius"))
$chunksRoot = [IO.Path]::GetFullPath((Join-Path $downloadDir ".chunks"))
New-Item -ItemType Directory -Force -Path $downloadDir, $chunksRoot | Out-Null
$curlProxyArgs = if ($ProxyUri) {
    @("--proxy", $ProxyUri)
}
else {
    @("--noproxy", "*")
}

function Test-ZipArchive([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        & $python.Source `
            -c `
            "import sys, zipfile; archive = zipfile.ZipFile(sys.argv[1]); bad = archive.testzip(); archive.close(); raise SystemExit(0 if bad is None else 1)" `
            $Path `
            2>$null
        return $LASTEXITCODE -eq 0
    }
    try {
        $zip = [IO.Compression.ZipFile]::OpenRead($Path)
        $fileCount = 0
        $buffer = New-Object byte[] (1MB)
        try {
            foreach ($entry in $zip.Entries) {
                if (-not $entry.Name) {
                    continue
                }
                $fileCount += 1
                $stream = $entry.Open()
                try {
                    while ($stream.Read($buffer, 0, $buffer.Length) -gt 0) {
                    }
                }
                finally {
                    $stream.Dispose()
                }
            }
        }
        finally {
            $zip.Dispose()
        }
        return $fileCount -gt 0
    }
    catch {
        return $false
    }
}

function Get-FreeDownloadUrl([string]$Slug) {
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $purchaseUrl = "https://quaternius.itch.io/$Slug/purchase?popup=1"
    $purchase = Invoke-WebRequest -UseBasicParsing -WebSession $session -Uri $purchaseUrl
    $csrf = [regex]::Match(
        $purchase.Content,
        'meta name="csrf_token" value="([^"]+)"'
    ).Groups[1].Value
    if (-not $csrf) {
        throw "Could not resolve purchase CSRF token for $Slug"
    }

    $jumpResponse = Invoke-WebRequest `
        -UseBasicParsing `
        -WebSession $session `
        -Method Post `
        -Uri "https://quaternius.itch.io/$Slug/download_url" `
        -Body @{ csrf_token = $csrf; reward_id = "" } `
        -Headers @{ "X-Requested-With" = "XMLHttpRequest"; Referer = $purchaseUrl }
    $jumpUrl = ($jumpResponse.Content | ConvertFrom-Json).url

    $downloadPage = Invoke-WebRequest -UseBasicParsing -WebSession $session -Uri $jumpUrl
    $downloadCsrf = [regex]::Match(
        $downloadPage.Content,
        'meta name="csrf_token" value="([^"]+)"'
    ).Groups[1].Value
    $uploadId = [regex]::Match(
        $downloadPage.Content,
        'data-upload_id="(\d+)"'
    ).Groups[1].Value
    if ((-not $downloadCsrf) -or (-not $uploadId)) {
        throw "Could not resolve free Standard upload for $Slug"
    }

    $fileResponse = Invoke-WebRequest `
        -UseBasicParsing `
        -WebSession $session `
        -Method Post `
        -Uri "https://quaternius.itch.io/$Slug/file/$uploadId`?source=game_download" `
        -Body @{ csrf_token = $downloadCsrf } `
        -Headers @{ "X-Requested-With" = "XMLHttpRequest"; Referer = $jumpUrl }
    return ($fileResponse.Content | ConvertFrom-Json).url
}

function Get-RemoteSize([string]$Slug, [string]$ChunkDir) {
    $headerPath = Join-Path $ChunkDir "probe.headers"
    $probePath = Join-Path $ChunkDir "probe.bin"
    $signedUrl = Get-FreeDownloadUrl $Slug
    & curl.exe @curlProxyArgs `
        --fail `
        --location `
        --silent `
        --show-error `
        --range "0-0" `
        --dump-header $headerPath `
        --output $probePath `
        $signedUrl
    if ($LASTEXITCODE -ne 0) {
        throw "Remote-size probe failed for $Slug"
    }
    $headers = Get-Content -LiteralPath $headerPath -Raw
    $sizeMatch = [regex]::Match(
        $headers,
        'Content-Range:\s*bytes\s+0-0/(\d+)',
        [Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if (-not $sizeMatch.Success) {
        throw "Remote-size probe returned no Content-Range for $Slug"
    }
    return [int64]$sizeMatch.Groups[1].Value
}

function Remove-ScopedDirectory([string]$Path) {
    $resolved = [IO.Path]::GetFullPath($Path)
    if ((-not $resolved.StartsWith($chunksRoot, [StringComparison]::OrdinalIgnoreCase)) -or
        ($resolved -eq $chunksRoot)) {
        throw "Refusing unsafe chunk cleanup: $resolved"
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}

$chunkSize = [int64]$ChunkSizeMb * 1MB
foreach ($slug in $Slugs) {
    $target = [IO.Path]::GetFullPath((Join-Path $downloadDir "$slug-standard.zip"))
    if (-not $target.StartsWith($downloadDir, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing unsafe archive target: $target"
    }
    if (Test-ZipArchive $target) {
        Write-Output "VALID_SKIP $slug"
        continue
    }

    $chunkDir = [IO.Path]::GetFullPath((Join-Path $chunksRoot $slug))
    New-Item -ItemType Directory -Force -Path $chunkDir | Out-Null
    $totalSize = Get-RemoteSize $slug $chunkDir
    $chunkCount = [int][Math]::Ceiling($totalSize / $chunkSize)
    Write-Output "CHUNK_PLAN $slug bytes=$totalSize chunks=$chunkCount"

    for ($index = 0; $index -lt $chunkCount; $index++) {
        $rangeStart = [int64]$index * $chunkSize
        $rangeEnd = [Math]::Min($totalSize - 1, $rangeStart + $chunkSize - 1)
        $expectedSize = $rangeEnd - $rangeStart + 1
        $partPath = Join-Path $chunkDir ("part-{0:D3}.bin" -f $index)
        if ((Test-Path -LiteralPath $partPath) -and
            ((Get-Item -LiteralPath $partPath).Length -eq $expectedSize)) {
            Write-Output "PART_SKIP $slug $($index + 1)/$chunkCount"
            continue
        }
        if (Test-Path -LiteralPath $partPath) {
            Remove-Item -LiteralPath $partPath -Force
        }

        $partComplete = $false
        for ($attempt = 1; ($attempt -le 10) -and (-not $partComplete); $attempt++) {
            $signedUrl = Get-FreeDownloadUrl $slug
            & curl.exe @curlProxyArgs `
                --fail `
                --location `
                --silent `
                --show-error `
                --connect-timeout 20 `
                --max-time 180 `
                --range "$rangeStart-$rangeEnd" `
                --output $partPath `
                $signedUrl
            if (($LASTEXITCODE -eq 0) -and
                (Test-Path -LiteralPath $partPath) -and
                ((Get-Item -LiteralPath $partPath).Length -eq $expectedSize)) {
                $partComplete = $true
                Write-Output "PART_DONE $slug $($index + 1)/$chunkCount"
            }
            else {
                Write-Output "PART_RETRY $slug $($index + 1)/$chunkCount attempt=$attempt"
                if (Test-Path -LiteralPath $partPath) {
                    Remove-Item -LiteralPath $partPath -Force
                }
            }
        }
        if (-not $partComplete) {
            throw "Could not download chunk $index for $slug"
        }
    }

    # Replace only a known-invalid partial archive inside the isolated download directory.
    if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Force
    }
    $output = [IO.File]::Open(
        $target,
        [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None
    )
    try {
        for ($index = 0; $index -lt $chunkCount; $index++) {
            $partPath = Join-Path $chunkDir ("part-{0:D3}.bin" -f $index)
            $input = [IO.File]::OpenRead($partPath)
            try {
                $input.CopyTo($output)
            }
            finally {
                $input.Dispose()
            }
        }
    }
    finally {
        $output.Dispose()
    }

    if ((Get-Item -LiteralPath $target).Length -ne $totalSize) {
        throw "Merged archive size mismatch for $slug"
    }
    if (-not (Test-ZipArchive $target)) {
        throw "Merged archive failed ZIP validation for $slug"
    }
    Write-Output "VALID_MERGED $slug bytes=$totalSize"
    Remove-ScopedDirectory $chunkDir
}

$licenseTarget = Join-Path $projectRoot "art_source\licenses\CC0-1.0-legalcode.txt"
Invoke-WebRequest `
    -UseBasicParsing `
    -Uri "https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt" `
    -OutFile $licenseTarget
Write-Output "ALL_DOWNLOADS_VALID"
