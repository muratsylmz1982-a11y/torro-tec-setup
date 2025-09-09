param(
  [string]$Installer = "C:\Tiptorro\packages\teamviewer\TeamViewer_Setup.exe",
  [string]$PolicyReg = "C:\Tiptorro\policies\teamviewer-standard.reg" # optionaler, privater Reg-Export (nicht ins Repo!)
)

$ErrorActionPreference = 'Continue'
$logDir = "C:\Tiptorro\logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$log = Join-Path $logDir ("teamviewer_setup_" + (Get-Date -Format yyyyMMdd_HHmmss) + ".log")

function Log($m){ "$((Get-Date).ToString('o')) $m" | Tee-Object -FilePath $log -Append }

function Get-TVServiceName {
  $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*TeamViewer*" }
  if ($svc) { return $svc.Name } else { return "TeamViewer" }
}

function Get-TVClientID {
  $paths = @("HKLM:\SOFTWARE\WOW6432Node\TeamViewer","HKLM:\SOFTWARE\TeamViewer")
  foreach($p in $paths){
    try{
      if(Test-Path $p){
        $props = Get-ItemProperty -Path $p -ErrorAction Stop
        if($props.PSObject.Properties.Name -contains 'ClientID' -and $props.ClientID){ return $props.ClientID }
        if($props.PSObject.Properties.Name -contains 'ClientID64' -and $props.ClientID64){ return $props.ClientID64 }
      }
    } catch {}
  }
  return $null
}

Log "=== TeamViewer Setup START ==="

# 1) Installieren, wenn nicht vorhanden
$installed = (Get-Item "C:\Program Files\TeamViewer\TeamViewer.exe" -ErrorAction SilentlyContinue) -or
             (Get-Item "C:\Program Files (x86)\TeamViewer\TeamViewer.exe" -ErrorAction SilentlyContinue)

if(-not $installed){
  if(Test-Path $Installer){
    Log "Installing TeamViewer from $Installer (silent)"
    Start-Process $Installer -ArgumentList "/S" -Wait
  } else {
    Log "WARN: Installer not found at $Installer"
  }
} else {
  Log "TeamViewer already installed"
}

# 2) Optional: Policies/Reg importieren (z.B. dyn. PW aus, Standard-PW Hash, etc.)
if(Test-Path $PolicyReg){
  Log "Importing policy: $PolicyReg"
  & reg import "$PolicyReg" | Out-Null
} else {
  Log "No policy reg found (skipping). You can export from a golden machine to $PolicyReg"
}

# 3) Autostart/Service sicherstellen
$svcName = Get-TVServiceName
try{
  Set-Service -Name $svcName -StartupType Automatic -ErrorAction SilentlyContinue
  Start-Service -Name $svcName -ErrorAction SilentlyContinue
  Log "Service ensured: $svcName (Automatic + Running)"
} catch {
  Log "ERROR ensuring service ${svcName}: $($_.Exception.Message)"
}

# 4) TeamViewer ID aus Registry lesen & loggen
Start-Sleep -Seconds 3
$id = Get-TVClientID
if($id){
  $idLog = "C:\Tiptorro\logs\teamviewer_id.log"
  "$((Get-Date).ToString('o')) ClientID=$id" | Tee-Object -FilePath $idLog -Append | Out-Null
  Log "ClientID logged: $id"
} else {
  Log "WARN: ClientID not found yet (TeamViewer may need to start once and phone home)"
}

Log "=== TeamViewer Setup END ==="
