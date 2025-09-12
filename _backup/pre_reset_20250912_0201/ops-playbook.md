<!-- CONTINUE-HERE BANNER (auto) -->

> Dieses Playbook ist die maßgebliche Betriebsanleitung. Keine Grundgerüste/Dateien duplizieren.
> Nach kurzer Sicht auf **README.md** direkt hier arbeiten.

<!-- END CONTINUE-HERE BANNER -->

# Ops Playbook – Torro Tec Setup & Management

**Stand:** 11.09.2025
**Ziel:** Reproduzierbare Einrichtung/Support für **Terminal (Kiosk)** & **Kasse (Desktop)** unter Windows 10/11 Pro.

Root-Pfad: `C:\Tiptorro`
Profile/Edge: `C:\ttedge\...`
Shop: `https://shop.tiptorro.com`

---

## Inhaltsverzeichnis

* [Phase 1 – Basis vorbereiten](#phase-1--basis-vorbereiten)
* [Phase 2 – TeamViewer (optional)](#phase-2--teamviewer-optional)
* [Phase 3 – Device Manager (MSI) Neuaufbau](#phase-3--device-manager-msi-neuaufbau)
* [Phase 4 – Drucker & Formulare & OneClick](#phase-4--drucker--formulare--oneclick)
* [Phase 5 – Geldgeräte (Terminal)](#phase-5--geldgeräte-terminal)
* [Phase 6 – Edge/Policies (Popups aus, Cookies erlaubt)](#phase-6--edgepolicies-popups-aus-cookies-erlaubt)
* [Phase 7 – Assigned Access (optional/nicht genutzt)](#phase-7--assigned-access-optionalnicht-genutzt)
* [Phase 8 – Kiosk/Support final (Monitor 2 & LiveTV)](#phase-8--kiosksupport-final-monitor2--livetv)
* [Phase 9 – Shortcuts & Autostart (legacy/optional)](#phase-9--shortcuts--autostart-legacyoptional)
* [Phase 10 – Diagnose/Repair](#phase-10--diagnoserepair)
* [Phase 11 – Sicherheit](#phase-11--sicherheit)
* [Anhang – Verifikation & Snapshots](#anhang--verifikation--snapshots)

---

## Phase 1 – Basis vorbereiten

Ordnerstruktur anlegen (falls nicht vorhanden) und **Offline-Pakete** in `packages\` kopieren:

```powershell
$root = 'C:\Tiptorro'
$dirs = 'scripts','packages','logs','state','shortcuts','docs'
foreach($d in $dirs){ New-Item -ItemType Directory -Force -Path (Join-Path $root $d) | Out-Null }
# Branding/Icon optional:
# Copy-Item .\tiptorro.jpg C:\Tiptorro\tiptorro.jpg -Force
```

---

## Phase 2 – TeamViewer (optional)

**Wenn** verwendet: silent installieren, ID protokollieren. Sonst Phase überspringen.

```powershell
Start-Process 'C:\Tiptorro\packages\teamviewer\TeamViewer_Setup.exe' -ArgumentList '/S' -Wait
$id = (Get-Content "$env:ProgramFiles\TeamViewer\TeamViewer.ini" -ErrorAction SilentlyContinue | Select-String 'ClientID').ToString()
Add-Content C:\Tiptorro\logs\teamviewer_id.log "$(Get-Date -Format o) $id"
```

---

## Phase 3 – Device Manager (MSI) Neuaufbau

* Dienstname: **DeviceManager.Bootstrapper** (DisplayName „DeviceManager“)
* HealthCheck ≤120 s nach Install/FirstRun

```powershell
# Deinstall
$prod = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object { $_.DisplayName -like '*TipTorro Device Manager*' }
if($prod){ & msiexec.exe /x $prod.PSChildName /qn }
Remove-Item 'C:\Program Files (x86)\TipTorro' -Recurse -Force -ErrorAction SilentlyContinue

# Neuinstall
Start-Process msiexec.exe -ArgumentList "/i `"C:\Tiptorro\packages\device-manager\DeviceManager.msi`" /qn" -Wait

# Health-Check (Platzhalter: eigenes Script
# PowerShell -ExecutionPolicy Bypass -File 'C:\Tiptorro\scripts\HealthCheck.ps1'
```

---

## Phase 4 – Drucker & Formulare & OneClick

**Strategie:** Original-Treiber-Namen verwenden (Legacy `TT_*` bleibt funktionsfähig).

**OneClick (Star/Hwasung auto; Epson interaktiver Fallback):**

```powershell
PowerShell -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Printers_Forms.ps1" -Action OneClick `
  -StarInf   "C:\Tiptorro\packages\printers\star\smjt100.inf" `
  -StarDriverName "Star TSP100 Cutter (TSP143)" `
  -HwasungInf "C:\Tiptorro\packages\printers\hwasung\HWASUNG_64bit_v400.INF" `
  -HwasungDriverName "HWASUNG HMK-072"
```

**Verifikation:**

```powershell
Get-Printer | ft Name,DriverName,PortName,Default -Auto
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PrintService/Operational'; Id=307} -MaxEvents 3 |
  Select TimeCreated,Message
```

> Hinweis: Wenn kein Star/Hwasung erkannt → interaktiver Epson-Installer (TM‑T88V/TM‑T88IV) aus `C:\Tiptorro\packages\printers\epson\installer\*.exe`, danach Testseite & Standarddrucker.

---

## Phase 5 – Geldgeräte (Terminal)

**Ziel:** Dienst sauber stoppen → `ccTalk Devices.exe` (≈30–45 s) → Dienst starten.
**Recovery:** Settings löschen → erneut `ccTalk Devices.exe` → Dienst starten.
**Wichtig (11.09.2025):** Settings-Dateien werden **nach Backend-Setup automatisch neu erzeugt** (kein manuelles Anlegen nötig).

```powershell
$svc = 'DeviceManager.Bootstrapper'
# Rescan (Standard)
Stop-Service $svc -Force
Start-Process 'C:\Tiptorro\packages\cctalk\ccTalk Devices.exe'
Start-Sleep -Seconds 45
Start-Service $svc

# Recovery (Settings löschen + Rescan)
$settings = @(
  'C:\Program Files (x86)\TipTorro\Device Manager Service\moneysystem_settings.xml',
  'C:\Program Files (x86)\TipTorro\Device Manager Service\moneysystem_settings_save.xml'
)
Stop-Service $svc -Force
Remove-Item -LiteralPath $settings -Force -ErrorAction SilentlyContinue
Start-Process 'C:\Tiptorro\packages\cctalk\ccTalk Devices.exe'
Start-Sleep -Seconds 45
Start-Service $svc
```

---

## Phase 6 – Edge/Policies (Popups aus, Cookies erlaubt)

**Ziel:** Keine FRE-/Signin-/Sync-/Autofill-/Benachrichtigungs-Popups. Cookies für `shop.tiptorro.com` erlaubt.
**Umsetzung (OneClick-Step):** `scripts\OneClick-Phase8.ps1` setzt Policies in **HKLM** (HKCU-Fallback), räumt Profile und seedet Autostart.

**Ausführung (einmal pro Gerät, Admin empfohlen):**

```powershell
PowerShell -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\OneClick-Phase8.ps1" -PolicyScope Machine -SetAutostart -VerboseLog
# Optional: -PromptLiveTV für Erstwahl im Support
```

**Kernwerte (Auszug):**

* `HideFirstRunExperience=1`, `BrowserSignin=0`, `SyncDisabled=1`
* `DefaultNotificationsSetting=2`, `DefaultGeolocationSetting=2`
* `PasswordManagerEnabled=0`, `AutofillAddressEnabled=0`, `AutofillCreditCardEnabled=0`
* `PromotionalTabsEnabled=0`, `RestoreOnStartup=0`
* `CookiesAllowedForUrls = https://shop.tiptorro.com`

**Verifikation:** `edge://policy` oder per PowerShell siehe [Anhang](#anhang--verifikation--snapshots).

---

## Phase 7 – Assigned Access (optional/nicht genutzt)

**Hinweis:** Assigned Access/Kiosk der Windows-UI wird **nicht** verwendet.
Wir betreiben Kiosk-Fenster über Edge-Flags und dedizierte Profile (siehe Phase 8).
Bestehende Geräte mit Assigned Access bleiben funktionsfähig, neue Deployments **ohne**.

---

## Phase 8 – Kiosk/Support final (Monitor 2 & LiveTV)

**Verhalten (final):**

* **Support:** Shop **Tab** auf Monitor 1; LiveTV **Kiosk** auf Monitor 2; Auswahl via Prompt → Persistenz `C:\Tiptorro\state\livetv.selected.json`.
* **Betrieb/Neustart:** Shop **Kiosk** (M1), LiveTV **Kiosk** (M2) mit zuletzt gespeicherter Auswahl (keine Nachfrage).
* **Wartung:** `Start-Maintenance.ps1` öffnet Shop als Tab (M1) und LiveTV-Toolmaske (Link ändern, optional sofort übernehmen).

**Skripte:**

* `Start-ShopKiosk.ps1` – Shop (Support=Tab, Betrieb=Kiosk)
* `Start-LiveTV.ps1` – LiveTV immer Kiosk; `-Prompt` für Auswahl; Persistenz
* `LiveTV-SetLink.ps1` – Wartungs-Toolmaske; `-ApplyNow` setzt LiveTV sofort neu
* `Start-Maintenance.ps1` – kombinierter Wartungsablauf
* `OneClick-Phase8.ps1` – Policies, Profile, Autostart, optional Erstwahl

**Erstwahl (Support):**

```powershell
# Shop als Tab (M1)
PowerShell -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Start-ShopKiosk.ps1" -VerboseLog
# LiveTV-Auswahl (Kiosk M2) + Speichern
PowerShell -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Start-LiveTV.ps1" -Prompt -MonitorIndex 2 -VerboseLog
```

**Neustartbetrieb (Autostart via OneClick-Phase8):**

* `Torro Shop Kiosk.lnk` → `Start-ShopKiosk.ps1 -Mode Kiosk`
* `Torro LiveTV Kiosk.lnk` → `Start-LiveTV.ps1 -MonitorIndex 2`

**Wartungsmodus:**

```powershell
PowerShell -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Start-Maintenance.ps1"
```

**links.json (Format & Pfad):** `C:\Tiptorro\packages\LiveTVLinks\links.json`

```json
{
  "items": [
    { "name": "Fussball S1 Scanner", "url": "https://shop.tiptorro.com/livetv/?rows=12&scan=true&page=1&pagecount=1&sports=1&ngoal=true" }
  ],
  "defaultMonitorIndex": 2
}
```

---

## Phase 9 – Shortcuts & Autostart (legacy/optional)

**Ziel (ergänzend, nicht ersetzend):**  
*Bestehende Phase-8-Logik bleibt unberührt.* Wir liefern nur manuelle Shortcuts nach und stellen Autostart **falls fehlend** sicher.

**Ergebnis:**
- `LiveTV (Monitor 2).lnk` auf **Public Desktop** und **C:\Tiptorro\livetv.lnk** (Doppelklick startet LiveTV auf M2)
- `Torro Maintenance.lnk` auf **Public Desktop**
- Autostart-Shortcuts nur **anlegen, wenn nicht vorhanden**

> **Rollen-Hinweis:**  
> **Terminal (Kiosk):** Autostart belassen.  
> **Kasse (Desktop):** Autostart i. d. R. entfernen (nur manuelle Shortcuts verwenden).

### Umsetzung (idempotent)

```powershell
# Phase 9 – Shortcuts & Autostart (ergänzend)
$root   = 'C:\Tiptorro'
$psExe  = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$ws     = New-Object -ComObject WScript.Shell
$desk   = "$env:PUBLIC\Desktop"
$startu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'

function New-Shortcut($Path, $Target, $Arguments, $Icon=$null){
  if(Test-Path $Path){ return } # nichts überschreiben
  $sc = $ws.CreateShortcut($Path)
  $sc.TargetPath       = $Target
  $sc.Arguments        = [string]$Arguments
  $sc.WorkingDirectory = Split-Path $Target
  if($Icon){ $sc.IconLocation = $Icon }
  try { $sc.Save() }
  catch [System.UnauthorizedAccessException] {
    throw "Zugriff verweigert: $Path  (Konsole als Administrator starten oder Fallback auf User-Desktop nutzen)"
  }
}

# Arguments
$argLiveTV = "-ExecutionPolicy Bypass -File `"$root\scripts\Start-LiveTV.ps1`" -MonitorIndex 2"
$argShop   = "-ExecutionPolicy Bypass -File `"$root\scripts\Start-ShopKiosk.ps1`" -Mode Kiosk"
$argMaint  = "-ExecutionPolicy Bypass -File `"$root\scripts\Start-Maintenance.ps1`""

# Manuelle Shortcuts
New-Shortcut (Join-Path $desk 'LiveTV (Monitor 2).lnk') $psExe $argLiveTV
New-Shortcut (Join-Path $root 'livetv.lnk')             $psExe $argLiveTV
New-Shortcut (Join-Path $desk 'Torro Maintenance.lnk')  $psExe $argMaint

# Autostart nur sicherstellen (falls Phase 8 nicht bereits gesetzt hat)
New-Shortcut (Join-Path $startu 'Torro Shop Kiosk.lnk')   $psExe $argShop
New-Shortcut (Join-Path $startu 'Torro LiveTV Kiosk.lnk') $psExe $argLiveTV
$userDesk = Join-Path $env:USERPROFILE 'Desktop'
New-Shortcut (Join-Path $userDesk 'LiveTV (Monitor 2).lnk') $psExe $argLiveTV
New-Shortcut (Join-Path $userDesk 'Torro Maintenance.lnk')  $psExe $argMaint
# später mit Adminrechten kopieren:
Copy-Item (Join-Path $userDesk 'LiveTV (Monitor 2).lnk') "$env:PUBLIC\Desktop\LiveTV (Monitor 2).lnk" -Force
Copy-Item (Join-Path $userDesk 'Torro Maintenance.lnk')  "$env:PUBLIC\Desktop\Torro Maintenance.lnk" -Force
@(
  "$env:PUBLIC\Desktop\LiveTV (Monitor 2).lnk",
  "C:\Tiptorro\livetv.lnk",
  "$env:PUBLIC\Desktop\Torro Maintenance.lnk",
  "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Torro Shop Kiosk.lnk",
  "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Torro LiveTV Kiosk.lnk"
) | ForEach-Object { '{0} : {1}' -f <!-- CONTINUE-HERE BANNER (auto) -->

> Dieses Playbook ist die maßgebliche Betriebsanleitung. Keine Grundgerüste/Dateien duplizieren.
> Nach kurzer Sicht auf **README.md** direkt hier arbeiten.

<!-- END CONTINUE-HERE BANNER -->

# Ops Playbook – Torro Tec Setup & Management

**Stand:** 11.09.2025
**Ziel:** Reproduzierbare Einrichtung/Support für **Terminal (Kiosk)** & **Kasse (Desktop)** unter Windows 10/11 Pro.

Root-Pfad: `C:\Tiptorro`
Profile/Edge: `C:\ttedge\...`
Shop: `https://shop.tiptorro.com`

---

