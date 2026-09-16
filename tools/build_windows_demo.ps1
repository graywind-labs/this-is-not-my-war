[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Stage([string]$Name) {
    Write-Host "[$Name]"
}

function Move-DirectoryWithRetry([string]$Source, [string]$Destination) {
    $attempts = 12
    for ($attempt = 1; $attempt -le $attempts; $attempt++) {
        try {
            Move-Item -LiteralPath $Source -Destination $Destination -ErrorAction Stop
            return
        }
        catch {
            if ($attempt -eq $attempts) {
                throw
            }
            Start-Sleep -Milliseconds (250 * $attempt)
        }
    }
}

function Get-EnvFileValue([string[]]$Lines, [string]$Name) {
    $prefix = "$Name="
    foreach ($line in $Lines) {
        if ($line.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
            return $line.Substring($prefix.Length).Trim()
        }
    }
    return ''
}

function Get-SecretFingerprint([string]$Value) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash).Replace('-', '').ToLowerInvariant()).Substring(0, 12)
    }
    finally {
        $sha.Dispose()
        [System.Array]::Clear($bytes, 0, $bytes.Length)
    }
}

function Read-DemoDeepSeekKey {
    $fromEnvironment = [Environment]::GetEnvironmentVariable('THIS_IS_NOT_MY_WAR_DEMO_DEEPSEEK_API_KEY', 'Process')
    if (-not [string]::IsNullOrWhiteSpace($fromEnvironment)) {
        return $fromEnvironment.Trim()
    }
    $secure = Read-Host 'DeepSeek API Key for this demo package' -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer).Trim()
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

$scriptPath = $MyInvocation.MyCommand.Path
$workspace = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $scriptPath) '..'))
$configPath = Join-Path $workspace 'tools\release\demo_build_config.json'
$envPath = Join-Path $workspace 'backend\.env'
$buildRoot = $null
$publishCandidate = $null
$distRoot = $null
$originalSecretEnvironment = @{}
$secretEnvironmentNames = @(
    'THIS_IS_NOT_MY_WAR_DEMO_DEEPSEEK_API_KEY',
    'DASHSCOPE_API_KEY',
    'VOICE_WORKSPACE_ID',
    'VOICE_BASE_URL',
    'DEVELOPMENT_DEEPSEEK_API_KEY_FOR_AUDIT'
)

foreach ($name in $secretEnvironmentNames) {
    $originalSecretEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

try {
    Write-Stage '00 AcquireSecret'
    $demoDeepSeekKey = Read-DemoDeepSeekKey
    if ([string]::IsNullOrWhiteSpace($demoDeepSeekKey)) {
        throw 'A non-empty demo DeepSeek API Key is required.'
    }

    Write-Stage '01 Preflight'
    if (-not (Test-Path -LiteralPath (Join-Path $workspace 'project.godot') -PathType Leaf)) {
        throw "The Godot project root could not be recognized: $workspace"
    }
    $config = Get-Content -Raw -Encoding UTF8 -LiteralPath $configPath | ConvertFrom-Json
    $backendPort = [int]$config.backend_port
    $portListeners = @(Get-NetTCPConnection -LocalPort $backendPort -State Listen -ErrorAction SilentlyContinue)
    if ($portListeners.Count -gt 0) {
        $ownerIds = @($portListeners | Select-Object -ExpandProperty OwningProcess -Unique | Sort-Object)
        throw "Demo backend port $backendPort is already occupied (PID: $($ownerIds -join ', ')). Close the development backend or another demo instance, then retry. No existing process was stopped."
    }
    $envLines = Get-Content -Encoding UTF8 -LiteralPath $envPath
    $developmentDeepSeekKey = Get-EnvFileValue $envLines 'LLM_API_KEY'
    $voiceKey = Get-EnvFileValue $envLines 'DASHSCOPE_API_KEY'
    $voiceWorkspace = Get-EnvFileValue $envLines 'VOICE_WORKSPACE_ID'
    $voiceBaseUrl = Get-EnvFileValue $envLines 'VOICE_BASE_URL'
    foreach ($pair in @(
        @('DASHSCOPE_API_KEY', $voiceKey),
        @('VOICE_WORKSPACE_ID', $voiceWorkspace),
        @('VOICE_BASE_URL', $voiceBaseUrl)
    )) {
        if ([string]::IsNullOrWhiteSpace([string]$pair[1])) {
            throw "backend/.env is missing required demo voice configuration: $($pair[0])"
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($developmentDeepSeekKey) -and $demoDeepSeekKey -ceq $developmentDeepSeekKey) {
        throw 'The demo DeepSeek Key matches the development Key. Use a separate limited and revocable demo Key.'
    }
    $pythonVersion = & python --version 2>&1
    if ($LASTEXITCODE -ne 0 -or $pythonVersion -notmatch '^Python 3\.11\.') {
        throw "Python 3.11 is required. Current version: $pythonVersion"
    }
    $godotVersion = & godot --version 2>&1
    if ($LASTEXITCODE -ne 0 -or -not $godotVersion.StartsWith('4.6.2.stable')) {
        throw "Godot 4.6.2-stable is required. Current version: $godotVersion"
    }
    & python (Join-Path $workspace 'tools\release\verify_branding_icon.py') --source-root $workspace
    if ($LASTEXITCODE -ne 0) { throw 'The shared Windows branding icon does not satisfy the release contract.' }

    $buildId = "demo-{0}-{1}" -f (Get-Date -Format 'yyyyMMddHHmmss'), ((git -C $workspace rev-parse --short HEAD) | Select-Object -First 1)
    $buildRoot = Join-Path ([IO.Path]::GetTempPath()) ("ThisIsNotMyWarDemoBuild\" + [Guid]::NewGuid().ToString('N'))
    $stagingRoot = Join-Path $buildRoot 'staging'
    $packageRoot = Join-Path $buildRoot 'package'
    $workRoot = Join-Path $buildRoot 'work'
    New-Item -ItemType Directory -Path $buildRoot | Out-Null
    New-Item -ItemType Directory -Path $packageRoot | Out-Null
    New-Item -ItemType Directory -Path $workRoot | Out-Null

    Write-Stage '02 PrepareBuildTools'
    $cacheRoot = Join-Path $env:LOCALAPPDATA 'ThisIsNotMyWarDemoBuildCache'
    $venvRoot = Join-Path $cacheRoot 'python311'
    $venvPython = Join-Path $venvRoot 'Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) {
        New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
        & python -m venv $venvRoot
        if ($LASTEXITCODE -ne 0) { throw 'Failed to create the isolated build virtual environment.' }
    }
    & $venvPython -m pip install --disable-pip-version-check -q -r (Join-Path $workspace 'backend\requirements.txt') -r (Join-Path $workspace 'tools\release\requirements-build.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Failed to install pinned build dependencies.' }
    & $venvPython (Join-Path $workspace 'tools\release\ensure_godot_templates.py') --source-root $workspace
    if ($LASTEXITCODE -ne 0) { throw 'Failed to prepare Godot export templates.' }

    Write-Stage '03 CreateIsolatedStaging'
    & $venvPython (Join-Path $workspace 'tools\release\prepare_demo_staging.py') --source-root $workspace --staging-root $stagingRoot
    if ($LASTEXITCODE -ne 0) { throw 'Failed to create the isolated release workspace.' }

    Write-Stage '04 ApplyAndVerifyReleaseProfile'
    & $venvPython (Join-Path $workspace 'tools\verify_t1703_p1_demo_staging.py')
    if ($LASTEXITCODE -ne 0) { throw 'The release profile verification failed.' }

    foreach ($name in $secretEnvironmentNames) {
        [Environment]::SetEnvironmentVariable($name, $null, 'Process')
    }
    [Environment]::SetEnvironmentVariable('THIS_IS_NOT_MY_WAR_DEMO_DEEPSEEK_API_KEY', $demoDeepSeekKey, 'Process')
    [Environment]::SetEnvironmentVariable('DASHSCOPE_API_KEY', $voiceKey, 'Process')
    [Environment]::SetEnvironmentVariable('VOICE_WORKSPACE_ID', $voiceWorkspace, 'Process')
    [Environment]::SetEnvironmentVariable('VOICE_BASE_URL', $voiceBaseUrl, 'Process')
    [Environment]::SetEnvironmentVariable('DEVELOPMENT_DEEPSEEK_API_KEY_FOR_AUDIT', $developmentDeepSeekKey, 'Process')

    Write-Stage '05 BuildBackend'
    & $venvPython (Join-Path $workspace 'tools\release\build_demo_backend.py') --source-root $workspace --output-root (Join-Path $packageRoot 'backend') --work-root (Join-Path $workRoot 'backend') --build-id $buildId
    if ($LASTEXITCODE -ne 0) { throw 'Failed to freeze the demo backend.' }

    Write-Stage '06 ExportGodotClient'
    & $venvPython (Join-Path $workspace 'tools\release\export_demo_client.py') --source-root $workspace --project-root (Join-Path $stagingRoot 'project') --output-root (Join-Path $packageRoot 'game')
    if ($LASTEXITCODE -ne 0) { throw 'Failed to export the Godot release client.' }

    Write-Stage '07 BuildLauncher'
    & $venvPython (Join-Path $workspace 'tools\release\build_demo_launcher.py') --source-root $workspace --output-root (Join-Path $workRoot 'launcher-output') --work-root (Join-Path $workRoot 'launcher')
    if ($LASTEXITCODE -ne 0) { throw 'Failed to build the demo launcher.' }
    $launcherExecutable = @(Get-ChildItem -LiteralPath (Join-Path $workRoot 'launcher-output') -Filter '*.exe' -File)
    if ($launcherExecutable.Count -ne 1) { throw 'The launcher output did not contain exactly one executable.' }
    Copy-Item -LiteralPath $launcherExecutable[0].FullName -Destination (Join-Path $packageRoot $launcherExecutable[0].Name)

    Write-Stage '08 AssemblePackage'
    $deepseekFingerprint = Get-SecretFingerprint $demoDeepSeekKey
    $voiceFingerprint = Get-SecretFingerprint $voiceKey
    & $venvPython (Join-Path $workspace 'tools\release\finalize_demo_package.py') --source-root $workspace --package-root $packageRoot --build-id $buildId --deepseek-fingerprint $deepseekFingerprint --voice-fingerprint $voiceFingerprint
    if ($LASTEXITCODE -ne 0) { throw 'Failed to generate package documentation or the build manifest.' }

    Write-Stage '09 AuditPackage'
    & $venvPython (Join-Path $workspace 'tools\release\audit_demo_package.py') --package-root $packageRoot
    if ($LASTEXITCODE -ne 0) { throw 'The package content or secret isolation audit failed.' }

    Write-Stage '10 VerifyDeepSeekConnection'
    & $venvPython (Join-Path $workspace 'tools\release\verify_demo_provider_connection.py') --backend-executable (Join-Path $packageRoot 'backend\ThisIsNotMyWarBackend.exe') --build-id $buildId
    if ($LASTEXITCODE -ne 0) { throw 'The packaged DeepSeek API Key or model connection test failed.' }

    Write-Stage '11 SmokeTest'
    $publishedLauncher = @(Get-ChildItem -LiteralPath $packageRoot -Filter '*.exe' -File)
    if ($publishedLauncher.Count -ne 1) { throw 'The package root did not contain exactly one launcher executable.' }
    $smoke = Start-Process -FilePath $publishedLauncher[0].FullName -ArgumentList '--smoke-test' -WorkingDirectory $packageRoot -PassThru -Wait -WindowStyle Hidden
    if ($smoke.ExitCode -ne 0) { throw "The launcher smoke test failed with exit code $($smoke.ExitCode)." }

    Write-Stage '12 VerifySourceIntegrity'
    & $venvPython (Join-Path $workspace 'tools\release\verify_source_integrity.py') --source-root $workspace --staging-manifest (Join-Path $stagingRoot 'staging_manifest.json')
    if ($LASTEXITCODE -ne 0) { throw 'Development workspace integrity changed during the build.' }

    Write-Stage '13 AtomicPublish'
    $finalRoot = [IO.Path]::GetFullPath((Join-Path $workspace ([string]$config.output_directory)))
    $distRoot = Split-Path -Parent $finalRoot
    New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
    $publishCandidate = Join-Path $distRoot ('.t1703-publishing-' + [Guid]::NewGuid().ToString('N'))
    Copy-Item -LiteralPath $packageRoot -Destination $publishCandidate -Recurse -Force
    & $venvPython (Join-Path $workspace 'tools\release\audit_demo_package.py') --package-root $publishCandidate
    if ($LASTEXITCODE -ne 0) { throw 'The copied publish candidate failed its content or secret audit.' }
    & $venvPython (Join-Path $workspace 'tools\release\verify_package_manifest.py') --package-root $publishCandidate
    if ($LASTEXITCODE -ne 0) { throw 'The copied publish candidate does not match BUILD_MANIFEST.json.' }
    $backupRoot = $null
    if (Test-Path -LiteralPath $finalRoot) {
        $backupRoot = "$finalRoot.previous.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Move-DirectoryWithRetry $finalRoot $backupRoot
    }
    try {
        Move-DirectoryWithRetry $publishCandidate $finalRoot
        $publishCandidate = $null
    }
    catch {
        if ($backupRoot -and (Test-Path -LiteralPath $backupRoot) -and -not (Test-Path -LiteralPath $finalRoot)) {
            Move-DirectoryWithRetry $backupRoot $finalRoot
        }
        throw
    }
    Write-Host "Demo package directory: $finalRoot"
}
finally {
    Write-Stage '14 Cleanup'
    foreach ($name in $secretEnvironmentNames) {
        [Environment]::SetEnvironmentVariable($name, $originalSecretEnvironment[$name], 'Process')
    }
    $demoDeepSeekKey = $null
    $voiceKey = $null
    $voiceWorkspace = $null
    $voiceBaseUrl = $null
    $developmentDeepSeekKey = $null
    if ($publishCandidate -and (Test-Path -LiteralPath $publishCandidate)) {
        $resolvedCandidate = [IO.Path]::GetFullPath($publishCandidate)
        if ($distRoot) {
            $resolvedDistRoot = [IO.Path]::GetFullPath($distRoot)
            if ((Split-Path -Parent $resolvedCandidate) -eq $resolvedDistRoot -and (Split-Path -Leaf $resolvedCandidate) -match '^\.t1703-publishing-[0-9a-f]{32}$') {
                Remove-Item -LiteralPath $resolvedCandidate -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    if ($buildRoot) {
        $resolvedBuildRoot = [IO.Path]::GetFullPath($buildRoot)
        $expectedParent = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) 'ThisIsNotMyWarDemoBuild'))
        if ((Split-Path -Parent $resolvedBuildRoot) -eq $expectedParent -and (Split-Path -Leaf $resolvedBuildRoot) -match '^[0-9a-f]{32}$') {
            Remove-Item -LiteralPath $resolvedBuildRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
