<!-- START-HERE BANNER (auto) -->

> **Hinweis für Betrieb & Handover:** Bitte **keine bestehenden Phasen/Logiken ändern**, **außer** wenn es ausdrücklich beauftragt ist. Arbeiten (Tests, Deploy, Wartung) wie beschrieben **weiter durchführen**.
> Lies zuerst diese README, dann `docs/ops-playbook.md` (Phasen), danach optional `START-HERE.md` (Kurzleitfaden).

<!-- END START-HERE BANNER -->

# Torro Tec Setup & Management – README

**Ziel:** Reproduzierbare Einrichtung und Betrieb von **Terminal (Kiosk)** & **Kasse (Desktop)** unter Windows 10/11 Pro.

* **Root-Pfad:** `C:\Tiptorro`
* **Edge-Profile:** `C:\ttedge\{shop_support,shop_kiosk,livetv_support,livetv_kiosk}`
* **Shop-URL:** `https://shop.tiptorro.com`

---

## Aktueller Stand (2025‑09‑11)

* **Phase 5 (Geldgeräte):** Rescan/Recovery dokumentiert & getestet. **Settings werden nach Backend‑Setup automatisch neu erzeugt** (kein manuelles Anlegen).
* **Phase 6 (Edge/Policies):** Erststart-/Signin-/Sync-/Autofill-/Promo-/Benachrichtigungs‑Popups **aus**; Cookies für `https://shop.tiptorro.com` **erlaubt**.
* **Drucker OneClick:** Star/Hwasung automatisch (Queues mit **Original‑Treibernamen**). Falls kein Gerät erkannt → interaktiver Epson‑Installer (TM‑T88V/TM‑T88IV), danach Testseite & Standarddrucker.
* **Queue‑Namensstrategie:** Neu = Original‑Treibernamen (Legacy `TT_*` kompatibel).
* **Phase 8 (Kiosk/Support final):**

  * **Support:** Shop als **Tab** auf Monitor 1; LiveTV als **Kiosk** auf Monitor 2; Auswahl wird in `C:\Tiptorro\state\livetv.selected.json` gespeichert.
  * **Betrieb/Neustart:** Shop **Kiosk** (M1) & LiveTV **Kiosk** (M2) mit **gespeichertem Link** (keine Nachfrage).
  * **Wartung:** `Start-Maintenance.ps1` öffnet Shop (Tab) + Toolmaske zum Ändern des LiveTV‑Links; optional sofortige Übernahme.
  * **Assigned Access:** **nicht** im Einsatz (Edge‑Kiosk via Flags/Profiles).

> **Monitor 2**: Zielauflösung 1920×1080 bei 100 % Skalierung.

---

## Wichtige Skripte

* `scripts/Printers_Forms.ps1` – Aktionen: `OneClick`, `Detect`, `AddForms`, `Install`, `TestASCII`, `SavePrefs`, `LoadPrefs`
* `scripts/DeviceManager.ps1` – Service‑Handling / Health / Recovery
* **Kiosk/Support:**

  * `scripts/Start-ShopKiosk.ps1` – Shop: Support=Tab (M1), Betrieb=Kiosk (M1)
  * `scripts/Start-LiveTV.ps1` – LiveTV immer Kiosk (M2; `-MonitorIndex` konfigurierbar), **Persistenz** der Auswahl
  * `scripts/LiveTV-SetLink.ps1` – Wartungs‑Toolmaske (Link wählen/speichern, optional `-ApplyNow`)
  * `scripts/Start-Maintenance.ps1` – Wartungsworkflow (Shop Tab + LiveTV‑Toolmaske)
  * `scripts/OneClick-Phase8.ps1` – **Policies (HKLM/HKCU)**, **Profil‑Reset**, **Autostart‑Seeding**, optional Erstwahl `-PromptLiveTV`

---

## Pakete & Pfade

* **Drucker‑Treiber**
  `packages\printers\star\smjt100.inf`
  `packages\printers\hwasung\HWASUNG_64bit_v400.INF`
  `packages\printers\epson\installer\*.exe` (interaktiver Fallback)

* **LiveTV‑Links**
  `packages\LiveTVLinks\links.json`
  Beispiel:

  ```json
  { "items": [{"name": "Fussball S1 Scanner", "url": "https://shop.tiptorro.com/livetv/?rows=12&scan=true&page=1&pagecount=1&sports=1&ngoal=true"}],
    "defaultMonitorIndex": 2 }
  ```

* **Logs/State**
  `C:\Tiptorro\logs\*`, `C:\Tiptorro\state\livetv.selected.json`

---

## Quickstart

### Drucker – OneClick

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

### Edge‑Hardening, Profile, Autostart (Phase 8)

```powershell
PowerShell -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\OneClick-Phase8.ps1" -PolicyScope Machine -SetAutostart
# Optional Erstwahl LiveTV (Support‑Prompt):
# ... OneClick-Phase8.ps1 -PolicyScope Machine -SetAutostart -PromptLiveTV
```

### Support (manuell)

```powershell
# Shop Tab (M1)
PowerShell -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Start-ShopKiosk.ps1"
# LiveTV Auswahl (Kiosk M2) + Speichern
PowerShell -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Start-LiveTV.ps1" -Prompt -MonitorIndex 2
```

### Wartung

```powershell
PowerShell -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Start-Maintenance.ps1"
```

---

## Verifikation (Kernchecks)

```powershell
# Edge‑Policies (HKLM)
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' |
  Select HideFirstRunExperience,BrowserSignin,SyncDisabled

# Autostart‑Shortcuts
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" |
  Where-Object Name -like 'Torro *.lnk' | Select Name

# LiveTV‑Auswahl
Get-Content 'C:\Tiptorro\state\livetv.selected.json'
```

---

## Troubleshooting

* **Doppelte Tabs im Support:** `C:\ttedge\shop_support` löschen; Shop‑Script erneut starten.
* **Edge‑Popups sichtbar:** `OneClick-Phase8.ps1 -PolicyScope Machine` (Admin) ausführen; Profile `C:\ttedge\*` frisch anlegen.
* **Monitor 2 fehlt:** Script versucht `/extend`; ansonsten Positionierung auf Primär; Logs prüfen.

---

## Hinweise

* **Assigned Access:** nicht genutzt (Edge‑Kiosk mit Flags/Profilen).
* **Kompatibilität Queues:** Legacy `TT_*` bleibt funktionsfähig.
* **Sicherheit:** keine Credentials speichern; dedizierte Profile; Logs/Audit.

---

## Maintainer

Torro Tec – Setup & Management Team
Für Tickets bitte **Event 307** (Druck) + **Phase‑8 Snapshot** aus `C:\Tiptorro\logs\` anhängen.

---

### Änderungsübersicht (diese Fassung)

* Assigned‑Access‑Hinweise entfernt; Edge‑Kiosk final dokumentiert.
* Phase‑8 Verhalten/Policies/Autostart ergänzt.
* Pfade/Skripte vereinheitlicht; Quickstart/Verifikation/TS gebündelt.
