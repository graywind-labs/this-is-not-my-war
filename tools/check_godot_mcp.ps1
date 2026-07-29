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
$directGodotMcpProcesses = @(
    $godotMcp | Where-Object {
        $_.Name -eq "node.exe" -and
        $_.CommandLine -match "@satelliteoflove/godot-mcp|godot-mcp\\dist\\cli\\.js" -and
        $_.CommandLine -notmatch "godot-mcp-(proxy|broker)\.mjs"
    }
)
$brokerListen = Get-NetTCPConnection -LocalPort 8765 -State Listen -ErrorAction SilentlyContinue
$pluginProcess = $null
if ($listen) {
    $pluginProcess = Get-Process -Id ($listen | Select-Object -First 1).OwningProcess -ErrorAction SilentlyContinue
}

if ($conn) {
    Write-Host "Godot MCP connected" -ForegroundColor Green
    if ($pluginProcess) {
        Write-Host "Info: 127.0.0.1:6550 is the expected Godot addon listener owned by $($pluginProcess.ProcessName) (PID $($pluginProcess.Id))." -ForegroundColor Cyan
    }

    if ($brokerProcesses.Count -ne 1 -or -not $brokerListen) {
        Write-Host "Warning: expected exactly one listening broker." -ForegroundColor Yellow
        $brokerProcesses |
            Select-Object ProcessId, ParentProcessId, Name, CommandLine |
            Format-Table -AutoSize
    }

    if ($proxyProcesses.Count -gt 1) {
        Write-Host "Info: $($proxyProcesses.Count) session-local stdio proxies are alive; this is expected with multiple Codex sessions." -ForegroundColor Cyan
    }

    if ($directGodotMcpProcesses.Count -gt 0) {
        Write-Host "Warning: direct godot-mcp clients bypassing the broker are alive." -ForegroundColor Yellow
        $directGodotMcpProcesses |
            Select-Object ProcessId, ParentProcessId, Name, CommandLine |
            Format-Table -AutoSize
    }

    exit 0
}

if ($listen) {
    Write-Host "Godot plugin is running, but MCP is not connected" -ForegroundColor Yellow
    if ($pluginProcess) {
        Write-Host "Port 6550 is already correctly owned by $($pluginProcess.ProcessName) (PID $($pluginProcess.Id)); do not start a second --editor instance or kill this listener just because the port is occupied." -ForegroundColor Cyan
    }

    if ($godotMcp) {
        Write-Host "Detected godot-mcp processes:" -ForegroundColor Yellow
        $godotMcp |
            Select-Object ProcessId, ParentProcessId, Name, CommandLine |
            Format-Table -AutoSize
        Write-Host "Run tools/verify_godot_mcp_topology.mjs, then restart only the affected Codex session if its stdio transport was already closed." -ForegroundColor Yellow
    } else {
        Write-Host "Open Codex after Godot, or restart Codex once." -ForegroundColor Yellow
    }

    exit 1
}

if ($proxyProcesses -and (-not $brokerProcesses -or -not $brokerListen)) {
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
