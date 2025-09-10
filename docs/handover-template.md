# Übergabe – Torro Tec Setup & Management – Produktion


**Datum:** <YYYY-MM-DD>
**Kontakt/Owner:** <Name, E-Mail>


## 1) Projektkontext (kurz)
- Zweck & Scope:
- Geräte & Rollen: Terminal (Kiosk), Kasse (Desktop)
- Kernpfad: `C:\Tiptorro`
- Shop‑URL: https://shop.tiptorro.com


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

## Beispieleinträge (Stand 2025-09-10)
- [12:22] Star-Drucker eingerichtet: Queue **TT_Star**, Driver **Star TSP100 Cutter (TSP143)**, Port **USB007**, Test ASCII ok, als Standard gesetzt.
- TeamViewer: Policy importiert (`policies\TeamViewer_Settings.reg`), Service läuft.
- DeviceManager: Dienst **DeviceManager.Bootstrapper** (Autostart), Fallback `net start/stop devicemanager` verifiziert.

## Offene Punkte (Next Actions – Vorlage)
- [ ] Epson/Hwasung vor Ort anschließen; Queue per `Printers_Forms.ps1 -Action Install` anlegen; ggf. Prefs sichern (`SavePrefs`).
- [ ] Geldgeräte (Phase 5): Dienst stoppen → `cctalkDevices.exe` (30–45 s) → Dienst starten; Recovery via `cctalk.exe` + 2× `moneysystemsettings` löschen.
- [ ] Edge/Policies (Phase 6): Popups/Assistenten aus; persistente Cookies (Terminal/Kasse) überprüfen.
