# SystemInfo.ps1 — called by Dart fallback via Process.runSync.
# Run standalone:  powershell -NoProfile -File SystemInfo.ps1
# VSCode syntax highlighting: install PowerShell extension.

$os   = Get-CimInstance Win32_OperatingSystem
$cs   = Get-CimInstance Win32_ComputerSystem
$cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$net  = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1

Write-Output "UPTIME|$($os.LastBootUpTime)"
Write-Output "CPU|$($cpu.Name) ($($cpu.NumberOfLogicalProcessors) cores)"
Write-Output "MEM|$([math]::Round($cs.TotalPhysicalMemory/1GB,1)) GiB total"
Write-Output "DISK|$([math]::Round($disk.Size/1GB,1)) GiB total $([math]::Round(($disk.Size-$disk.FreeSpace)/1GB,1)) GiB used"
Write-Output "NET|$($net.Name)"
