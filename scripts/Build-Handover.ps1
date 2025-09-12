[CmdletBinding()]
param(
  [string]$SiteName = '(Standort eintragen)',
  [ValidateSet('Terminal','Kasse','Unbekannt')] [string]$Zielrolle = 'Unbekannt',
  [string]$LinksJson = 'C:\Tiptorro\links.json',
  [switch]$IncludePackages
)

$ErrorActionPreference='Stop'
$root='C:\Tiptorro'
$hostName = (Get-CimInstance Win32_ComputerSystem).Name
$ts = Get-Date -Format 'yyyyMMdd_HHmm'
$base = Join-Path $root "handover\$hostName`_$ts"
$exp  = Join-Path $base 'exports'
$logd = Join-Path $root 'logs'
New-Item -ItemType Directory -Force $base,$exp | Out-Null

# 1) Logs & State
Get-ChildItem $logd -File -Filter 'healthcheck_*.log' | Sort LastWriteTime -desc | Select -First 5 | Copy-Item -Destination $base -Force -ErrorAction SilentlyContinue
Get-ChildItem $logd -File -Filter 'audit_signatures_*.csv' | Sort LastWriteTime -desc | Select -First 3 | Copy-Item -Destination $base -Force -ErrorAction SilentlyContinue
Get-ChildItem $logd -File -Filter 'audit_signatures_*.log' | Sort LastWriteTime -desc | Select -First 3 | Copy-Item -Destination $base -Force -ErrorAction SilentlyContinue
@('state\livetv.selected.json','state\hashes.csv') | ForEach-Object {
  $p = Join-Path $root $_; if(Test-Path $p){ Copy-Item $p $base -Force }
}

# 2) Exporte (Fakten)
# 2a OS/Host
Get-CimInstance Win32_OperatingSystem | Select Caption,Version,BuildNumber,OSArchitecture |
  Export-Csv (Join-Path $exp 'os.csv') -NoTypeInformation -Encoding UTF8
Get-CimInstance Win32_ComputerSystem | Select Name,Manufacturer,Model,Domain |
  Export-Csv (Join-Path $exp 'host.csv') -NoTypeInformation -Encoding UTF8

# 2b Monitore
try{
  Add-Type -AssemblyName System.Windows.Forms
  $rows = [System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
    $b=$_.Bounds; [pscustomobject]@{ DeviceName=$_.DeviceName; Primary=$_.Primary; Width=$b.Width; Height=$b.Height; X=$b.X; Y=$b.Y }
  }
  $rows | Export-Csv (Join-Path $exp 'monitors.csv') -NoTypeInformation -Encoding UTF8
}catch{}

# 2c Dienste & Drucker
Get-Service Spooler,DeviceManager.Bootstrapper -ErrorAction SilentlyContinue |
  Select Name,Status,StartType | Export-Csv (Join-Path $exp 'services.csv') -NoTypeInformation -Encoding UTF8
Get-Printer -ErrorAction SilentlyContinue |
  Select Name,DriverName,PortName,Shared,Default | Export-Csv (Join-Path $exp 'printers.csv') -NoTypeInformation -Encoding UTF8

# 2d Edge Policies (REG Export)
try{
  $regOut = Join-Path $exp 'edge-policies.reg'
  reg.exe export "HKLM\SOFTWARE\Policies\Microsoft\Edge" "$regOut" /y | Out-Null
}catch{}

# 2e Autostart/Shortcuts
$startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
Get-ChildItem $startup -Filter 'Torro *.lnk' -ErrorAction SilentlyContinue |
  Select Name,FullName | Export-Csv (Join-Path $exp 'startup_shortcuts.csv') -NoTypeInformation -Encoding UTF8
@("$env:PUBLIC\Desktop\LiveTV (Monitor 2).lnk",
  "$root\livetv.lnk",
  "$env:PUBLIC\Desktop\Torro Maintenance.lnk") |
  ForEach-Object { [pscustomobject]@{ Path=$_; Exists=(Test-Path $_) } } |
  Export-Csv (Join-Path $exp 'desktop_shortcuts.csv') -NoTypeInformation -Encoding UTF8

# 2f Netzwerk Smoke
$net = Test-NetConnection -ComputerName 'shop.tiptorro.com' -Port 443 -WarningAction SilentlyContinue
[pscustomobject]@{
  ComputerName = $net.ComputerName; RemotePort = $net.RemotePort; TcpTestSucceeded = $net.TcpTestSucceeded
} | Export-Csv (Join-Path $exp 'net.csv') -NoTypeInformation -Encoding UTF8

# 3) Doku kopieren
@('README.md','CHANGELOG.md') | ForEach-Object {
  $s = Join-Path $root $_; if(Test-Path $s){ Copy-Item $s $base -Force }
}
$play = Join-Path $root 'docs\ops-playbook.md'; if(Test-Path $play){ Copy-Item $play $base -Force }

# 4) Handover.md erzeugen
$health = Get-ChildItem $base -Filter 'healthcheck_*.log' | Sort LastWriteTime -desc | Select -First 1
$hcSummary = '(kein HealthCheck gefunden)'
if($health){
  $tail = Get-Content $health.FullName -Tail 20
  $sum  = $tail | Where-Object { $_ -match 'Summary: OK=' } | Select -First 1
  $hcSummary = $sum ? $sum.Trim() : ($tail -join "`n")
}
$handover = @"
# Torro Tec – Handover

**Standort:** $SiteName  
**Host:** $hostName  
**Rolle (Ziel):** $Zielrolle

## System
$(Get-Content (Join-Path $exp 'os.csv') -Raw 2>$null)

## Monitore
(siehe exports\monitors.csv)

## Autostart & Shortcuts
- Startup: exports\startup_shortcuts.csv
- Desktop: exports\desktop_shortcuts.csv

## Drucker
(siehe exports\printers.csv)

## Edge-Policies
exports\edge-policies.reg

## Netzwerk
$(Get-Content (Join-Path $exp 'net.csv') -Raw 2>$null)

## LiveTV/Links
- links.json: $LinksJson (falls genutzt)
- Auswahl: state\livetv.selected.json (kopiert, falls vorhanden)

## HealthCheck (Kurz)
$hcSummary

## Security-Audit
- CSV/LOG: audit_signatures_*.csv|.log
- Hash-Baseline: state\hashes.csv (falls vorhanden)

## TODO (auszufüllen)
- Standort-spezifische LiveTV-Links verifizieren
- Abweichende Drucker/INF-Pfade dokumentieren
- Besondere Policies/MDM-Vorgaben ergänzen
"@
$handover | Set-Content (Join-Path $base 'Handover.md') -Encoding UTF8

# 5) Optional: packages aufnehmen (groß!)
if($IncludePackages){
  $pkg = Join-Path $root 'packages'
  if(Test-Path $pkg){ Copy-Item $pkg (Join-Path $base 'packages') -Recurse -Force -ErrorAction SilentlyContinue }
}

# 6) ZIP
$zip = "$base.zip"
if(Test-Path $zip){ Remove-Item $zip -Force }
Compress-Archive -Path $base -DestinationPath $zip
Write-Host "Handover bereit: $zip"
