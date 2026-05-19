$port = 6550

$listen = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
$conn = Get-NetTCPConnection -RemotePort $port -State Established -ErrorAction SilentlyContinue

if ($conn) {
    Write-Host "✅ Godot MCP 已连接" -ForegroundColor Green
    exit 0
}

if ($listen) {
    Write-Host "🟡 Godot 插件已启动，但 MCP 还没连上" -ForegroundColor Yellow
    Write-Host "处理：关闭多余 Codex 会话，只保留一个；必要时重开 Codex。" -ForegroundColor Yellow
    exit 1
}

Write-Host "❌ Godot MCP 插件没启动" -ForegroundColor Red
Write-Host "处理：先打开 Godot 项目，并确认插件启用。" -ForegroundColor Red
exit 2