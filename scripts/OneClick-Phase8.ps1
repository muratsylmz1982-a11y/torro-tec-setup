[CmdletBinding()]
param(
  [ValidateSet('Machine','User')][string]$PolicyScope = 'Machine',
  [switch]$SetAutostart = $true,
  [switch]$PromptLiveTV,
  [int]$LiveTVMonitorIndex = 2,
  [switch]$VerboseLog
)

$ErrorActionPreference = "Stop"
function Log([string]$m){ if($VerboseLog){ Write-Host "[Phase8] $m" } }

function Is-Admin {
  $id=[Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 1) Policies anwenden (Auto-Elevation bei Machine)
$base = if($PolicyScope -eq 'Machine'){'HKLM:\SOFTWARE\Policies\Microsoft\Edge'} else {'HKCU:\SOFTWARE\Policies\Microsoft\Edge'}
if($PolicyScope -eq 'Machine' -and -not (Is-Admin)){
  Log "Kein Admin: starte mich neu mit UAC..."
  Start-Process PowerShell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -PolicyScope Machine -SetAutostart:$SetAutostart -PromptLiveTV:$PromptLiveTV -LiveTVMonitorIndex $LiveTVMonitorIndex -VerboseLog:$VerboseLog"
  exit 0
}

Log "Policies unter $base setzen..."
New-Item -Path $base -Force | Out-Null
$vals = @{
  HideFirstRunExperience=1; PromotionalTabsEnabled=0; DefaultBrowserSettingEnabled=0; AutoImportAtFirstRun=0;
  BrowserSignin=0; SyncDisabled=1; DefaultNotificationsSetting=2; DefaultGeolocationSetting=2;
  PasswordManagerEnabled=0; PasswordLeakDetectionEnabled=0; AutofillAddressEnabled=0; AutofillCreditCardEnabled=0;
  RestoreOnStartup=0; ShowRecommendationsEnabled=0; StandaloneHubsSidebarEnabled=0
}
foreach($k in $vals.Keys){ New-ItemProperty -Path $base -Name $k -PropertyType DWord -Value $vals[$k] -Force | Out-Null }

$cookiesKey = Join-Path $base 'CookiesAllowedForUrls'
New-Item -Path $cookiesKey -Force | Out-Null
New-ItemProperty -Path $cookiesKey -Name '1' -PropertyType MultiString -Value @('https://shop.tiptorro.com') -Force | Out-Null

# 2) Edge-Prozesse beenden & Profile „frisch“
Log "Edge-Instanzen stoppen und Profile bereinigen..."
Stop-Process -Name msedge -Force -ErrorAction SilentlyContinue
$profiles = 'C:\ttedge\shop_support','C:\ttedge\shop_kiosk','C:\ttedge\livetv_support','C:\ttedge\livetv_kiosk'
foreach($p in $profiles){ if(Test-Path $p){ Remove-Item $p -Recurse -Force -EA SilentlyContinue } }
New-Item -ItemType Directory -Force $profiles | Out-Null
New-Item -ItemType Directory -Force 'C:\Tiptorro\state','C:\Tiptorro\logs' | Out-Null

# 3) Autostart-Verknüpfungen (Benutzer-Startup)
if($SetAutostart){
  Log "Autostart-Verknüpfungen setzen (User-Startup)..."
  $startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
  New-Item -ItemType Directory -Force $startup | Out-Null
  @('Torro Shop Kiosk.lnk','Torro LiveTV Kiosk.lnk','tv.lnk','livetv.lnk') | %{
    $p = Join-Path $startup $_; if(Test-Path $p){ Remove-Item $p -Force }
  }
  $psExe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
  $wsh = New-Object -ComObject WScript.Shell

  # Shop (Kiosk auf M1)
  $lnk1 = $wsh.CreateShortcut((Join-Path $startup 'Torro Shop Kiosk.lnk'))
  $lnk1.TargetPath = $psExe
  $lnk1.Arguments  = '-ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Start-ShopKiosk.ps1" -Mode Kiosk'
  $lnk1.WorkingDirectory = 'C:\Tiptorro\scripts'
  $lnk1.Save()

  # LiveTV (Kiosk auf M2, lädt gespeicherten Link)
  $lnk2 = $wsh.CreateShortcut((Join-Path $startup 'Torro LiveTV Kiosk.lnk'))
  $lnk2.TargetPath = $psExe
  $lnk2.Arguments  = "-ExecutionPolicy Bypass -File `"C:\Tiptorro\scripts\Start-LiveTV.ps1`" -MonitorIndex $LiveTVMonitorIndex"
  $lnk2.WorkingDirectory = 'C:\Tiptorro\scripts'
  $lnk2.Save()
}

# 4) Optional: erste LiveTV-Auswahl im Support, speichert Persistenz
if($PromptLiveTV){
  Log "Erste LiveTV-Auswahl (Support-Prompt) wird angezeigt..."
  Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -ArgumentList @("-ExecutionPolicy","Bypass","-File","C:\Tiptorro\scripts\Start-LiveTV.ps1","-Prompt","-MonitorIndex",$LiveTVMonitorIndex) `
    -Wait
}

# 5) Snapshot/Protokoll
$logFile = Join-Path 'C:\Tiptorro\logs' ("phase8_{0:yyyyMMdd_HHmmss}.txt" -f (Get-Date))
Add-Type -AssemblyName System.Windows.Forms
$i=0
$mon = [System.Windows.Forms.Screen]::AllScreens | % { $i++; "{0}: {1}x{2} @ {3},{4} Primary={5}" -f $i,$_.Bounds.Width,$_.Bounds.Height,$_.Bounds.X,$_.Bounds.Y,$_.Primary }
$pol = Get-ItemProperty $base | Select-Object HideFirstRunExperience,BrowserSignin,SyncDisabled,DefaultNotificationsSetting,DefaultGeolocationSetting,PasswordManagerEnabled,AutofillAddressEnabled,AutofillCreditCardEnabled,PromotionalTabsEnabled,RestoreOnStartup
"=== Phase8 Snapshot ===`nPolicyBase: $base`n--- Policies ---`n$($pol | Out-String)`n--- Monitors ---`n$($mon -join "`n")" |
  Out-File $logFile -Encoding utf8
Log "Snapshot -> $logFile"

Write-Host "✔ Phase8 abgeschlossen."
