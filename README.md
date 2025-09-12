# Torro Tec Setup & Management – README

**Ziel:** Reproduzierbare Einrichtung und Betrieb von **Terminal (Kiosk)** & **Kasse (Desktop)** unter Windows 10/11 Pro.

* **Root-Pfad:** `C:\Tiptorro`
* **Edge-Profile:** `C:\ttedge\{shop_support,shop_kiosk,livetv_support,livetv_kiosk}`
* **Shop-URL:** `https://shop.tiptorro.com`

---

## Aktueller Stand (2025-09-12)

**Kernpunkte**

- **Phase 8 (Finalisierung/Kiosk):**
  - **Support-Laufzeit:** Shop als **Tab** auf Monitor 1.
  - **Betrieb/Neustart:** Shop **Kiosk** (M1) & LiveTV **Kiosk** (M2) starten automatisch mit **gespeichertem LiveTV-Link** (keine Nachfrage mehr).
  - **LiveTV-Auswahl** wird in `C:\Tiptorro\state\livetv.selected.json` persistiert.
  - **Assigned Access** wird **nicht** genutzt (Edge-Kiosk via Flags/Profiles ist Standard).
- **Edge-Policies (Hardening):** First-Run/Signin/Sync/Autofill/Promo/Notify unterdrückt; Cookies für `shop.tiptorro.com` erlaubt.
- **Drucker (OneClick):**
  - Es wird **kein Standardmodell erzwungen**; installiert wird **nur der tatsächlich erkannte** Drucker:
    - **Star TSP100/TSP143** (INF),
    - **Hwasung HMK-072** (INF),
    - **Epson TM-T88V/TM-T88IV** via **EXE-Installer** (interaktiv) als Fallback.
  - Nach erfolgreicher Installation: **als Standard setzen** + **Testseite** drucken.
- **Device Manager (Dienst):**
  - Dienstname: `DeviceManager.Bootstrapper`
  - MSI: `packages\device-manager\DeviceManager.Service.Setup.msi`
  - Service-Binary: `"C:\Program Files (x86)\TipTorro\Device Manager Service\DeviceManager.Service.exe"`

---

## Wichtige Skripte

- `scripts\Torro-Panel.ps1` – GUI-Panel (Tabs: Setup, Terminal, Kasse, Diagnostics, Security, Status, Tools)
- `scripts\OneClick-Phase8.ps1` – Edge-Hardening, Profile/Autostart, optional **Erstwahl** `-PromptLiveTV`
- `scripts\Start-ShopKiosk.ps1` – Shop (Tab/Kiosk je Modus)
- `scripts\Start-LiveTV.ps1` – LiveTV Kiosk (M2, `-MonitorIndex`), **Auswahl speichern**
- `scripts\LiveTV-SetLink.ps1` – Link wählen/speichern (optional `-ApplyNow`)
- `scripts\Start-Maintenance.ps1` – Wartungsworkflow (Shop Tab + LiveTV-Maske)
- `scripts\Printers_Forms.ps1` – Drucker OneClick/Detect/AddForms/Install/Test/Prefs
- `scripts\DeviceManager.ps1` – Install/Repair/Start/Stop/Health
- `scripts\HealthCheck.ps1`, `scripts\Audit-Signatures.ps1` – Prüfungen/Reports

---

## Pakete & Pfade

**Drucker-Treiber**

packages\printers\star\smjt100.inf
packages\printers\hwasung\HWASUNG_64bit_v400.INF
packages\printers\epson\installer*.exe # interaktiver Fallback

markdown
Code kopieren

**LiveTV-Links**

packages\LiveTVLinks\links.json
state\livetv.selected.json # wird vom Tool angelegt/aktualisiert

markdown
Code kopieren

**Device Manager**

packages\device-manager\DeviceManager.Service.Setup.msi

Dienstname: DeviceManager.Bootstrapper
cpp
Code kopieren

**TeamViewer (optional, Kasse)**

packages\teamviewer\TeamViewer_Setup.exe
packages\teamviewer\TeamViewer_Settings.reg

markdown
Code kopieren

**Logs**

C:\Tiptorro\logs\healthcheck_.log
C:\Tiptorro\logs\audit_signatures_.csv
C:\Tiptorro\logs\printers_forms_*.log

yaml
Code kopieren

---

## Quickstart (Befehle)

### Panel (als Administrator)

```powershell
Start-Process powershell.exe -Verb runas -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Torro-Panel.ps1"'
Phase 8 – Edge/Autostart/Erstwahl LiveTV
powershell
Code kopieren
PowerShell -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\OneClick-Phase8.ps1" -PolicyScope Machine -SetAutostart -PromptLiveTV
LiveTV manuell starten / Link wählen (Kiosk auf M2)
powershell
Code kopieren
# Auswahldialog + Start (Monitor 2)
PowerShell -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Start-LiveTV.ps1" -Prompt -MonitorIndex 2
Drucker – OneClick (Erkennungsgesteuert)
powershell
Code kopieren
PowerShell -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Printers_Forms.ps1" -Action OneClick `
  -StarInf "C:\Tiptorro\packages\printers\star\smjt100.inf" -StarDriverName "Star TSP100 Cutter (TSP143)" `
  -HwasungInf "C:\Tiptorro\packages\printers\hwasung\HWASUNG_64bit_v400.INF" -HwasungDriverName "HWASUNG HMK-072"
Wichtig: Es wird nur der physisch erkannte Drucker installiert. Epson läuft bewusst über den EXE-Installer (kein INF).

Device Manager (Dienst)
powershell
Code kopieren
# Install/Repair (silent)
Start-Process msiexec.exe -Verb runas -ArgumentList '/i "C:\Tiptorro\packages\device-manager\DeviceManager.Service.Setup.msi" /qn' -Wait

# Start/Stop/Status
sc.exe start  "DeviceManager.Bootstrapper"
sc.exe stop   "DeviceManager.Bootstrapper"
sc.exe query  "DeviceManager.Bootstrapper"
Panel – Terminallayout (final)
Reihe 1: OneClick Setup (Phase 8, Admin) • Maintenance öffnen (PIN/normal) • Geldgeräte-Assistent (ccTalk)
Reihe 2: Start LiveTV (Monitor 2) • Shop (normal, kein Kiosk) • (rechts: LiveTV-Auswahl, Speichern, Jetzt starten)
Reihe 3: DeviceManager installieren/aktualisieren (Admin) • DeviceManager Start • DeviceManager Stop
Reihe 4: HealthCheck ausführen • Audit Signatures

Tab Kasse: OneClick Drucker • TeamViewer Setup (Silent + Reg) • DESKO installieren (optional) • DATAWIN installieren (optional) • LiveTV (ohne Kiosk)

Verifikation (Kernchecks)
powershell
Code kopieren
# Edge-Policies (HKLM)
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' |
  Select HideFirstRunExperience,BrowserSignin,SyncDisabled

# Autostart-Verknüpfungen (pro Benutzer)
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" |
  Where-Object Name -like 'Torro *.lnk' | Select Name

# LiveTV-Auswahl (Persistenz)
Get-Content 'C:\Tiptorro\state\livetv.selected.json' -Raw

# Druckerstatus
Get-Printer | ft Name,DriverName,PortName,Default -Auto
Troubleshooting (Kurz)
Panel ohne Admin gestartet: Dienst-/Policy-Aktionen schlagen fehl → Panel mit Admin starten.

Monitor 2 fehlt: Script versucht /extend; sonst Start auf Primärmonitor; Logs prüfen.

Drucker nicht erkannt: Siehe separates Drucker-Playbook/Thread (Star/Hwasung via INF, Epson via EXE). Log: printers_forms_*.log.

Doppelte Shop-Tabs: C:\ttedge\shop_support löschen, Shop erneut starten.

Print-Event 307 fehlt: Kanal aktivieren
wevtutil sl Microsoft-Windows-PrintService/Operational /e:true

Sicherheit & Betrieb
Keine Credentials speichern; getrennte Edge-Profile.

Offline-tauglich: Treiberpakete lokal; minimale Abhängigkeiten.

Logs & Audit: C:\Tiptorro\logs\* regelmäßig sichern/prüfen.

Maintainer
Torro Tec – Setup & Management Team
Bitte bei Tickets Event 307 (Druck) und Phase-8-Log beilegen.


---