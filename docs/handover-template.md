```markdown
# Übergabe – Torro Tec Setup & Management – Produktion

**Datum:** <YYYY-MM-DD>  
**Kontakt/Owner:** <Name, E-Mail>

## 1) Projektkontext (kurz)
- Zweck & Scope:
- Geräte & Rollen: Terminal (Kiosk), Kasse (Desktop)
- Kernpfad: `C:\Tiptorro`
- Shop-URL: https://shop.tiptorro.com

## 2) Aktueller Stand
- Letzte Schritte (Zeitstempel + kurze Beschreibung):
- Erreichte Meilensteine:

## 3) Offene Punkte (Next Actions)
- [ ] …
- [ ] …

## 4) Risiken/Blocker
- …

## 5) Entscheidungen/Annahmen
- …

## 6) Artefakte/Orte
- Repo/Branch: …
- Logs: `C:\Tiptorro\logs\` (keine Credentials)
- Wichtige Skripte: `C:\Tiptorro\scripts\`

## 7) Wie starte ich lokal?
- PowerShell als Admin → `docs/ops-playbook.md` folgen.

## 8) Nächste Prüfpunkte / Definition of Done

---

# Beispieleinträge (Stand 2025-09-10)
- [Phase 5] Geldgeräte-Rescan durchgeführt: Dienst **DeviceManager.Bootstrapper** gestoppt, **ccTalk Devices.exe** (~45 s) gestartet, Dienst wieder gestartet. Recovery: `moneysystem_settings*.xml` gelöscht; Backend hat Dateien neu erzeugt.
- [Phase 6] Edge/Policies gesetzt: Popups blocken, First-Run aus, Cookies persistent, 3rd-Party nicht blockieren, Allowlist `https://shop.tiptorro.com`. Anzeige in `edge://policy` = OK.
- [Drucker] Star produktiv: Queue **TT_Star**, Driver **Star TSP100 Cutter (TSP143)**, Port **USB007**, ASCII-Test ok, als Standard gesetzt.
- TeamViewer: Policy importiert (`policies\TeamViewer_Settings.reg`), Service läuft.
- DeviceManager: Dienst **DeviceManager.Bootstrapper** (Autostart), Fallback `net start/stop devicemanager` verifiziert.

## Offene Punkte (Next Actions – Vorlage)
- [ ] Epson/Hwasung vor Ort anschließen; Queue per `Printers_Forms.ps1 -Action Install` anlegen; ggf. Prefs sichern (`SavePrefs`).
- [ ] Monitor 2 (falls vorhanden): `C:\Tiptorro\livetv.lnk` erzeugen und Ziel für Live-TV konfigurieren.
- [ ] Optional: HealthCheck/Repair-Skripte ergänzen (Dichte/Codepage/COM).

## Start here (für den nächsten Chat) – 2025-09-10
- Bitte nicht neu aufsetzen. Lies zuerst README.md (Projektstand) und `docs/ops-playbook.md` (Phasen 3/4/5/6 – umgesetzt).
- Weiterführen: Phase 7 (Kiosk/Assigned Access), Phase 8 (Monitor 2 & Live-TV) **oder** Drucker-Queues für Epson/Hwasung erzeugen.
- Star ist eingerichtet (TT_Star auf USB007). Epson/Hwasung nur gestaged (keine Queues).

## Anhänge (bei Rückfragen beilegen)
- README.md
- docs/ops-playbook.md
- docs/handover-template.md
- Relevante Logs aus `C:\Tiptorro\logs\*` (z. B. `printers_forms_*.log`, `devicemanager_*.log`, `edge-policies.reg`)
- Skripte unter `C:\Tiptorro\scripts\*`

- **Drucker – OneClick-Logik:** Star/Hwasung auto (Queue = **Original-Treibername**).  
  Wenn **kein** Star/Hwasung erkannt → **Epson via Dialog** (Modellwahl **TM-T88V**/**TM-T88IV**, Installer-EXE), danach **Testseite** & **Standarddrucker**.  
  _Legacy:_ vorhandene `TT_*`-Queues bleiben gültig.
<!-- Marker: OneClick-Logik: Star/Hwasung auto (Original-Name) -->
```
