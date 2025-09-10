# START-HERE.md (Handover Kurzanleitung) – 2025-09-10

Nicht neu bauen. Weiterfuehren ab Phase 5 (Geldgeraete) oder Phase 6 (Edge/Policies).
Vorher: README lesen (Projektstand), ops-playbook Phase 3/4 ueberfliegen, handover-template Offene Punkte.
Kurzcheck:
  Get-Printer | ? Name -like 'TT_*' | select Name,DriverName,PortName
  (Get-CimInstance Win32_Printer | ? Default).Name
Star ist eingerichtet: TT_Star (Driver 'Star TSP100 Cutter (TSP143)', Port 'USB007', Default).
Epson/Hwasung: nur gestaged, keine Queues.

Siehe:
- README.md – Abschnitt "Aktueller Projektstand (Kurz)" und "Wichtige Skripte & Pfade"
- docs/ops-playbook.md – Phasen 3/4 mit konkreten Befehlen
- docs/handover-template.md – Offene Punkte / Next Actions
