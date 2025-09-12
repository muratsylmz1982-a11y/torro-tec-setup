<# 
 .SYNOPSIS
   Torro Tec HealthCheck – liest Zustände aus und schreibt ein Log (keine Änderungen am System).

 .USAGE
   powershell -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\HealthCheck.ps1"
   # optional: -OutFile "C:\Tiptorro\logs\healthcheck_custom.log" -Verbose

 .NOTES
   Schreibt nach C:\Tiptorro\logs\healthcheck_yyyyMMdd_HHmmss.log (Default)
#>

[CmdletBinding()]
param(
  [string]$OutFile
)

$ErrorActionPreference = 'SilentlyContinue'
$root = 'C:\Tiptorro'
$logDir = Join-Path $root 'logs'
if(!(Test-Path $logDir)){ New-Item -ItemType Directory -Path $logDir | Out-Null }
if([string]::IsNullOrWhiteSpace($OutFile)){
  $OutFile = Join-Path $logDir ("healthcheck_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
}

$script:Ok=0; $script:Warn=0; $script:Err=0

function W($m){ $script:Warn++;  "{0} WARN  {1}" -f (Get-Date -Format o), $m | Tee-Object -File $OutFile -Append | Out-Null }
function E($m){ $script:Err++;   "{0} ERROR {1}" -f (Get-Date -Format o), $m | Tee-Object -File $OutFile -Append | Out-Null }
function I($m){ $script:Ok++;    "{0} INFO  {1}" -f (Get-Date -Format o), $m | Tee-Object -File $OutFile -Append | Out-Null }

I "Start HealthCheck"

# --- Systembasis
try{
  $os = Get-CimInstance Win32_OperatingSystem
  $cs = Get-CimInstance Win32_ComputerSystem
  I "Host: $($cs.Name) / $($os.Caption) $($os.Version) Build $([Environment]::OSVersion.Version.Build)"
}catch{ W "OS/Host Info nicht lesbar: $($_.Exception.Message)" }

# --- Rollen-/Pfadindikatoren
try{
  $roleHints = @()
  if(Test-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Torro Shop Kiosk.lnk"){ $roleHints += 'Terminal:AutostartShop' }
  if(Test-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Torro LiveTV Kiosk.lnk"){ $roleHints += 'Terminal:AutostartLiveTV' }
  if(Test-Path "$root\livetv.lnk"){ $roleHints += 'LiveTV:ManualShortcut' }
  I ("Rollen-Hinweise: {0}" -f ($(if($roleHints){$roleHints -join ', '}else{'(keine)'})))
}catch{ W "Rollen-Hinweise nicht ermittelt: $($_.Exception.Message)" }

# --- Dienste (Device Manager, Spooler)
foreach($svcName in @('DeviceManager.Bootstrapper','Spooler')){
  try{
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if(!$svc){ W "Dienst fehlt: $svcName"; continue }
    if($svc.Status -ne 'Running'){ W "Dienst nicht laufend: $svcName (Status=$($svc.Status))" } else { I "Dienst läuft: $svcName" }
  }catch{ W "Dienst-Check fehlgeschlagen: $svcName – $($_.Exception.Message)" }
}

# --- Drucker
try{
  $printers = Get-Printer -ErrorAction SilentlyContinue
  if($printers){
    foreach($p in $printers){ I ("Printer: {0} / {1}{2}" -f $p.Name, $p.DriverName, $(if($p.Default){' (Default)'})) }
    try{
  $supported = @('Star TSP1*','HWASUNG*','EPSON TM-T88V*','EPSON TM-T88IV*')
  $printers = Get-Printer -ErrorAction SilentlyContinue
  $hits = @()
  foreach($p in $printers){
    foreach($pat in $supported){
      if($p.Name -like $pat -or $p.DriverName -like $pat){ $hits += $p; break }
    }
  }
  $cnt = ($hits | Measure-Object).Count
  if($cnt -eq 1){
    I ("Drucker-Check: 1 unterstütztes Gerät installiert -> {0} / {1}" -f $hits[0].Name, $hits[0].DriverName)
  } elseif($cnt -eq 0){
    W 'Drucker-Check: Kein unterstütztes Gerät installiert'
  } else {
    W ("Drucker-Check: Mehrere unterstützte Geräte installiert -> {0}" -f (($hits | Select-Object -Expand Name) -join ', '))
  }
}catch{ W ("Drucker-Check fehlgeschlagen: {0}" -f $_.Exception.Message) }
  }else{
    W "Keine Drucker gefunden"
  }
}catch{ W "Druckerabfrage fehlgeschlagen: $($_.Exception.Message)" }

# --- Edge Policies
try{
  if(Test-Path 'HKLM:SOFTWARE\Policies\Microsoft\Edge'){ I 'Edge Policies: vorhanden (HKLM)' } else { W 'Edge Policies: fehlen (HKLM)' }
}catch{ W "Edge-Policies nicht prüfbar: $($_.Exception.Message)" }

# --- Profile/Ordner (Pfad-Fix für Phase 8)
foreach($path in @("$root\scripts\Start-LiveTV.ps1",
                   "$root\scripts\Start-ShopKiosk.ps1",
                   "$root\scripts\Start-Maintenance.ps1",
                   "$root\scripts\OneClick-Phase8.ps1",
                   "$root\state\livetv.selected.json",
                   "C:\ttedge")){
  if(Test-Path $path){ I "OK: $path" } else { W "FEHLT: $path" }
}

# --- Autostart & Shortcuts
foreach($lnk in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Torro Shop Kiosk.lnk",
                  "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Torro LiveTV Kiosk.lnk",
                  "$env:PUBLIC\Desktop\LiveTV (Monitor 2).lnk",
                  "$root\livetv.lnk",
                  "$env:PUBLIC\Desktop\Torro Maintenance.lnk")){
  if(Test-Path $lnk){ I "Shortcut vorhanden: $lnk" } else { W "Shortcut fehlt: $lnk" }
}

# --- Monitore
try{
  Add-Type -AssemblyName System.Windows.Forms
  [System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
    $b = $_.Bounds
    I ("Screen: {0} Primary={1} Bounds={2}x{3}+{4}+{5}" -f $_.DeviceName, $_.Primary, $b.Width, $b.Height, $b.X, $b.Y)
  }
}catch{ W "Monitorinfo nicht lesbar: $($_.Exception.Message)" }

# --- COM/Seriell (Geldgeräte)
try{
  $ports = Get-CimInstance Win32_SerialPort -ErrorAction SilentlyContinue
  if($ports){ $ports | ForEach-Object { I ("COM: {0} {1}" -f $_.DeviceID, $_.Name) } } else { W "Keine seriellen Geräte gefunden" }
}catch{ W "COM-Ports nicht lesbar: $($_.Exception.Message)" }

# --- Netzwerk / DNS
try{
  $dns = Resolve-DnsName -Name 'shop.tiptorro.com' -ErrorAction SilentlyContinue
  if($dns){ I "DNS shop.tiptorro.com -> $($dns | Select-Object -ExpandProperty IPAddress -ErrorAction SilentlyContinue -First 1)" } else { W "DNS-Auflösung shop.tiptorro.com fehlgeschlagen" }
  $tnc = Test-NetConnection -ComputerName 'shop.tiptorro.com' -Port 443 -WarningAction SilentlyContinue
  if($tnc.TcpTestSucceeded){ I "HTTPS erreichbar: shop.tiptorro.com:443" } else { W "HTTPS NICHT erreichbar: shop.tiptorro.com:443" }
}catch{ W "Netzwerktest fehlgeschlagen: $($_.Exception.Message)" }

# --- Datenträger
try{
  $c = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
  if($c){
    $freeGB = [math]::Round($c.FreeSpace/1GB,2)
    $sizeGB = [math]::Round($c.Size/1GB,2)
    $msg = "C: frei $freeGB GB / $sizeGB GB"
    if($freeGB -lt 5){ W $msg } else { I $msg }
  }
}catch{ W "Datenträgerinfo nicht lesbar: $($_.Exception.Message)" }

# --- Eventlog (Druck 307, letzte 20)
try{
  $e = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PrintService/Operational'; Id=307} -MaxEvents 20 -ErrorAction SilentlyContinue
  if($e){ I "PrintService/Operational – 307-Ereignisse: $($e.Count) (letzte 20 protokolliert)" } else { W "Keine 307-Events gefunden (oder Log deaktiviert)" }
}catch{ W "Eventlog 307 nicht lesbar: $($_.Exception.Message)" }

# --- Schreibtest ins Logverzeichnis
try{
  $tmp = Join-Path $logDir ('_writetest_{0}.tmp' -f ([guid]::NewGuid().ToString('N')))
  'ok' | Out-File -FilePath $tmp -Encoding ascii -Force
  Remove-Item $tmp -Force
  I "WriteCheck: OK ($logDir)"
}catch{ E "WriteCheck: FEHLER ($logDir) – $($_.Exception.Message)" }

I ("Summary: OK={0} WARN={1} ERROR={2}" -f $script:Ok, $script:Warn, $script:Err)
I "Ende HealthCheck"

# Non-zero ExitCode bei Fehlern
if($script:Err -gt 0){ exit 2 } elseif($script:Warn -gt 0){ exit 1 } else { exit 0 }
