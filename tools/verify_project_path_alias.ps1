param(
    [string]$CanonicalPath = '',
    [string]$AliasPath = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($CanonicalPath)) {
    $CanonicalPath = Split-Path -Parent $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($AliasPath)) {
    $driveRoot = Split-Path -Qualifier $CanonicalPath
    $projectLeaf = Split-Path -Leaf $CanonicalPath
    $AliasPath = Join-Path -Path (Join-Path -Path $driveRoot -ChildPath 'MyGames') -ChildPath $projectLeaf
}

function Resolve-NormalizedPath([string]$Path) {
    return (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\', '/').ToLowerInvariant()
}

function Assert-Equal([string]$Label, [string]$Actual, [string]$Expected) {
    if ($Actual -cne $Expected) {
        throw "$Label mismatch: actual='$Actual' expected='$Expected'"
    }
}

$canonicalItem = Get-Item -LiteralPath $CanonicalPath
$aliasItem = Get-Item -LiteralPath $AliasPath
if ($aliasItem.LinkType -ne 'Junction') {
    throw "Alias is not an NTFS Junction: $AliasPath (LinkType=$($aliasItem.LinkType))"
}
if ($aliasItem.Target.Count -ne 1) {
    throw "Alias must have exactly one Junction target: $AliasPath"
}

$rawTarget = [string]$aliasItem.Target[0]
if (-not [System.IO.Path]::IsPathRooted($rawTarget)) {
    $rawTarget = Join-Path -Path $aliasItem.Parent.FullName -ChildPath $rawTarget
}
$canonicalResolved = Resolve-NormalizedPath $canonicalItem.FullName
$targetResolved = Resolve-NormalizedPath $rawTarget
Assert-Equal 'Junction target' $targetResolved $canonicalResolved

$canonicalGitRoot = (& git -C $canonicalItem.FullName rev-parse --show-toplevel).Trim().Replace('\', '/').ToLowerInvariant()
$aliasGitRoot = (& git -C $aliasItem.FullName rev-parse --show-toplevel).Trim().Replace('\', '/').ToLowerInvariant()
Assert-Equal 'Git root' $aliasGitRoot $canonicalGitRoot

$canonicalHead = (& git -C $canonicalItem.FullName rev-parse HEAD).Trim()
$aliasHead = (& git -C $aliasItem.FullName rev-parse HEAD).Trim()
Assert-Equal 'Git HEAD' $aliasHead $canonicalHead

$criticalFiles = @('project.godot', 'AGENTS.md')
$hashes = @{}
foreach ($relativePath in $criticalFiles) {
    $canonicalHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $canonicalItem.FullName $relativePath)).Hash
    $aliasHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $aliasItem.FullName $relativePath)).Hash
    Assert-Equal "$relativePath SHA256" $aliasHash $canonicalHash
    $hashes[$relativePath] = $canonicalHash
}

[ordered]@{
    ok = $true
    canonical_path = $canonicalItem.FullName
    alias_path = $aliasItem.FullName
    alias_link_type = $aliasItem.LinkType
    alias_target = $aliasItem.Target[0]
    git_root = $canonicalGitRoot
    git_head = $canonicalHead
    critical_file_hashes = $hashes
} | ConvertTo-Json -Depth 4
