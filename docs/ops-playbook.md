TipTorro – Setup & Operations Playbook

Stand: aktuell, Windows 10/11, reine Offline-Tauglichkeit. Rollen: Terminal (Kiosk + Geldgeräte) und Kasse (Desktop, ohne Geldgeräte).

0) Überblick & Voraussetzungen

Adminrechte erforderlich (PowerShell „Als Administrator“).

Lokale Pakete vorhanden unter C:\Tiptorro\packages\…

Alle Skripte unter C:\Tiptorro\scripts\…

Logs unter C:\Tiptorro\logs\…

Zweiter Monitor (TV) wird, wenn angeschlossen, für LiveTV (1920×1080 @ 100 %) genutzt.

Links für LiveTV liegen in C:\Tiptorro\links.json (bzw. Symlink auf packages\LiveTvLinks\links.json).

Auswahl LiveTV wird persistent gespeichert in C:\Tiptorro\state\livetv.selected.json.

Schnellstart (Bedienoberfläche „Torro-Panel“)
Start-Process powershell.exe -Verb runas -ArgumentList `
  '-NoProfile -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Torro-Panel.ps1"'


Im Panel gibt es eigene Reiter für Setup, Terminal, Kasse, Status, Diagnostics, Security, Tools. Alle Hauptabläufe sind als Buttons verfügbar.

1) Einmal-Setup (One-Click) – empfohlene Reihenfolge
1.1 Terminal (Kiosk-System)

Panel öffnen (Admin) – siehe Befehl oben.

Reiter Terminal → „OneClick Setup (Phase 8, Admin)”

Fragt (bei erkannten 2 Monitoren) den gewünschten LiveTV-Link ab.

Speichert Auswahl nach state\livetv.selected.json.

Richtet Autostart für LiveTV/Shop (Shortcuts im Startup) ein, sofern gewünscht.

Startet LiveTV Test auf Monitor 2.

„Device Manager installieren/aktualisieren (Admin)”

Nutzt MSI (packages\device-manager\DeviceManager.Service.Setup.msi) oder setup.exe.

Startet Dienst DeviceManager.Bootstrapper.

Geldgeräte (optional jetzt/sonst später)

„Geldgeräte-Assistent (ccTalk)” → MoneyDevices.ps1 bzw. ccTalk Devices.exe.

Prüfen: Status-Reiter (Health/Audit), LiveTV startet, Shop öffnet im Kiosk (bei Bedarf über Button).

1.2 Kasse (Desktop-System)

Panel öffnen (Admin).

Reiter Kasse → „OneClick Drucker (Star/Hwasung, sonst Epson)”

Erkennung Star/Hwasung (Treiber aus lokalem Pool), sonst interaktiver Epson-Installer.

Setzt Standarddrucker und druckt Testseite.

TeamViewer Setup (Silent + Reg) (optional)

Desko/Datawin (optional)

LiveTV (ohne Kiosk) – „LiveTV im normalen Edge (ohne Kiosk)“ bei Bedarf.

2) OneClick – Details (Phase 8)

Skript: C:\Tiptorro\scripts\OneClick-Phase8.ps1

2.1 Typische Ausführung (Terminal)
powershell -NoProfile -ExecutionPolicy Bypass `
  -File "C:\Tiptorro\scripts\OneClick-Phase8.ps1" `
  -PromptLiveTV -SetAutostart -MonitorIndex 2


Was passiert:

Links laden (C:\Tiptorro\links.json), Auswahl dialogisch, Speichern nach C:\Tiptorro\state\livetv.selected.json.

LiveTV auf Monitor 2 testen (Start-LiveTV.ps1).

Autostart anlegen (User-Startup-Shortcuts „Torro LiveTV Kiosk.lnk“ und „Torro Shop Kiosk.lnk“).
Hinweis: Es kann alternativ ein Sched.Task Tiptorro-EdgeTV existieren – in aktuellen Builds nutzen wir bevorzugt die Startup-Links.

Edge-First-Run wird über Policies unterdrückt (separates Skript vorhanden).

Keine Speicherung von Shop-Credentials (nur Links/Kiosk).

2.2 Verifikation
# Auswahl
Test-Path 'C:\Tiptorro\state\livetv.selected.json'
Get-Content 'C:\Tiptorro\state\livetv.selected.json' -Raw

# Autostart
$me  = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
Get-ChildItem $me -Filter 'Torro *.lnk' | Select Name,FullName

# Kiosk-Probe
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Start-LiveTV.ps1" -MonitorIndex 2

3) Drucker-Workflow (Star/Hwasung auto, Epson interaktiv)

Skript: C:\Tiptorro\scripts\Printers_Forms.ps1

3.1 OneClick-Modus
powershell -NoProfile -ExecutionPolicy Bypass `
  -File "C:\Tiptorro\scripts\Printers_Forms.ps1" `
  -Action OneClick `
  -StarInf "C:\Tiptorro\packages\printers\star\smjt100.inf" `
  -StarDriverName "Star TSP100 Cutter (TSP143)" `
  -HwasungInf "C:\Tiptorro\packages\printers\hwasung\HWASUNG_64bit_v400.INF" `
  -HwasungDriverName "HWASUNG HMK-072" `
  -Verbose


Log/Ergebnis: C:\Tiptorro\logs\printers_forms_*.log

Erkennt angeschlossene Star/Hwasung via PnP/Win32_Printer.

Installiert Treiber via pnputil (Star/Hwasung), legt Queue mit Original-Treibername an.

Epson als Fallback: interaktiver Installer aus packages\printers\epson\installer\*.exe.

Setzt Standarddrucker und triggert Testseite.

Hinweise/Tipps:

Bei Star: INF (smjt100.inf) + Dateien müssen vollständig in packages\printers\star\ liegen.

Falls pnputil „Datei nicht gefunden“ meldet, trotz vorhandenem Pfad: erneut ausführen; bei Erfolg sieht man Published Name (z. B. oem96.inf).

Log zeigt Erkennung + Portwahl (USBxxx/ESDPRT).

Bei Problemen mit Erkennung: temporär manuell Queue anlegen, dann OneClick erneut (der OneClick setzt dann Standard/Testseite korrekt).

4) Device Manager – Installation, Dienst & Repair

Paketpfade:

C:\Tiptorro\packages\device-manager\DeviceManager.Service.Setup.msi (bevorzugt)

C:\Tiptorro\packages\device-manager\DeviceManager.msi (Fallback, wenn vorhanden)

C:\Tiptorro\packages\device-manager\setup.exe (als Alternative)

Dienstname: DeviceManager.Bootstrapper
Binärpfad: C:\Program Files (x86)\TipTorro\Device Manager Service\DeviceManager.Service.exe

4.1 Installation/Update (silent)
# MSI (bevorzugt)
Start-Process msiexec.exe -ArgumentList '/i "C:\Tiptorro\packages\device-manager\DeviceManager.Service.Setup.msi" /qn' -Wait -Verb runas
# Start
sc.exe start "DeviceManager.Bootstrapper"

4.2 Service-Steuerung/Diagnose
# Status
Get-Service 'DeviceManager.Bootstrapper' | Select Name,Status,StartType

# Start/Stop
sc.exe start "DeviceManager.Bootstrapper"
sc.exe stop  "DeviceManager.Bootstrapper"

# ImagePath prüfen
(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\DeviceManager.Bootstrapper').ImagePath

5) Kiosk & Shop

LiveTV Kiosk startet auf Monitor 2 über Start-LiveTV.ps1 und Edge-Flags.

Shop Kiosk (Terminal): Start-ShopKiosk.ps1 -Mode Kiosk

Shop normal (Kasse): Edge normal öffnen, Auto-Login vom Mitarbeiter.

Autostart (aktuell): per User-Startup-Shortcuts

Torro LiveTV Kiosk.lnk, Torro Shop Kiosk.lnk im %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup

Sched.Task Tiptorro-EdgeTV kann vorhanden sein; im aktuellen Stand ist der Startup-Ordner die bevorzugte Methode.

6) Health & Security
6.1 HealthCheck
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\HealthCheck.ps1" -Verbose


Log: C:\Tiptorro\logs\healthcheck_*.log

Status-Ampel im Panel: OK/WARN/ERROR + Zeitpunkt letzter Lauf.

6.2 Audit Signatures
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Audit-Signatures.ps1" -Verbose


CSV: C:\Tiptorro\logs\audit_signatures_*.csv

Panel zeigt Ampel „Security Audit“ inkl. Gesamtanzahl und „Bad (Bin)“.

7) LiveTV – Auswahl ändern & Neustart-Verhalten

Auswahl wird in C:\Tiptorro\state\livetv.selected.json gespeichert (Name/URL/Zeitstempel).

Ändern per Panel (Kasse-Reiter, Bereich „links.json neu laden / Auswahl speichern“), oder Datei austauschen.

Beim Neustart startet der zweite Monitor direkt im gewählten LiveTV-Link, wenn die Autostart-Links aktiv sind.

Nützliche Befehle:

# Auswahl anzeigen
Get-Content 'C:\Tiptorro\state\livetv.selected.json' -Raw

# Links-Datei öffnen
start C:\Tiptorro\links.json

8) TeamViewer (optional, Kasse/Terminal)

Installer: C:\Tiptorro\packages\teamviewer\TeamViewer_Setup.exe (Silent: /S)

Konfiguration: TeamViewer_Settings.reg / teamviewer-standard.reg importieren.

Start-Process "C:\Tiptorro\packages\teamviewer\TeamViewer_Setup.exe" -ArgumentList '/S' -Wait
reg import "C:\Tiptorro\packages\teamviewer\TeamViewer_Settings.reg"

9) Geldgeräte (Terminal)

Button „Geldgeräte-Assistent (ccTalk)“ im Reiter Terminal.

Intern: C:\Tiptorro\packages\MoneyDevices.ps1 oder packages\cctalk\ccTalk Devices.exe

Typischer Ablauf: Service stoppen → Erkennung → ggf. Reset („moneysystemsettings“ löschen) → Service starten → Geräte im Shop neu konfigurieren.

10) Troubleshooting – Kurzreferenz

A) LiveTV startet nach Neustart nicht

Prüfen: state\livetv.selected.json vorhanden & gültig.

Prüfen: %APPDATA%\...\Startup enthält „Torro LiveTV Kiosk.lnk“.

Test: Start-LiveTV.ps1 -MonitorIndex 2 manuell.

B) Zweiter Monitor erkannt, aber falsche Anzeige

Windows Anzeigeeinstellungen: Monitor 2 = 1920×1080 @ 100 %.

Edge-Fenster ggf. minimiert → per Alt+Tab prüfen.

C) DeviceManager Dienst startet nicht

Als Admin neu installieren (MSI).

Eventlog „Service Control Manager“ sichten.

sc.exe query "DeviceManager.Bootstrapper" prüfen.

D) Star/Hwasung nicht erkannt

printers_forms_*.log lesen (zeigt PnP & Win32-Queues).

pnputil /add-driver "<voller INF-Pfad>" /install erneut ausführen.

Danach Get-PrinterDriver | ? Name -match 'Star|Hwasung'.

E) Panel-Log unten leer

Buttons „Health/Audit jetzt“ ausführen → Ampel aktualisieren.

„Status aktualisieren“ klicken (Timer läuft alle 30 s).

11) Abnahmekriterien
Terminal

LiveTV-Link gewählt, gespeichert, startet nach Neustart auf Monitor 2.

Shop Kiosk startbar.

DeviceManager-Dienst Running, Autostart = Automatic.

Geldgeräte-Assistent öffnet (ccTalk/MoneyDevices).

Health/Audit im Panel Green oder begründete Yellow.

Kasse

Drucker OneClick hat den vorhandenen (Star/Hwasung) installiert, Standard gesetzt, Testseite gedruckt.
(Falls nur Epson: interaktiver Installer geöffnet, Installation erfolgreich, Testseite möglich.)

TeamViewer optional eingerichtet (Silent+Reg).

LiveTV ohne Kiosk startbar.

Health/Audit OK.

12) Nützliche Befehle (Copy-Paste)
# Panel starten (Admin)
Start-Process powershell.exe -Verb runas -ArgumentList `
 '-NoProfile -ExecutionPolicy Bypass -File "C:\Tiptorro\scripts\Torro-Panel.ps1"'

# OneClick Phase 8 (Terminal)
powershell -NoProfile -ExecutionPolicy Bypass `
 -File "C:\Tiptorro\scripts\OneClick-Phase8.ps1" -PromptLiveTV -SetAutostart -MonitorIndex 2

# LiveTV sofort auf Monitor 2
powershell -NoProfile -ExecutionPolicy Bypass `
 -File "C:\Tiptorro\scripts\Start-LiveTV.ps1" -MonitorIndex 2

# DeviceManager Dienst
Get-Service DeviceManager.Bootstrapper | fl Name,Status,StartType
sc.exe start "DeviceManager.Bootstrapper"
sc.exe stop  "DeviceManager.Bootstrapper"

# Drucker OneClick
powershell -NoProfile -ExecutionPolicy Bypass `
 -File "C:\Tiptorro\scripts\Printers_Forms.ps1" -Action OneClick `
 -StarInf "C:\Tiptorro\packages\printers\star\smjt100.inf" `
 -StarDriverName "Star TSP100 Cutter (TSP143)" `
 -HwasungInf "C:\Tiptorro\packages\printers\hwasung\HWASUNG_64bit_v400.INF" `
 -HwasungDriverName "HWASUNG HMK-072" -Verbose

13) Struktur & Pfade (Kurz)
C:\Tiptorro\
  scripts\
    Torro-Panel.ps1
    OneClick-Phase8.ps1
    Start-LiveTV.ps1
    Start-ShopKiosk.ps1
    Start-Maintenance*.ps1
    Printers_Forms.ps1
    HealthCheck.ps1
    Audit-Signatures.ps1
    ...
  packages\
    device-manager\*.msi|setup.exe
    printers\
      star\ (smjt100.inf + DLLs)
      hwasung\ (INF + CAT)
      epson\installer\*.exe
    teamviewer\*.exe|*.reg
    cctalk\*.exe
    desko\*.exe
    datawin\*.exe
  logs\ *.log / *.csv
  state\ livetv.selected.json
  links.json  (oder Symlink -> packages\LiveTvLinks\links.json)

14) Bekannte Punkte & Empfehlungen

Star-Treiber (pnputil): Meldung „Datei nicht gefunden“ kann sporadisch auftreten; bei erneutem Aufruf i. d. R. erfolgreich. Danach ist oemXX.inf sichtbar.

Edge First-Run: via bereitgestellter Policies unterdrückt; Popups/Assistenten sind im Normalfall weg.

Autostart-Methode: Startup-Ordner (derzeit bevorzugt) ist durchschaubar und leicht prüfbar.

Admin-Kontext sicherstellen: Panel/OneClick/Driver-Install immer „Als Administrator“.

Ende Playbook.

