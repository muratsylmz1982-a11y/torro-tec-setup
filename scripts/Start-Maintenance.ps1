# Shop als Tab (Support)
Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
  -ArgumentList @("-ExecutionPolicy","Bypass","-File","C:\Tiptorro\scripts\Start-ShopKiosk.ps1") `
  -WindowStyle Hidden

# LiveTV-Toolmaske öffnen, Auswahl speichern und sofort anwenden (Monitor 2 bleibt Kiosk)
Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
  -ArgumentList @("-ExecutionPolicy","Bypass","-File","C:\Tiptorro\scripts\LiveTV-SetLink.ps1","-ApplyNow","-MonitorIndex","2") `
  -NoNewWindow
