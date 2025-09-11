# Changelog


## [Unreleased]
### Added
- `scripts/Printers_Forms.ps1`: ASCII-Test, Custom-Forms (Admin), gezielte Installation nur erkannter Drucker.
- `scripts/Scan-PrinterPackages.ps1`: INF-Prüfer (Klasse/Architektur/Katalog/Signatur).
- Doku-Erweiterungen: README „Aktueller Projektstand“ & „Wichtige Skripte & Pfade“, ops-playbook Phase 4 konkretisiert, handover-Template Beispiele.
### Added
- Phase 5 (Geldgeräte): Rescan/Recovery dokumentiert; Service `DeviceManager.Bootstrapper`; ToolsPath `C:\Tiptorro\packages\cctalk`; Tool **ccTalk Devices.exe**; Settings-Dateien (`moneysystem_settings*.xml`) vermerkt.
- Phase 6 (Edge/Policies): Policies gesetzt (`DefaultPopupsSetting=2`, `HideFirstRunExperience=1`, `DefaultCookiesSetting=1`, `ClearBrowsingDataOnExit=0`, `BlockThirdPartyCookies=0`) inkl. Allowlist `https://shop.tiptorro.com`.

### Changed
- README/ops-playbook/handover/start-here um Phase-5/6-Umsetzung & Nachweise erweitert.

### Fixed
- Edge-Policy-Duplikat/Leereintrag bereinigt (Unknown Policy entfernt); Anzeige in `edge://policy` nun vollständig **OK**.

### Changed
- DeviceManager-Playbook: Dienstname **DeviceManager.Bootstrapper** + Fallback `net start/stop devicemanager` ausdrücklich dokumentiert.


## [Unreleased]
### Changed
- `Printers_Forms.ps1` **OneClick**: Star/Hwasung werden automatisch mit **Original-Treibernamen** installiert.
  Nur wenn **kein** Star/Hwasung erkannt wird: interaktive **Epson**-Installation (Modellwahl **TM-T88V**/**TM-T88IV**) direkt �ber die EXE unter `C:\Tiptorro\packages\printers\epson\installer`.
  Danach **Testseite** & **Standarddrucker**.

### Added
- Doku: Quickstart �OneClick� und Hinweis auf Queue-Namen (Original statt `TT_*`).
<!-- Marker: OneClick: Original-Treibernamen + Epson via EXE -->
