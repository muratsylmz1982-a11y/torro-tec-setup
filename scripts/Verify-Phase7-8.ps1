<# 
 Verify-Phase7-8.ps1
 Torro Tec – Verifikation & Snapshot (robust gegen fehlende Event-Kanäle)
#>

param(
    [string]$LogsDir = "C:\Tiptorro\logs",
    [int]$AssignedAccessEvents = 10,
    [int]$PrinterEvents = 3
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null

# Helper: try event channels by pattern
function Try-EventLog([string]$pattern, [int]$max=10){
    try {
        $log = Get-WinEvent -ListLog $pattern -ErrorAction Stop | Select-Object -First 1
        if ($null -ne $log) {
            Get-WinEvent -LogName $log.LogName -MaxEvents $max |
              Select TimeCreated, Id, LevelDisplayName, Message |
              Format-Table -Auto | Out-String
        } else {
            return "[Info] Keine passenden Logs für Pattern: $pattern"
        }
    } catch {
        return "[Info] Eventlog-Pattern nicht verfügbar: $pattern"
    }
}

# 1) Assigned Access / Kiosk – Eventlog oder Hinweis
$aa = Try-EventLog -pattern "*AssignedAccess*" -max $AssignedAccessEvents
$aa | Out-File -FilePath (Join-Path $LogsDir "assigned_access_events.txt") -Encoding UTF8

# 1b) Assigned Access – Registry-Indikatoren (falls Events fehlen)
$aaKeys = @(
 "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell\AssignedAccess",
 "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AssignedAccessConfiguration",
 "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\AssignedAccess"
)
"--- AssignedAccess Registry ---" | Out-File -FilePath (Join-Path $LogsDir "assigned_access_registry.txt") -Encoding UTF8
foreach($k in $aaKeys){
  try { reg query $k /s | Out-File -Append (Join-Path $LogsDir "assigned_access_registry.txt") -Encoding UTF8 }
  catch { "[Info] Key fehlt: $k" | Out-File -Append (Join-Path $LogsDir "assigned_access_registry.txt") -Encoding UTF8 }
}

# 2) Edge Policies
reg query "HKLM\SOFTWARE\Policies\Microsoft\Edge" /s |
  Out-File -FilePath (Join-Path $LogsDir "edge_policies.txt") -Encoding UTF8
try {
  reg query "HKCU\SOFTWARE\Policies\Microsoft\Edge" /s |
    Out-File -Append -FilePath (Join-Path $LogsDir "edge_policies.txt") -Encoding UTF8
} catch {}

# 3) Monitore & LiveTV Link
Add-Type -AssemblyName System.Windows.Forms | Out-Null
$screens = [System.Windows.Forms.Screen]::AllScreens
"DetectedScreens=$($screens.Count)" | Out-File (Join-Path $LogsDir "monitors.txt")
$screens | ForEach-Object { "$($_.DeviceName) $($_.Bounds.Width)x$($_.Bounds.Height) Scaling?N/A" } |
  Out-File -Append (Join-Path $LogsDir "monitors.txt")
"livetv.lnk Exists: $(Test-Path 'C:\Tiptorro\livetv.lnk')" |
  Out-File -Append (Join-Path $LogsDir "monitors.txt")

# 4) Druckernachweise
Get-Printer | Format-Table Name, DriverName, PortName, Default -Auto |
  Out-String | Out-File (Join-Path $LogsDir "printers.txt") -Encoding UTF8

Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PrintService/Operational'; Id=307} -MaxEvents $PrinterEvents |
  Select TimeCreated, Message |
  Format-Table -Auto | Out-String | Out-File (Join-Path $LogsDir "print_307_events.txt") -Encoding UTF8

# 5) Forms
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Print\Forms" /s |
  Out-File -FilePath (Join-Path $LogsDir "custom_forms.txt") -Encoding UTF8

# 6) Snapshot
$ts = Get-Date -Format yyyyMMdd_HHmmss
$zip = Join-Path $LogsDir "phase7_8_snapshot_$ts.zip"
Compress-Archive -Path (Join-Path $LogsDir "*") -DestinationPath $zip -Force
Write-Host "Snapshot erstellt: $zip"
