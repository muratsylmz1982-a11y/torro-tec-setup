Phase 1 – Basis vorbereiten

Ordnerstruktur anlegen (falls nicht vorhanden):

$root = 'C:\Tiptorro'
$dirs = 'scripts','packages','policies','shortcuts','profiles','logs','docs'
foreach($d in $dirs){ New-Item -ItemType Directory -Force -Path (Join-Path $root $d) | Out-Null }

Logo/Branding ablegen: C:\tiptorro.jpg (wird für Shortcuts verwendet).

Offline‑Pakete in packages/ kopieren (Git ignoriert diese).

Phase 2 – TeamViewer standardisieren

Falls vorhanden: Einstellungen prüfen/anpassen.

Sonst installieren (Offline‑Paket):

Start-Process "C:\Tiptorro\packages\teamviewer\TeamViewer_Setup.exe" -ArgumentList "/S" -Wait

Einstellungen skripten (Beispiele – je nach Version prüfen):

Dynamisches PW aus, Autostart an.

Standard‑Passwort setzen (Policies/Export).

ID in Log schreiben:

$id = (Get-Content "$env:ProgramFiles\TeamViewer\TeamViewer.ini" -ErrorAction SilentlyContinue | Select-String -Pattern 'ClientID').ToString()
Add-Content C:\Tiptorro\logs\teamviewer_id.log "$(Get-Date -Format o) $id"

Phase 3 – Device Manager (MSI) Neuaufbau

Deinstallieren (Produktname/GUID anpassen):

$prod = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object {$_.DisplayName -like '*TipTorro Device Manager*'}
if($prod){ & msiexec.exe /x $prod.PSChildName /qn }

Ordner löschen: C:\Program Files (x86)\TipTorro.

Neustart nur bei Button: Biete Benutzer‑Prompt an (kein Auto‑Reboot).

Neuinstallieren:

Start-Process msiexec.exe -ArgumentList "/i `"C:\Tiptorro\packages\device-manager\DeviceManager.msi`" /qn" -Wait

Health‑Check (≤120 s) – siehe scripts/HealthCheck.ps1 (unten).

Phase 4 – Drucker + Formulare

Treiber installieren (Star/Epson/Hwasung) via printui.exe /ia oder Add-PrinterDriver.

Formulare anlegen (Beispiele):

# Erfordert Admin. Legt benutzerdef. Formate an.
function Add-Form([string]$name,[int]$wMm,[int]$hMm){
  $w = [int]($wMm*1000); $h = [int]($hMm*1000)
  $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Print\Forms'
  New-Item -Path $path -Name $name -Force | Out-Null
  New-ItemProperty -Path "$path\$name" -Name 'FormName' -Value $name -PropertyType String -Force | Out-Null
  New-ItemProperty -Path "$path\$name" -Name 'Size' -Value ([byte[]](0..7|%{0})) -PropertyType Binary -Force | Out-Null
  New-ItemProperty -Path "$path\$name" -Name 'ImageableArea' -Value ([byte[]](0..15|%{0})) -PropertyType Binary -Force | Out-Null
}
Add-Form 'TT_Star_72mm' 72 200
Add-Form 'TT_Epson_80x297' 80 297
Add-Form 'TT_Hwasung_80x400' 80 400

Hwasung in Diagnose: FormFeed+2 → Partial Cut, Skalierung 100 %, UTF‑8 (Fallback CP‑858), Dichte ±1.

Phase 5 – Geldgeräte (Terminal)

Dienst stoppen (Name anpassen, z. B. TipTorro.MoneySystem):

Stop-Service -Name 'TipTorro.MoneySystem' -ErrorAction SilentlyContinue

cctalkDevices.exe 30–45 s laufen lassen, dann Dienst starten:

Start-Process "C:\Tiptorro\packages\cctalk\cctalkDevices.exe" -Wait
Start-Service -Name 'TipTorro.MoneySystem'

Recovery: cctalk.exe ausführen + zweimal moneysystemsettings löschen.

Phase 6 – Edge/Policies (Pop‑ups/Assistenten aus, Cookies persistent)

Gruppe-Richtlinien (GUI): Computerkonfiguration → Administrative Vorlagen → Microsoft Edge

„Erste‑Schritte/Assistenten“ deaktivieren

„Pop‑ups“ blockieren

„Browsingdaten beim Beenden löschen“ Deaktiviert

„Drittanbieter‑Cookies blockieren“ Deaktiviert

Optional „Cookies für bestimmte Sites zulassen“: https://shop.tiptorro.com

Alternativ (Reg‑Beispiel, Version prüfen/ggf. anpassen):

policies/edge-policies.reg erstellen:

Windows Registry Editor Version 5.00
[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge]
"HideFirstRunExperience"=dword:00000001
"DefaultPopupsSetting"=dword:00000002
"ClearBrowsingDataOnExit"=dword:00000000
"BlockThirdPartyCookies"=dword:00000000

Anwenden: reg import C:\Tiptorro\policies\edge-policies.reg

Phase 7 – Kiosk (Terminal) Assigned Access

Manuell (UI): Einstellungen → Konten → Familie & andere Benutzer → Kiosk einrichten (Assigned Access)

Kiosk‑Benutzer anlegen (z. B. kiosk)

Microsoft Edge als App, Modus „Kiosk (Digital Signage)“

Start‑URL: https://shop.tiptorro.com

Wirksam nach manuellem Neustart.

Phase 8 – Monitor 2 & Live‑TV

Wenn zweiter Monitor erkannt wird (1920×1080 @ 100 % einstellen): Anzeigeeinstellungen → Erweiterte Anzeige.

Live‑TV‑Profile (.txt) nach C:\Tiptorro\packages\LiveTVLinks\ kopieren (Import Altordner möglich).

Shortcut C:\Tiptorro\livetv.lnk erzeugen (öffnet Live‑TV auf Screen 2):

$wsh = New-Object -ComObject WScript.Shell
$sc = $wsh.CreateShortcut('C:\Tiptorro\livetv.lnk')
$sc.TargetPath = 'powershell.exe'
$sc.Arguments   = '-ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Start-LiveTV.ps1"'
$sc.IconLocation= 'C:\Tiptorro\shortcuts\livetv.ico'
$sc.Save()

scripts/Start-LiveTV.ps1 (Beispiel – bewegt Fenster auf Monitor 2):

Add-Type -AssemblyName System.Windows.Forms
$hasTwo = [System.Windows.Forms.Screen]::AllScreens.Count -ge 2
if(-not $hasTwo){ Start-Process 'msedge.exe' 'https://shop.tiptorro.com'; exit }
# TODO: Ziel der Live-TV App/URL anpassen
$p = Start-Process 'msedge.exe' '--kiosk https://live.example/' -PassThru
Start-Sleep 2
# Fenster nach Screen 2 verschieben (vereinfachtes Beispiel, ggf. Hilfstool verwenden)
# Tipp: Tools wie nircmd/moveontop können hier präziser steuern.

Phase 9 – Shortcuts & Autostart

Terminal/Kasse Verknüpfungen erstellen:

function New-Link($path,$target,$args='',$icon='C:\tiptorro.jpg'){
  $w = New-Object -ComObject WScript.Shell
  $s = $w.CreateShortcut($path)
  $s.TargetPath=$target; $s.Arguments=$args; $s.IconLocation=$icon; $s.Save()
}
New-Link 'C:\Tiptorro Terminal.lnk' 'msedge.exe' '--kiosk https://shop.tiptorro.com'
New-Link 'C:\Tiptorro Kasse.lnk'    'C:\Tiptorro\packages\kasse\TiptorroKasse.exe'
# Autostart für Kasse
$startup = [Environment]::GetFolderPath('Startup')
Copy-Item 'C:\Tiptorro Kasse.lnk' (Join-Path $startup 'Tiptorro Kasse.lnk') -Force

Phase 10 – Diagnose/Repair

Ein-Klick‑Check (≤120 s) – scripts/HealthCheck.ps1:

# Pseudo-Beispiel: Prüft Dienste, Drucker, Policies, COM, Live-TV
$log = 'C:\Tiptorro\logs\healthcheck_'+(Get-Date -Format yyyyMMdd_HHmmss)+'.log'
function Log($m){ "$((Get-Date).ToString('o')) $m" | Tee-Object -FilePath $log -Append }
Log 'Start HealthCheck'
# Dienst
$svc = Get-Service -Name 'TipTorro.MoneySystem' -ErrorAction SilentlyContinue
if($svc.Status -ne 'Running'){ Start-Service $svc; Log "Dienst neu gestartet" }
# Drucker
Get-Printer | ForEach-Object{ Log "Printer: $($_.Name) / $($_.DriverName)" }
# Edge Policy Test (Registry Key vorhanden?)
$k='HKLM:SOFTWARE\Policies\Microsoft\Edge'
if(Test-Path $k){ Log 'Edge Policies vorhanden' } else { Log 'WARN: Edge Policies fehlen' }
# COM-Ports (Beispiel)
Get-CimInstance Win32_SerialPort | ForEach-Object{ Log "COM: $($_.DeviceID) $($_.Name)" }
Log 'HealthCheck Ende'

Repair: Teilskripte für Druckdichte/Codepage, Dienst‑Reset, Policy‑Reimport etc. separat in scripts/repair-*.ps1 pflegen.

Phase 11 – Sicherheit

PIN‑Schutz in UI der Kasse/Terminal‑Switcher vorsehen.

Signaturen prüfen vor Ausführung:

Get-ChildItem C:\Tiptorro\packages -Recurse -Include *.exe,*.msi | \
  ForEach-Object{ $sig=Get-AuthenticodeSignature $_; if($sig.Status -ne 'Valid'){ Write-Warning "Unsig.: $($_.FullName)" } }

Audit‑Logs in C:\Tiptorro\logs\ schreiben (keine Credentials im Klartext ablegen).

---

## PHASE-UPDATES (2025-09-10)

### Phase 3 – DeviceManager (Präzisierung)
- Dienstname: **DeviceManager.Bootstrapper** (DisplayName „DeviceManager“).
- Start-Absicherung: ServiceController + Fallback **`net start devicemanager`** / **`net stop devicemanager`**.
- HealthCheck ≤120s nach Install/FirstRun.

### Phase 4 – Drucker & Formate (konkret)
**Erkennung & Treiberpakete prüfen**
```powershell
& C:\Tiptorro\scripts\Scan-PrinterPackages.ps1 -Paths `
  'C:\Tiptorro\packages\printers\epson\driver\Tm-T 88V', `
  'C:\Tiptorro\packages\printers\epson\driver\Tm-T88IV', `
  'C:\Tiptorro\packages\printers\star', `
  'C:\Tiptorro\packages\printers\hwasung'
```

**Formate anlegen (Admin erforderlich)**
```powershell
Start-Process PowerShell -Verb RunAs -ArgumentList '-ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Printers_Forms.ps1" -Action AddForms'
```

**Nur erkannte Targets installieren (Beispiel Star)**
```powershell
& C:\Tiptorro\scripts\Printers_Forms.ps1 -Action Detect
& C:\Tiptorro\scripts\Printers_Forms.ps1 -Action Install -Targets Star `
  -StarInf 'C:\Tiptorro\packages\printers\star\smjt100.inf' `
  -StarDriverName 'Star TSP100 Cutter (TSP143)' `
  -StarPort 'USB007'
& C:\Tiptorro\scripts\Printers_Forms.ps1 -Action TestASCII -PrinterName 'TT_Star'
rundll32 printui.dll,PrintUIEntry /y /n "TT_Star"   # Standarddrucker setzen
```

**Epson/Hwasung (ohne Gerät vor Ort)**
```powershell
pnputil /add-driver "C:\Tiptorro\packages\printers\epson\driver\Tm-T 88V\*.inf" /install
pnputil /add-driver "C:\Tiptorro\packages\printers\hwasung\*.inf" /install
```
