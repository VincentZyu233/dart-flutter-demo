Write-Host "`n" -NoNewline
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║       Apple iPad 设备检测工具           ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "`n[1/3] 🔍 正在扫描 USB 设备..." -ForegroundColor Yellow

$devices = Get-PnpDevice -PresentOnly | Where-Object { $_.FriendlyName -match "Apple" -or $_.FriendlyName -match "iPad" }

if (-not $devices) {
    Write-Host "`n❌ 未发现已连接的 iPad。请检查 USB 线或在 iPad 上点击'信任'。" -ForegroundColor Red
    Write-Host "`n💡 常见排查：" -ForegroundColor Yellow
    Write-Host "   • 换一根 USB 数据线（有些线只支持充电）" -ForegroundColor Gray
    Write-Host "   • 在 iPad 上点击「信任这台电脑」" -ForegroundColor Gray
    Write-Host "   • 重新插拔 USB 线" -ForegroundColor Gray
    Write-Host "   • 重启 Apple Mobile Device Service 服务`n" -ForegroundColor Gray
    return
}

Write-Host "`n[2/3] ✅ 找到 $($devices.Count) 个 Apple 设备" -ForegroundColor Green

Write-Host "`n" -NoNewline
Write-Host "  ┌─────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host ("  │  {0,-40} {1,-10} {2,-20} │" -f "设备名称", "状态", "类别") -ForegroundColor Cyan
Write-Host "  ├─────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor Cyan
foreach ($dev in $devices) {
    $statusColor = if ($dev.Status -eq "OK") { "Green" } else { "Red" }
    Write-Host "  │  " -NoNewline -ForegroundColor Cyan
    Write-Host ("{0,-40}" -f $dev.FriendlyName) -NoNewline -ForegroundColor White
    Write-Host ("{0,-10}" -f $dev.Status) -NoNewline -ForegroundColor $statusColor
    Write-Host ("{0,-20}" -f ($dev.Class -replace '^(.{18}).*$', '$1…')) -ForegroundColor Gray
    Write-Host "  │" -ForegroundColor Cyan
}
Write-Host "  └─────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan

Write-Host "`n[3/3] 📋 硬件摘要" -ForegroundColor Yellow
Write-Host "  ─────────────────────────────────────────────" -ForegroundColor DarkGray
foreach ($dev in $devices) {
    $icon = if ($dev.FriendlyName -match "iPad") { "📱" } elseif ($dev.FriendlyName -match "iPhone") { "📱" } else { "🔌" }
    Write-Host ("  {0}  {1}" -f $icon, $dev.FriendlyName) -ForegroundColor White
    $id = ($dev.InstanceId -split '\\' | Select-Object -Last 1)
    Write-Host ("      └ InstanceId: {0}" -f $id) -ForegroundColor DarkGray
}

Write-Host "`n✅ Apple 设备检测完成。" -ForegroundColor Green
Write-Host "💡 提示：iPad 不会自动映射为盘符。如需传输文件，建议安装：" -ForegroundColor Yellow

# 扫描 WMI 获取更多详情
Write-Host "── 通过 WMI 获取更多信息 ─────────────────" -ForegroundColor DarkGray
$wmiDevices = Get-WmiObject Win32_PnPEntity | Where-Object { $_.Description -match "Apple" -or $_.Service -match "Apple" }
foreach ($dev in $wmiDevices) {
    if ($dev.FriendlyName) {
        Write-Host "  • $($dev.FriendlyName)" -ForegroundColor White
        Write-Host "     Service: $($dev.Service)" -ForegroundColor DarkGray
    }
}
Write-Host "`n"