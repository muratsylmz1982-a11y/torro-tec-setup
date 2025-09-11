# Changelog

Dieses Changelog folgt einem einfachen Schema (Added/Changed/Fixed/Docs). Datum im Format **YYYY-MM-DD**.
Siehe auch: `docs/ops-playbook.md`, `START-HERE.md`.

---

## \[Unreleased]

### Added

* Platzhalter für zukünftige Erweiterungen (Phase 9–11 Feinjustage, HealthCheck, zusätzliche Tools).

### Changed

* —

### Fixed

* —

### Docs

* —

---

## \[2025-09-11] Phase 8 – Kiosk/Support final (ohne Edge‑Popups)

### Added

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
