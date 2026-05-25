$port = 6550

$listen = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
$conn = Get-NetTCPConnection -RemotePort $port -State Established -ErrorAction SilentlyContinue
$godotMcp = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
        ($_.Name -in @("node.exe", "cmd.exe", "powershell.exe", "pwsh.exe")) -and
        $_.CommandLine -and
        $_.CommandLine -match "@satelliteoflove/godot-mcp|godot-mcp\\dist\\cli\\.js|\bgodot-mcp\b"
    }
$proxyProcesses = @(
    $godotMcp | Where-Object {
        $_.Name -eq "node.exe" -and
        $_.CommandLine -match "godot-mcp-proxy\.mjs"
    }
)
$brokerProcesses = @(
    $godotMcp | Where-Object {
        $_.Name -eq "node.exe" -and
        $_.CommandLine -match "godot-mcp-broker\.mjs"
    }
)
$godotMcpNodeCount = @(
    $godotMcp | Where-Object {
        $_.Name -eq "node.exe" -and
        $_.CommandLine -match "@satelliteoflove/godot-mcp|godot-mcp\\dist\\cli\\.js"
    }
).Count

if ($conn) {
    Write-Host "Godot MCP connected" -ForegroundColor Green

    if ($godotMcpNodeCount -gt 2) {
        Write-Host "Warning: multiple godot-mcp helper processes are still alive." -ForegroundColor Yellow
        $godotMcp |
            Select-Object ProcessId, ParentProcessId, Name, CommandLine |
            Format-Table -AutoSize
    }

    if ($proxyProcesses.Count -gt 1) {
        Write-Host "Warning: multiple proxy processes are alive; they should self-clean after restart." -ForegroundColor Yellow
        $proxyProcesses |
            Select-Object ProcessId, ParentProcessId, Name, CommandLine |
            Format-Table -AutoSize
    }

    exit 0
}

if ($listen) {
    Write-Host "Godot plugin is running, but MCP is not connected" -ForegroundColor Yellow

    if ($godotMcp) {
        Write-Host "Detected godot-mcp processes:" -ForegroundColor Yellow
        $godotMcp |
            Select-Object ProcessId, ParentProcessId, Name, CommandLine |
            Format-Table -AutoSize
        Write-Host "Try restarting Codex once after closing duplicate sessions." -ForegroundColor Yellow
    } else {
        Write-Host "Open Codex after Godot, or restart Codex once." -ForegroundColor Yellow
    }

    exit 1
}

if ($proxyProcesses -and -not $brokerProcesses) {
    Write-Host "Proxy is alive, but broker is missing" -ForegroundColor Yellow
    Write-Host "Restart Codex once to let the proxy recreate the broker." -ForegroundColor Yellow
    $proxyProcesses |
        Select-Object ProcessId, ParentProcessId, Name, CommandLine |
        Format-Table -AutoSize
    exit 1
}

Write-Host "Godot MCP plugin is not running" -ForegroundColor Red
Write-Host "Open the Godot project and make sure the Godot MCP plugin is enabled." -ForegroundColor Red
exit 2
