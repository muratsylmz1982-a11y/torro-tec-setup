## [2025-09-12] Panel-UX, LiveTV-Flow, DeviceManager-Fallback (PS 5.1-Kompatibilität)

### Added
- **Panel/Log-Konsole:** Persistente Log-Ausgabe am unteren Rand; alle Aktionen schreiben nun konsistente Zeitstempel-Einträge (z. B. „Panel gestartet – Log bereit.“).
- **DeviceManager-Installer (Admin):** Neuer Fallback: bevorzugt `DeviceManager.Service.Setup.msi`, sonst `DeviceManager.msi`, ansonsten `setup.exe`; Start **elevated** und mit `/qn` bzw. Silent-Setup.
- **LiveTV-Persistenz & Prompt im OneClick-Flow:** Panel triggert `OneClick-Phase8.ps1` mit `-PromptLiveTV -SetAutostart -MonitorIndex 2`; Auswahl wird unter `C:\Tiptorro\state\livetv.selected.json` gespeichert und beim Start genutzt.

### Changed
- **Terminal-Tab Layout (4 Reihen, übersichtlich):**
  1) OneClick Setup (Phase 8, Admin) · Maintenance öffnen · Geldgeräte-Assistent  
  2) Start LiveTV (Monitor 2) · Shop (normal, kein Kiosk) · **LiveTV jetzt starten**  
  3) DeviceManager installieren/aktualisieren (Admin) · DeviceManager: Start · DeviceManager: Stop  
  4) HealthCheck ausführen · Audit Signatures
- **LiveTV-Sektion (Robuster UI-Code):** ComboBox-Befüllung + Labels („URL: …“, „Auswahl …“) sauber initialisiert; Monitorauswahl als NumericUpDown.
- **OneClick-Anbindung:** Panel ruft Phase 8 nun direkt mit den oben genannten Parametern auf (Prompt für Link-Wahl, Autostart-Seeding, Monitor 2).
- **PS 5.1-Kompat:** Ternary-Operator `? :` entfernt; Dateiauswahl & OR-Logik in klassischen `if/else` umgesetzt.

### Fixed
- **NullRef beim Laden der Links-JSON:** `$cmb.Items.Clear()` und anschließendes Füllen laufen jetzt gegen das richtige Control-Objekt; kein „Methode auf NULL“ mehr.
- **Label-Property-Fehler („.Text nicht gefunden“):** Labels aus `Add-Label` werden gehalten und aktualisiert, nicht neu erstellt/überschrieben.
- **DeviceManager-Installationsblock:** `if ((Test-Path $msi) -or (Test-Path $alt)) { … }` + saubere Zuweisung `$use = if (Test-Path $msi) { $msi } else { $alt }` → keine `Test-Path -or`/Parser-Fehler mehr.
- **Button-Positionen:** „LiveTV jetzt starten“ und „Auswahl speichern“ kollidieren nicht mehr; DeviceManager-Buttons sichtbar und klickbar.
- **Logs sichtbar:** TextBox-Größe/Anchoring korrigiert – neue Einträge werden zuverlässig angezeigt.

### Docs
- **ops-playbook.md**: heutige Flows (Panel-UX, OneClick-Verkabelung, LiveTV-Persistenz, Admin-Hinweis für DM/Printer) ergänzt. Siehe „Details & Phasen“. :contentReference[oaicite:2]{index=2}
- **START-HERE.md**: Kernskripte & Speicherpfad der LiveTV-Auswahl verlinkt/erklärt. :contentReference[oaicite:3]{index=3}
- **Ablage/Logs**: Verweise auf `C:\Tiptorro\logs\…` und `state\livetv.selected.json` ergänzt (Struktur bestätigt). :contentReference[oaicite:4]{index=4} :contentReference[oaicite:5]{index=5}


## \[Unreleased]

### Added

* Platzhalter für zukünftige Erweiterungen (Phase 9–11 Feinjustage, HealthCheck, zusätzliche Tools).
* **Phase 9 – Shortcuts & Autostart (ergänzend):** Manuelle Shortcuts für **LiveTV (Monitor 2)** auf **Public Desktop** und **C:\Tiptorro\livetv.lnk**; **Torro Maintenance**-Shortcut. Autostart nur **prüfen/sicherstellen**, nichts Überschreiben bestehender Logik.
* **Fallback ohne Admin:** Erstellung auf Benutzer-Desktop mit anschließendem Kopieren nach `C:\Users\Public\Desktop`.
### Changed

- HealthCheck: Auswertung „unterstützte Drucker: 0/1/>1“ mit klaren Meldungen.

### Fixed
* Versehentliche Nutzung der reservierten PowerShell-Variable `$args` bei Shortcut-Erstellung vermieden (Parameter heißt nun `$Arguments`).
* —

### Docs

* **ops-playbook:** Phase-9-Kapitel deutlich erweitert (Funktion `New-Shortcut`, Kasse/Terminal-Hinweise, Verifikation).
* **README:** Hinweis ergänzt, dass Kassen-Rollen i. d. R. nur **manuelle** Shortcuts nutzen (Autostart optional entfernen).

---

## \[2025-09-11] Phase 8 – Kiosk/Support final (ohne Edge‑Popups)

### Added
- Panel: Tabs **Terminal** & **Kasse** mit getrennten One-Click-Flows.
- Drucker-Setup auf **Erkennung zuerst** umgestellt (nur tatsächlich vorhandenes Modell wird installiert).


* **Skripte**

  * `scripts/Start-ShopKiosk.ps1` – Shop: Support=Tab (M1), Betrieb=Kiosk (M1), dediziertes Profil.
  * `scripts/Start-LiveTV.ps1` – LiveTV **immer Kiosk** (standardmäßig M2), optional `-Prompt`, Persistenz.
  * `scripts/LiveTV-SetLink.ps1` – Wartungs-Toolmaske (Link wählen/speichern), optional `-ApplyNow`.
  * `scripts/Start-Maintenance.ps1` – Wartungsworkflow (Shop Tab + LiveTV-Toolmaske).
  * `scripts/OneClick-Phase8.ps1` – **Policies (HKLM/HKCU)**, **Profil-Reset** (`C:\ttedge\*`), **Autostart-Seeding** (Benutzer-Startup), optional Erstwahl (`-PromptLiveTV`).
* **Persistenz**: `C:\Tiptorro\state\livetv.selected.json` speichert die getroffene LiveTV-Auswahl.
* **Autostart** (Benutzer):

  * `Torro Shop Kiosk.lnk` → `Start-ShopKiosk.ps1 -Mode Kiosk`
  * `Torro LiveTV Kiosk.lnk` → `Start-LiveTV.ps1 -MonitorIndex 2`
* **Snapshots/Logs**: `C:\Tiptorro\logs\phase8_*.txt` (Policies & Monitore), Monitor‑Snapshot für Tickets.

### Changed

* **Betriebsverhalten (final):**

  * **Support:** Shop **Tab** (M1), LiveTV **Kiosk** (M2) → Auswahl via Prompt; Speicherung in `state\livetv.selected.json`.
  * **Neustart/Betrieb:** Shop **Kiosk** (M1), LiveTV **Kiosk** (M2) → Startet mit **gespeichertem Link** (keine Nachfrage).
  * **Wartung:** Shop als Tab (M1) + LiveTV‑Toolmaske; `-ApplyNow` startet LiveTV sofort neu (Kiosk, M2).
* **Edge‑Hardening:** First‑Run/Signin/Sync/Autofill/Benachrichtigungen/Promo abgeschaltet; Cookies‑Allowlist für `https://shop.tiptorro.com`.

### Fixed

* Sporadische doppelte Tabs im Support durch **frische Profile** (`C:\ttedge\shop_support`) und deaktivierte Startup‑Restore‑Mechanik.
* Edge‑Popups (FRE/Sign‑in/Sync) dauerhaft entfernt via Policy + Profilbereinigung.

### Docs

* `docs/ops-playbook.md`: Phase‑8 Ablauf, Tests & Verifikation, Troubleshooting.
* `START-HERE.md`: Kurzpfad (OneClick‑Phase8 + optionaler Prompt).
* `README.md`: Projektstand, Skriptüberblick, Pfade.

---

## \[2025-09-10] Phase 6 – Edge/Policies (Popups aus, Cookies erlaubt)

### Added

* **Policy‑Baseline** unter `HKLM\SOFTWARE\Policies\Microsoft\Edge` (HKCU‑Fallback):

  * `HideFirstRunExperience=1`, `BrowserSignin=0`, `SyncDisabled=1`
  * `DefaultNotificationsSetting=2`, `DefaultGeolocationSetting=2`
  * `PasswordManagerEnabled=0`, `AutofillAddressEnabled=0`, `AutofillCreditCardEnabled=0`
  * `PromotionalTabsEnabled=0`, `RestoreOnStartup=0`
  * `CookiesAllowedForUrls = https://shop.tiptorro.com`

### Changed

* Policies in `edge://policy` validiert; unbekannte/obsolete Einträge entfernt.

### Fixed

* Erststart‑Assistent, Sign‑in/Sync‑Dialoge und Promo‑Tabs erscheinen nicht mehr.

### Docs

* `ops-playbook` Phase 6 ergänzt (Ablauf + Verifikation), README aktualisiert.

---

## \[2025-09-09] Phase 5 – Geldgeräte (Rescan/Recovery)

### Added

* **Rescan/Recovery Flow** dokumentiert: Dienst **DeviceManager.Bootstrapper** stoppen → `ccTalk Devices.exe` → starten.
* **Recovery:** `moneysystem_settings*.xml` löschen → `ccTalk Devices.exe` → Dienst starten.

### Changed

* Hinweis: Settings‑Dateien werden **nach Backend‑Setup automatisch neu erzeugt** (kein manuelles Anlegen).

### Docs

* `ops-playbook` Phase 5 + Hinweise in README.

---

## \[2025-09-08] Phase 4 – Drucker & Formulare & OneClick

### Added

* `scripts/Printers_Forms.ps1`: ASCII‑Test, Custom‑Forms (Admin), gezielte Installation nur erkannter Drucker.
* `scripts/Scan-PrinterPackages.ps1`: INF‑Prüfer (Klasse/Architektur/Katalog/Signatur).

### Changed

* **OneClick**: Star/Hwasung werden automatisch mit **Original‑Treibernamen** installiert.
  Fallback: interaktive **Epson**‑Installation (Modelle **TM‑T88V/TM‑T88IV**) aus `packages\printers\epson\installer\*.exe`, danach Testseite & Standarddrucker.

### Docs

* Playbook (Phase 4) konkretisiert; README/START‑HERE aktualisiert.

---

## \[2025-09-07] Strukturbereinigung & Baseline

### Added

* Ordnerstruktur `C:\Tiptorro\{scripts,packages,logs,state,shortcuts,docs}`.

### Changed

* Bezeichnungen/Queues vereinheitlicht: **Original‑Treibernamen** bevorzugt, Legacy `TT_*` weiterhin kompatibel.

### Docs

* Erste README‑Fassung und Playbook‑Skeleton.
### Notes
- Epson weiterhin via EXE-Installer (UI), kein INF.
- DESKO/Datawin bleiben optionale Schritte im Kasse-Profil.