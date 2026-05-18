# SystemInfo.ps1 — called by Dart fallback via Process.runSync.
# Run standalone:  powershell -NoProfile -File SystemInfo.ps1
# VSCode syntax highlighting: install PowerShell extension.

$os   = Get-CimInstance Win32_OperatingSystem
$cs   = Get-CimInstance Win32_ComputerSystem
$cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

$preferred = Get-NetIPConfiguration | Where-Object {
  $_.IPv4Address -and
  $_.NetAdapter.Status -eq 'Up' -and
  $_.IPv4Address.IPAddress -notlike '127.*' -and
  $_.IPv4Address.IPAddress -notlike '169.254.*' -and
  $_.InterfaceAlias -notmatch 'Radmin|VPN|VMware|vEthernet|Hyper-V|WSL|Virtual|Todesk|Parsec|GameViewer'
} | Sort-Object {
  if ($_.IPv4DefaultGateway) { 0 } else { 1 }
} | Select-Object -First 1

if (-not $preferred) {
  $preferred = Get-NetIPConfiguration | Where-Object {
    $_.IPv4Address -and
    $_.NetAdapter.Status -eq 'Up' -and
    $_.IPv4Address.IPAddress -notlike '127.*' -and
    $_.IPv4Address.IPAddress -notlike '169.254.*'
  } | Select-Object -First 1
}

Write-Output "UPTIME|$($os.LastBootUpTime)"
Write-Output "CPU|$($cpu.Name) ($($cpu.NumberOfLogicalProcessors) cores)"
Write-Output "MEM|$([math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1024) / 1024, 1)) GiB / $([math]::Round(($os.TotalVisibleMemorySize / 1024) / 1024, 1)) GiB"
Write-Output "DISK|$([math]::Round($disk.Size/1GB,1)) GiB total $([math]::Round(($disk.Size-$disk.FreeSpace)/1GB,1)) GiB used"
Write-Output "NET|$($preferred.IPv4Address.IPAddress)"
