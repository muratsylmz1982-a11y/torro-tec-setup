# Ãœbergabe â€“ Torro Tec Setup & Management â€“ Produktion


**Datum:** <YYYY-MM-DD>
**Kontakt/Owner:** <Name, E-Mail>


## 1) Projektkontext (kurz)
- Zweck & Scope:
- GerÃ¤te & Rollen: Terminal (Kiosk), Kasse (Desktop)
- Kernpfad: `C:\Tiptorro`
- Shopâ€‘URL: https://shop.tiptorro.com


## 2) Aktueller Stand
- Letzte Schritte (Zeitstempel + kurze Beschreibung):
- Erreichte Meilensteine:


## 3) Offene Punkte (Next Actions)
- [ ] â€¦
- [ ] â€¦


## 4) Risiken/Blocker
- â€¦


## 5) Entscheidungen/Annahmen
- â€¦


## 6) Artefakte/Orte
- Repo/Branch: â€¦
- Logs: `C:\Tiptorro\logs\` (keine Credentials)
- Wichtige Skripte: `C:\Tiptorro\scripts\`


## 7) Wie starte ich lokal?
- PowerShell als Admin â†’ `docs/ops-playbook.md` folgen.


## 8) NÃ¤chste PrÃ¼fpunkte / Definition of Done

---

## BeispieleintrÃ¤ge (Stand 2025-09-10)
- [12:22] Star-Drucker eingerichtet: Queue **TT_Star**, Driver **Star TSP100 Cutter (TSP143)**, Port **USB007**, Test ASCII ok, als Standard gesetzt.
- TeamViewer: Policy importiert (`policies\TeamViewer_Settings.reg`), Service lÃ¤uft.
- DeviceManager: Dienst **DeviceManager.Bootstrapper** (Autostart), Fallback `net start/stop devicemanager` verifiziert.

## Offene Punkte (Next Actions â€“ Vorlage)
- [ ] Epson/Hwasung vor Ort anschlieÃŸen; Queue per `Printers_Forms.ps1 -Action Install` anlegen; ggf. Prefs sichern (`SavePrefs`).
- [ ] GeldgerÃ¤te (Phase 5): Dienst stoppen â†’ `cctalkDevices.exe` (30â€“45 s) â†’ Dienst starten; Recovery via `cctalk.exe` + 2Ã— `moneysystemsettings` lÃ¶schen.
- [ ] Edge/Policies (Phase 6): Popups/Assistenten aus; persistente Cookies (Terminal/Kasse) Ã¼berprÃ¼fen.
---

## Start here (fuer den naechsten Chat) – 2025-09-10
- Bitte NICHT neu aufsetzen. Lies zuerst README.md (Projektstand) und docs/ops-playbook.md (Phasen 3/4).
- Fuehre die Punkte unter "Offene Punkte / Next Actions" fort (Phase 5 Geldgeraete oder Phase 6 Edge/Policies).
- Falls Drucker-Themen: Star ist eingerichtet (TT_Star auf USB007). Epson/Hwasung nur gestaged (keine Queues).

## Anhaenge (bei Rueckfragen beilegen)
- README.md
- docs/ops-playbook.md
- docs/handover-template.md
- Relevante Logs aus C:\Tiptorro\logs\* (z. B. printers_forms_*.log, devicemanager_*.log, teamviewer_setup_*.log)
- Skripte unter C:\Tiptorro\scripts\*
