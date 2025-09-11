<# 
 Create-LiveTV-Shortcut.ps1
 Erstellt C:\Tiptorro\livetv.lnk, das Start-LiveTV.ps1 ausführt.
#>

param(
    [string]$ShortcutPath = "C:\Tiptorro\livetv.lnk",
    [string]$IconPath     = "C:\Tiptorro\shortcuts\livetv.ico"
)
$ErrorActionPreference = "Stop"
$targetPs1 = 'C:\Tiptorro\scripts\Start-LiveTV.ps1'
if (!(Test-Path $targetPs1)) { throw "Erwarte $targetPs1 – bitte Datei dorthin kopieren." }
$target = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$args   = "-ExecutionPolicy Bypass -File `"$targetPs1`""
$wsh = New-Object -ComObject WScript.Shell
$sc = $wsh.CreateShortcut($ShortcutPath)
$sc.TargetPath  = $target
$sc.Arguments   = $args
if (Test-Path $IconPath) { $sc.IconLocation = $IconPath }
$sc.WorkingDirectory = 'C:\Tiptorro\scripts'
$sc.Save()
Write-Host "Shortcut erstellt: $ShortcutPath"
