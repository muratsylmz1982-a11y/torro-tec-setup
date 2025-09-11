# START-HERE.md (Handover Kurzleitfaden)

**Stand:** 2025‑09‑11

> **Wichtig:** Bitte **keine bestehenden Phasen/Logiken ändern**, **außer** wenn es ausdrücklich beauftragt ist.
> Arbeiten (Tests, Deploy, Wartung) wie beschrieben **weiter durchführen**. Für Details siehe `docs/ops-playbook.md`.

---

## Zielbild (Terminal & Kasse)

* **Terminal (Kiosk):** Shop auf **Monitor 1**, LiveTV auf **Monitor 2** (falls vorhanden).
* **Kasse (Desktop):** Standard‑Desktopbetrieb mit Autostart.
* **Edge‑Popups:** komplett **aus** (Policies).
* **Profile:** dediziert in `C:\ttedge\{shop_*, livetv_*}`.
* **Root:** `C:\Tiptorro` mit `scripts/`, `packages/`, `logs/`, `state/`.

**Monitor 2 Vorgabe:** 1920×1080 bei 100 % Skalierung.

---

## TL;DR – Drei Schritte für ein frisches Gerät

1. **Drucker OneClick** (Star/Hwasung auto; Epson Fallback interaktiv):

```powershell
PowerShell -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Printers_Forms.ps1" -Action OneClick `
  -StarInf   "C:\Tiptorro\packages\printers\star\smjt100.inf" `
  -StarDriverName "Star TSP100 Cutter (TSP143)" `
  -HwasungInf "C:\Tiptorro\packages\printers\hwasung\HWASUNG_64bit_v400.INF" `
  -HwasungDriverName "HWASUNG HMK-072"
```

2. **Phase 8 OneClick** (Policies + Profile + Autostart; Popups aus):

```powershell
PowerShell -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\OneClick-Phase8.ps1" -PolicyScope Machine -SetAutostart
# Optional beim Erstsetup: LiveTV‑Auswahl jetzt treffen & speichern
# PowerShell -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\OneClick-Phase8.ps1" -PolicyScope Machine -SetAutostart -PromptLiveTV
```

3. **Support‑Erstwahl LiveTV** (falls nicht in Schritt 2 gemacht):

```powershell
PowerShell -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Start-LiveTV.ps1" -Prompt -MonitorIndex 2
```

**Neustartbetrieb:** Autostart startet Shop **Kiosk** (M1) & LiveTV **Kiosk** (M2) mit **gespeichertem Link**.

---

## Was bereits erledigt ist (nicht anfassen)

* **Phase 5 (Geldgeräte):** Rescan/Recovery etabliert; Settings nach Backend‑Setup werden **automatisch neu erzeugt**.
* **Phase 6 (Edge/Policies):** FRE/Sign‑in/Sync/Autofill/Promos/Benachrichtigungen **aus**; Cookies‑Allowlist `https://shop.tiptorro.com`.
* **Assigned Access:** **nicht** im Einsatz (wir nutzen Edge‑Kiosk via Flags/Profiles).
* **Queue‑Namen:** Original‑Treibernamen (Legacy `TT_*` bleibt funktionsfähig).

> Wenn Änderungen benötigt werden, bitte Ticket/Beauftragung – sonst unverändert lassen.

---

## Kernskripte

* `scripts/Printers_Forms.ps1` – OneClick Drucker & Formulare (Star/Hwasung auto, Epson Fallback).
* `scripts/Start-ShopKiosk.ps1` – Shop: Support=Tab (M1), Betrieb=Kiosk (M1).
* `scripts/Start-LiveTV.ps1` – LiveTV immer Kiosk (standardmäßig M2); `-Prompt` für Auswahl; Persistenz unter `C:\Tiptorro\state\livetv.selected.json`.
* `scripts/LiveTV-SetLink.ps1` – Toolmaske zum Ändern des LiveTV‑Links; `-ApplyNow` startet LiveTV sofort neu.
* `scripts/Start-Maintenance.ps1` – Wartungsmodus (Shop Tab + Toolmaske).
* `scripts/OneClick-Phase8.ps1` – Policies (HKLM/HKCU), Profil‑Reset, Autostart‑Seeding, optional Erstwahl.

---

## Verifikation (Kernchecks)

```powershell
# Druck-Nachweis
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PrintService/Operational'; Id=307} -MaxEvents 3 |
  Select TimeCreated,Message

# Edge‑Policies (HKLM)
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' |
  Select HideFirstRunExperience,BrowserSignin,SyncDisabled

# Autostart‑.lnk vorhanden?
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" |
  Where-Object Name -like 'Torro *.lnk' | Select Name

# LiveTV‑Auswahl gespeichert?
Get-Content 'C:\Tiptorro\state\livetv.selected.json'
```

---

## Troubleshooting (Kurz)

* **Doppelte Tabs im Support:** `C:\ttedge\shop_support` löschen; `Start-ShopKiosk.ps1` erneut starten.
* **Edge‑Popups:** `OneClick-Phase8.ps1 -PolicyScope Machine` als Admin ausführen; Profile `C:\ttedge\*` frisch anlegen.
* **Monitor 2 fehlt:** Script versucht `/extend`; sonst Position auf Primär; Logs prüfen (`C:\Tiptorro\logs\`).

---

## Weiterführend

* **Details & Phasen:** `docs/ops-playbook.md`
* **Änderungen:** `docs/CHANGELOG.md`
* **README:** Projektüberblick, Pfade & Quickstart
