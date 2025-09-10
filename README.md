# Torro Tec Setup & Management – Produktion

**Ziel:** Vollständige, reproduzierbare Einrichtung und Verwaltung von *Terminal (Kiosk)* und *Kasse (Desktop)* unter Windows 10/11 Pro.

**Kernpfad:** `C:\Tiptorro`  (Tool legt alles selbst an; alle Pakete offline enthalten)

**Shop-URL:** https://shop.tiptorro.com

## Geräte & Rollen
- **Terminal (Kiosk):** Assigned Access, Standardinhalt Shop, UI‑Umschalter „Live‑TV“; Änderungen wirksam nach *manuellem Neustart*.
- **Kasse (Desktop):** Desktop‑App/Shortcut, Autostart aktiviert.

## Standardpakete
- TeamViewer (Standard‑PW, dyn. PW *aus*, Autostart *an*, ID wird geloggt)
- Device Manager (MSI): Deinstall → Ordner löschen → Neustart nur per Button → Neuinstall → Health‑Check (≤120 s)
- Drucker: Star/Epson/Hwasung (Formulare: `TT_Star_72mm`, `TT_Epson_80x297`, `TT_Hwasung_80x400`)
- Geldgeräte (Terminal): Dienst stoppen → `cctalkDevices.exe` (30–45 s) → Dienst starten; Recovery: `cctalk.exe` + 2× `moneysystemsettings` löschen

## Edge/Policies
- Pop‑ups/Assistenten aus; persistente Cookies (Terminal & Kasse).

## Monitore
- **Monitor 2 (falls vorhanden):** 1920×1080 / 100 % Skalierung. Standard: *Live‑TV* auf Screen 2, sonst *Shop* auf Screen 1.
- **Live‑TV‑Links:** TXT‑Profile unter `C:\Tiptorro\packages\LiveTVLinks\` (Import vom Altordner möglich). Bei Screen 2: `C:\Tiptorro\livetv.lnk` erzeugen (öffnet auf Screen 2).

## Shortcuts & Branding
- `C:\Tiptorro Terminal.lnk`, `C:\Tiptorro Kasse.lnk`, `C:\tiptorro.jpg`
- Kasse: zusätzlich Desktop‑Icon + Autostart „Tiptorro Kasse“.

## Diagnose/Repair
Vollcheck + Ein‑Klick‑Fix für: Druckdichte, Codepage, Dienststatus, COM‑Ports, Drucker, Policies, Live‑TV‑Test.

## Sicherheit
PIN‑Schutz; signierte Payloads; Logs/Audit; keine Credentials speichern.

---

### How‑To starten
1) **Repo klonen/initialisieren** in `C:\Tiptorro`.
2) `docs/ops-playbook.md` Schritt für Schritt ausführen.
3) Nach großen Änderungen: `git add . && git commit -m "feat: …" && git push`.

---

## Aktueller Projektstand (Kurz)
- **TeamViewer:** installiert, Service *TeamViewer* läuft; Golden Settings liegen als `policies\TeamViewer_Settings.reg`.
- **DeviceManager:** MSI installiert; Dienstname **DeviceManager.Bootstrapper**; Autostart aktiv; Fallback **`net start devicemanager`** im Skript.
- **Drucker (Phase 4):** Star produktiv (Queue **TT_Star**, Treiber **Star TSP100 Cutter (TSP143)**, Port **USB007**, als Standard gesetzt).
  - Benutzerdefinierte Formate: `TT_Star_72mm`, `TT_Epson_80x297`, `TT_Hwasung_80x400` (**Admin erforderlich**).
  - **Epson/Hwasung:** Treiber nur gestaged (kein Gerät vor Ort) → aktuell **keine** Queues.

## Wichtige Skripte & Pfade
- `C:\Tiptorro\scripts\DeviceManager.ps1` – Install/FirstRun/Start/Stop/Status/Reinstall/HealthCheck (Fallback: `net start/stop devicemanager`).
- `C:\Tiptorro\scripts\Printers_Forms.ps1` – Detect, **AddForms (Admin)**, **Install (nur Targets & nur wenn erkannt)**, TestASCII, SavePrefs/LoadPrefs.
- `C:\Tiptorro\scripts\Scan-PrinterPackages.ps1` – Prüft `*.inf` (Klasse=Printer, NTamd64/x64, Katalog/Signatur).
- Logs: `C:\Tiptorro\logs\*`

## Quickstart – Drucker (Star-Beispiel)
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
