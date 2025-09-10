<!-- START-HERE BANNER (auto) -->
> WICHTIG fuer den naechsten Chat (Handover): Bitte NICHT neu aufsetzen oder Dateien neu erzeugen.
> 1) Zuerst README.md (diese Datei) lesen, dann docs/ops-playbook.md (Phasen 3/4) und docs/handover-template.md.
> 2) Weiterfuehren ab hier: Phase 5 (Geldgeraete) ODER Phase 6 (Edge/Policies).
> 3) Aktueller Stand: Star ok (Queue TT_Star, Treiber Star TSP100 Cutter (TSP143), Port USB007, Default gesetzt); Epson/Hwasung nur gestaged.
> 4) Kurzcheck:
>    Get-Printer | ? Name -like 'TT_*' | select Name,DriverName,PortName
>    (Get-CimInstance Win32_Printer | ? Default).Name
<!-- END START-HERE BANNER -->
# Torro Tec Setup & Management â€“ Produktion

**Ziel:** VollstÃ¤ndige, reproduzierbare Einrichtung und Verwaltung von *Terminal (Kiosk)* und *Kasse (Desktop)* unter WindowsÂ 10/11Â Pro.

**Kernpfad:** `C:\Tiptorro`  (Tool legt alles selbst an; alle Pakete offline enthalten)

**Shop-URL:** https://shop.tiptorro.com

## GerÃ¤te & Rollen
- **Terminal (Kiosk):** Assigned Access, Standardinhalt Shop, UIâ€‘Umschalter â€žLiveâ€‘TVâ€œ; Ã„nderungen wirksam nach *manuellem Neustart*.
- **Kasse (Desktop):** Desktopâ€‘App/Shortcut, Autostart aktiviert.

## Standardpakete
- TeamViewer (Standardâ€‘PW, dyn. PW *aus*, Autostart *an*, ID wird geloggt)
- Device Manager (MSI): Deinstall â†’ Ordner lÃ¶schen â†’ Neustart nur per Button â†’ Neuinstall â†’ Healthâ€‘Check (â‰¤120Â s)
- Drucker: Star/Epson/Hwasung (Formulare: `TT_Star_72mm`, `TT_Epson_80x297`, `TT_Hwasung_80x400`)
- GeldgerÃ¤te (Terminal): Dienst stoppen â†’ `cctalkDevices.exe` (30â€“45Â s) â†’ Dienst starten; Recovery: `cctalk.exe` + 2Ã— `moneysystemsettings` lÃ¶schen

## Edge/Policies
- Popâ€‘ups/Assistenten aus; persistente Cookies (Terminal & Kasse).

## Monitore
- **MonitorÂ 2 (falls vorhanden):** 1920Ã—1080 / 100Â % Skalierung. Standard: *Liveâ€‘TV* auf ScreenÂ 2, sonst *Shop* auf ScreenÂ 1.
- **Liveâ€‘TVâ€‘Links:** TXTâ€‘Profile unter `C:\Tiptorro\packages\LiveTVLinks\` (Import vom Altordner mÃ¶glich). Bei ScreenÂ 2: `C:\Tiptorro\livetv.lnk` erzeugen (Ã¶ffnet auf ScreenÂ 2).

## Shortcuts & Branding
- `C:\Tiptorro Terminal.lnk`, `C:\Tiptorro Kasse.lnk`, `C:\tiptorro.jpg`
- Kasse: zusÃ¤tzlich Desktopâ€‘Icon + Autostart â€žTiptorro Kasseâ€œ.

## Diagnose/Repair
Vollcheck + Einâ€‘Klickâ€‘Fix fÃ¼r: Druckdichte, Codepage, Dienststatus, COMâ€‘Ports, Drucker, Policies, Liveâ€‘TVâ€‘Test.

## Sicherheit
PINâ€‘Schutz; signierte Payloads; Logs/Audit; keine Credentials speichern.

---

### Howâ€‘To starten
1) **Repo klonen/initialisieren** in `C:\Tiptorro`.
2) `docs/ops-playbook.md` Schritt fÃ¼r Schritt ausfÃ¼hren.
3) Nach groÃŸen Ã„nderungen: `git add . && git commit -m "feat: â€¦" && git push`.

---

## Aktueller Projektstand (Kurz)
- **TeamViewer:** installiert, Service *TeamViewer* lÃ¤uft; Golden Settings liegen als `policies\TeamViewer_Settings.reg`.
- **DeviceManager:** MSI installiert; Dienstname **DeviceManager.Bootstrapper**; Autostart aktiv; Fallback **`net start devicemanager`** im Skript.
- **Drucker (Phase 4):** Star produktiv (Queue **TT_Star**, Treiber **Star TSP100 Cutter (TSP143)**, Port **USB007**, als Standard gesetzt).
  - Benutzerdefinierte Formate: `TT_Star_72mm`, `TT_Epson_80x297`, `TT_Hwasung_80x400` (**Admin erforderlich**).
  - **Epson/Hwasung:** Treiber nur gestaged (kein GerÃ¤t vor Ort) â†’ aktuell **keine** Queues.

## Wichtige Skripte & Pfade
- `C:\Tiptorro\scripts\DeviceManager.ps1` â€“ Install/FirstRun/Start/Stop/Status/Reinstall/HealthCheck (Fallback: `net start/stop devicemanager`).
- `C:\Tiptorro\scripts\Printers_Forms.ps1` â€“ Detect, **AddForms (Admin)**, **Install (nur Targets & nur wenn erkannt)**, TestASCII, SavePrefs/LoadPrefs.
- `C:\Tiptorro\scripts\Scan-PrinterPackages.ps1` â€“ PrÃ¼ft `*.inf` (Klasse=Printer, NTamd64/x64, Katalog/Signatur).
- Logs: `C:\Tiptorro\logs\*`

## Quickstart â€“ Drucker (Star-Beispiel)
```powershell
& C:\Tiptorro\scripts\Printers_Forms.ps1 -Action Detect
Start-Process PowerShell -Verb RunAs -ArgumentList '-ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Printers_Forms.ps1" -Action AddForms'
& C:\Tiptorro\scripts\Printers_Forms.ps1 -Action Install -Targets Star `
  -StarInf 'C:\Tiptorro\packages\printers\star\smjt100.inf' `
  -StarDriverName 'Star TSP100 Cutter (TSP143)' `
  -StarPort 'USB007'
& C:\Tiptorro\scripts\Printers_Forms.ps1 -Action TestASCII -PrinterName 'TT_Star'
rundll32 printui.dll,PrintUIEntry /y /n "TT_Star"
```
## Phase 5 & 6 – Umsetzung (Kurz) – Stand 2025-09-10

**Phase 5 – Geldgeräte**  
- Service: `DeviceManager.Bootstrapper`  
- ToolsPath: `C:\Tiptorro\packages\cctalk` (gefunden: **ccTalk Devices.exe**)  
- Rescan: Dienst stoppen → `ccTalk Devices.exe` (~45 s) → Dienst starten.  
- Recovery (bei Bedarf): Settings löschen und Rescan.  
  - Settings: `C:\Program Files (x86)\TipTorro\Device Manager Service\moneysystem_settings.xml` und `moneysystem_settings_save.xml`  
  - Hinweis: Die Dateien werden nach der Backend-Konfiguration durch den Support wieder neu erzeugt.

**Phase 6 – Edge/Policies**  
- Registry: `HKLM\SOFTWARE\Policies\Microsoft\Edge`  
- Werte: `DefaultPopupsSetting=2`, `HideFirstRunExperience=1`, `DefaultCookiesSetting=1`, `ClearBrowsingDataOnExit=0`, `BlockThirdPartyCookies=0`, `CookiesAllowedForUrls=https://shop.tiptorro.com`  
- Verifikation: `edge://policy` → alle Werte **OK**.

