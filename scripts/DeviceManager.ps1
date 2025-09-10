<#
Torro Tec – Device Manager Controller (v1.3)
-------------------------------------------
Zweck:
- Erstinstallation: Wenn nicht installiert → MSI installieren → **Dienst starten** (ServiceController + Fallback **net start devicemanager**) → Health-Check (≤120 s)
- Reinstall (optional): Deinstallieren → Ordner löschen → Neustart (optional) → Neuinstallieren → **Dienst starten** → Health-Check
- Manuelle Steuerung: Start/Stop/Status/HealthCheck/Uninstall/Install

Aufrufbeispiele (als Admin-PowerShell):
  powershell -ExecutionPolicy Bypass -File C:\Tiptorro\scripts\DeviceManager.ps1 -Action FirstRun
  powershell -ExecutionPolicy Bypass -File C:\Tiptorro\scripts\DeviceManager.ps1 -Action Reinstall
  powershell -ExecutionPolicy Bypass -File C:\Tiptorro\scripts\DeviceManager.ps1 -Action Status

Parameter:
  -Action              FirstRun|Install|Reinstall|Uninstall|Start|Stop|Status|HealthCheck
  -MsiPath             Optional; wenn leer → automatisch aus C:\Tiptorro\packages\device-manager\*.msi gewählt
  -DisplayNameLike     Muster zum Finden einer bestehenden Installation (Default: *Device*Manager*)
  -AppFolder           Installationsordner zum Bereinigen (Default: C:\Program Files (x86)\TipTorro)
  -ServiceName         Erwarteter Dienstname (Default: DeviceManager.Bootstrapper)
  -LegacyServiceName   **Name für net start/stop** (Default: DeviceManager)
  -HealthTimeoutSec    Timeout für Health-Check (Default: 120)
#>

[CmdletBinding()]
param(
  [ValidateSet("FirstRun","Install","Reinstall","Uninstall","Start","Stop","Status","HealthCheck")]
  [string]$Action = "FirstRun",
  [string]$MsiPath,
  [string]$DisplayNameLike = '*Device*Manager*',
  [string]$AppFolder = 'C:\\Program Files (x86)\\TipTorro',
  [string]$ServiceName = 'DeviceManager.Bootstrapper',
  [string]$LegacyServiceName = 'DeviceManager',
  [int]$HealthTimeoutSec = 120
)

$ErrorActionPreference = 'Continue'
$Root = 'C:\\Tiptorro'
$LogDir = Join-Path $Root 'logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Log = Join-Path $LogDir ("devicemanager_" + $Action + '_' + (Get-Date -Format yyyyMMdd_HHmmss) + '.log')

function Log([string]$m){ "$([DateTime]::Now.ToString('o')) $m" | Tee-Object -FilePath $Log -Append | Out-Null }

function Find-UninstallEntries {
  $roots = @(
    'HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\*',
    'HKLM:\\Software\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\*'
  )
  foreach($r in $roots){ Get-ItemProperty $r -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $DisplayNameLike } }
}

function Uninstall-ByEntry($e){
  if($e -and $e.PSChildName -match '^{[0-9A-F-]+}$'){
    Log ("Uninstall via ProductCode " + $e.PSChildName)
    Start-Process msiexec.exe -ArgumentList ("/x " + $e.PSChildName + " /qn /norestart") -Wait
  } elseif($e -and $e.UninstallString){
    $cmd = $e.UninstallString -replace 'msiexec\.exe','msiexec.exe'
    if($cmd -notmatch '/qn'){ $cmd += ' /qn' }
    if($cmd -notmatch '/norestart'){ $cmd += ' /norestart' }
    Log ("Uninstall via UninstallString: " + $cmd)
    Start-Process cmd.exe -ArgumentList ("/c " + $cmd) -Wait
  } else { Log "WARN: No uninstall info found for entry." }
}

function Get-MsiCandidate {
  if($MsiPath -and (Test-Path $MsiPath)){ return (Resolve-Path $MsiPath).Path }
  $pkg = Join-Path $Root 'packages/device-manager'
  if(-not (Test-Path $pkg)){ return $null }
  $msis = Get-ChildItem $pkg -Filter '*.msi' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
  if($msis.Count -ge 1){ return $msis[0].FullName }
  return $null
}

function Install-DM {
  $msi = Get-MsiCandidate
  if(-not $msi){ Log ("ERROR: No MSI found in " + (Join-Path $Root 'packages\\device-manager')); throw "MSI missing" }
  Log ("Installing MSI: " + $msi)
  Start-Process msiexec.exe -ArgumentList ("/i `"" + $msi + "`" /qn /norestart") -Wait
}

function Invoke-LegacyNet([string]$Do,[string]$Name){
  $cmd = "net $Do $Name"
  Log ("Legacy: " + $cmd)
  $p = Start-Process cmd.exe -ArgumentList ("/c " + $cmd) -Wait -PassThru -NoNewWindow
  Log ("Legacy exit code: " + $p.ExitCode)
  return $p.ExitCode
}

function Ensure-Service([string]$name){
  $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
  if($svc){
    try{ Set-Service -Name $name -StartupType Automatic -ErrorAction SilentlyContinue } catch {}
    if($svc.Status -ne 'Running'){
      try{ Start-Service -Name $name -ErrorAction SilentlyContinue } catch {}
      $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    }
    if($svc -and $svc.Status -eq 'Running'){
      Log ("Service ensured: " + $name + " (Automatic + Running)")
      return $true
    }
  }
  Log ("WARN: Service " + $name + " not running or not found → trying legacy net start '")
  $code = Invoke-LegacyNet -Do 'start' -Name $LegacyServiceName
  if($code -eq 0){ Log ("Legacy start OK for " + $LegacyServiceName); return $true }
  Log ("Legacy start failed (code=" + $code + ") for " + $LegacyServiceName)
  return $false
}

function Test-HealthCheck {
  $deadline = (Get-Date).AddSeconds($HealthTimeoutSec)
  while((Get-Date) -lt $deadline){ if(Ensure-Service -name $ServiceName){ return $true }; Start-Sleep 3 }
  Log ("Health-Check: TIMEOUT after " + $HealthTimeoutSec + " s")
  return $false
}

function Remove-AppFolder {
  if(Test-Path $AppFolder){
    Log ("Removing folder " + $AppFolder)
    try{ Remove-Item -Path $AppFolder -Recurse -Force } catch { Log ("WARN: " + $_.Exception.Message) }
  } else { Log ("App folder not present (" + $AppFolder + ")") }
}

# -----------------
# Execution
# -----------------
Log ("=== Device Manager " + $Action + " START ===")

switch($Action){
  "FirstRun" {
    $existing = @(Find-UninstallEntries)
    if($existing.Count -gt 0){
      Log "Device Manager already installed → skipping automatic install (manual control available)."
      [void](Test-HealthCheck)
    } else {
      Install-DM
      # **WICHTIG**: nach Installation sofort starten (inkl. legacy net start)
      [void](Ensure-Service -name $ServiceName)
      if(Test-HealthCheck){ Log "Health-Check: OK" } else { Log "Health-Check: FAILED" }
    }
  }
  "Install" {
    Install-DM
    [void](Ensure-Service -name $ServiceName)
    if(Test-HealthCheck){ Log "Health-Check: OK" } else { Log "Health-Check: FAILED" }
  }
  "Reinstall" {
    Write-Host "Reinstall führt Deinstall + Ordner löschen durch. Neustart wird empfohlen." -ForegroundColor Yellow
    $ans = Read-Host 'Fortfahren? (y/N)'
    if($ans -match '^(y|j)$'){
      $entries = @(Find-UninstallEntries)
      if($entries.Count -gt 0){ foreach($e in $entries){ Uninstall-ByEntry $e } } else { Log 'No existing install found.' }
      Remove-AppFolder
      $ans2 = Read-Host 'Jetzt Neustart durchführen? (y/N)'
      if($ans2 -match '^(y|j)$'){
        Log 'User opted to reboot now.'
        Restart-Computer -Force
        break
      } else { Log 'Continue without reboot.' }
      Install-DM
      [void](Ensure-Service -name $ServiceName)
      if(Test-HealthCheck){ Log "Health-Check: OK" } else { Log "Health-Check: FAILED" }
    } else { Log 'Reinstall aborted by user.' }
  }
  "Uninstall" {
    $entries = @(Find-UninstallEntries)
    if($entries.Count -gt 0){ foreach($e in $entries){ Uninstall-ByEntry $e } } else { Log 'No existing install found.' }
    $del = Read-Host ("Installationsordner " + $AppFolder + " löschen? (y/N)")
    if($del -match '^(y|j)$'){ Remove-AppFolder }
  }
  "Start"   {
    if(Ensure-Service -name $ServiceName){ Log 'Start OK' } else { Log 'Start failed, trying legacy'; [void](Invoke-LegacyNet -Do 'start' -Name $LegacyServiceName) }
  }
  "Stop"    {
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    $stopped = $false
    if($svc){ try{ Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue; $stopped = $true; Log 'Stopped.' } catch { Log ("ERROR stopping: " + $_.Exception.Message) } }
    if(-not $stopped){ [void](Invoke-LegacyNet -Do 'stop' -Name $LegacyServiceName) }
  }
  "Status"  {
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if($svc){ Log ("Service " + $ServiceName + " status: " + $svc.Status) } else { Log ("Service " + $ServiceName + " not found") }
    $entries = @(Find-UninstallEntries)
    Log ("Installed entries: " + $entries.Count)
    $msi = Get-MsiCandidate
    if($msi){ Log ("MSI candidate: " + $msi) } else { Log "MSI candidate: NONE" }
  }
  "HealthCheck" { if(Test-HealthCheck){ Log "Health-Check: OK" } else { Log "Health-Check: FAILED" } }
}

Log ("=== Device Manager " + $Action + " END ===")

