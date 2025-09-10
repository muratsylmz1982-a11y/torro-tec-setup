# Torro Tec - Printer & Forms Helper (v1.2 ASCII)

[CmdletBinding()]
param(
  [ValidateSet('Detect','AddForms','Install','TestASCII','SavePrefs','LoadPrefs')]
  [string]$Action = 'Detect',
  [string[]]$Targets = @(),
  [switch]$InstallIfDetected = $true,
  [string]$StarInf,
  [string]$EpsonInf,
  [string]$HwasungInf,
  [string]$StarDriverName,
  [string]$EpsonDriverName,
  [string]$HwasungDriverName,
  [string]$StarPort,
  [string]$EpsonPort,
  [string]$HwasungPort,
  [string]$PrinterName
)

$Root  = 'C:\Tiptorro'
$LogDir= Join-Path $Root 'logs'
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$Log   = Join-Path $LogDir ('printers_forms_' + $Action + '_' + (Get-Date -Format yyyyMMdd_HHmmss) + '.log')
function Log($m){ ('{0} {1}' -f (Get-Date).ToString('o'), $m) | Tee-Object -FilePath $Log -Append | Out-Null }

function Detect-Printers {
  $det = [ordered]@{ Star=$false; Epson=$false; Hwasung=$false; Raw=@() }
  try{
    $pnp = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { $_.PNPClass -eq 'Printer' -or $_.ClassGuid -eq '{4d36e979-e325-11ce-bfc1-08002be10318}' }
    $win = Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue
    $all = @()
    if($pnp){ $all += $pnp | Select-Object @{n='Source';e={'PnP'}}, Name, Manufacturer, HardwareID }
    if($win){ $all += $win | Select-Object @{n='Source';e={'Win32_Printer'}}, Name, @{n='Manufacturer';e={$_.DriverName}}, @{n='HardwareID';e={$null}} }
    foreach($i in $all){
      $name = (''+$i.Name); $man = (''+$i.Manufacturer); $hid = ($i.HardwareID -join ';')
      $det.Raw += [pscustomobject]@{ Source=$i.Source; Name=$name; Manufacturer=$man; HardwareID=$hid }
      if($name -match '(?i)\bstar\b|TSP|mC-Print' -or $man -match '(?i)\bstar\b'){ $det.Star = $true }
      if($name -match '(?i)\bepson\b|TM\-'        -or $man -match '(?i)\bepson\b'){ $det.Epson = $true }
      if($name -match '(?i)hwasung|hs\-printer'   -or $man -match '(?i)hwasung'){   $det.Hwasung = $true }
    }
  } catch {}
  return $det
}
function Dump-Detections($det){
  Log ('Detected Star:    ' + $det.Star)
  Log ('Detected Epson:   ' + $det.Epson)
  Log ('Detected Hwasung: ' + $det.Hwasung)
  foreach($r in $det.Raw){ Log (' - ['+$r.Source+'] '+$r.Name+' | '+$r.Manufacturer+' | '+$r.HardwareID) }
}

function Ensure-Form {
  param([string]$Name,[int]$Wmm,[int]$Hmm,[int]$MarginMm=0)
  $key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Print\Forms\' + $Name
  if(-not (Test-Path $key)){ New-Item -Path $key -Force | Out-Null }
  New-ItemProperty -Path $key -Name 'FormName' -Value $Name -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $key -Name 'Flags'    -Value 0    -PropertyType DWord  -Force | Out-Null
  [UInt32]$w=[UInt32]($Wmm*1000); [UInt32]$h=[UInt32]($Hmm*1000); [UInt32]$m=[UInt32]($MarginMm*1000)
  $sizeBytes =  [BitConverter]::GetBytes($w) + [BitConverter]::GetBytes($h)
  $imgBytes  =  [BitConverter]::GetBytes($m) + [BitConverter]::GetBytes($m) + [BitConverter]::GetBytes($w-$m) + [BitConverter]::GetBytes($h-$m)
  New-ItemProperty -Path $key -Name 'Size'          -Value $sizeBytes -PropertyType Binary -Force | Out-Null
  New-ItemProperty -Path $key -Name 'ImageableArea' -Value $imgBytes  -PropertyType Binary -Force | Out-Null
  Log ('Form ensured: ' + $Name + ' ('+$Wmm+'x'+$Hmm+' mm)')
}

function Ensure-DriverFromInf { param([string]$InfPath)
  if(-not $InfPath){ return }
  if(-not (Test-Path $InfPath)){ throw 'INF not found: ' + $InfPath }
  Log ('Installing driver from INF: ' + $InfPath)
  Start-Process pnputil.exe -ArgumentList ('/add-driver "'+$InfPath+'" /install') -Wait -NoNewWindow
}

function Ensure-Printer { param([string]$PrinterName,[string]$DriverName,[string]$PortName)
  if(-not $PrinterName -or -not $DriverName -or -not $PortName){ return }
  $p = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
  if($p){ Log ('Printer exists: ' + $PrinterName); return }
  $drv = Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue
  if(-not $drv){ Log ('WARN: Driver not found in system: ' + $DriverName) }
  if(-not (Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue)){
    try { Add-PrinterPort -Name $PortName -PrinterHostAddress $PortName | Out-Null } catch {}
  }
  Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $PortName -ErrorAction Stop | Out-Null
  Log ('Printer created: ' + $PrinterName + ' (Driver=' + $DriverName + ', Port=' + $PortName + ')')
}

function Save-PrinterPrefs { param([string]$Name)
  $dat = Join-Path 'C:\Tiptorro\policies' ($Name + '_prefs.dat')
  Log ('Saving prefs to ' + $dat)
  Start-Process rundll32.exe -ArgumentList ('printui.dll,PrintUIEntry /Sr /n "'+$Name+'" /a "'+$dat+'" m f g p r e') -Wait
}
function Load-PrinterPrefs { param([string]$Name)
  $dat = Join-Path 'C:\Tiptorro\policies' ($Name + '_prefs.dat')
  if(-not (Test-Path $dat)){ throw 'Prefs file not found: ' + $dat }
  Log ('Loading prefs from ' + $dat)
  Start-Process rundll32.exe -ArgumentList ('printui.dll,PrintUIEntry /Ss /n "'+$Name+'" /a "'+$dat+'" m f g p r e') -Wait
}

function Test-ASCIIPrint { param([string]$Name)
  if(-not $Name){ throw 'Please provide -PrinterName for TestASCII' }
  $tmp = Join-Path $env:TEMP ('tt_ascii_' + [guid]::NewGuid().Guid + '.txt')
  @(
    'Torro Tec - ASCII Test',
    'This is a printable ASCII-only receipt line.',
    'Numbers: 0 1 2 3 4 5 6 7 8 9',
    'Punctuation: . , ; : ! ? ( ) [ ] { } + - * / = < >',
    '-- END --'
  ) | Set-Content -Path $tmp -Encoding ASCII
  Log ('Printing test file ' + $tmp + ' to ' + $Name)
  Get-Content $tmp | Out-Printer -Name $Name
}

Log ('=== Printers_Forms ' + $Action + ' START ===')
$det = Detect-Printers
Dump-Detections -det $det

switch($Action){
  'Detect' { Log 'Detection complete.' }
  'AddForms' {
    Ensure-Form -Name 'TT_Star_72mm'     -Wmm 72 -Hmm 200
    Ensure-Form -Name 'TT_Epson_80x297'  -Wmm 80 -Hmm 297
    Ensure-Form -Name 'TT_Hwasung_80x400'-Wmm 80 -Hmm 400
    Log 'Custom forms added. If not visible immediately, restart the Spooler.'
  }
  'Install' {
    if($Targets.Count -eq 0){ Log 'No Targets specified -> nothing to install.'; break }
    if($Targets -contains 'Star'){
      if($det.Star -and $InstallIfDetected){
        Ensure-DriverFromInf -InfPath $StarInf
        Ensure-Printer -PrinterName 'TT_Star' -DriverName $StarDriverName -PortName $StarPort
      } else { Log 'Star not detected or InstallIfDetected=false -> skipping.' }
    }
    if($Targets -contains 'Epson'){
      if($det.Epson -and $InstallIfDetected){
        Ensure-DriverFromInf -InfPath $EpsonInf
        Ensure-Printer -PrinterName 'TT_Epson' -DriverName $EpsonDriverName -PortName $EpsonPort
      } else { Log 'Epson not detected or InstallIfDetected=false -> skipping.' }
    }
    if($Targets -contains 'Hwasung'){
      if($det.Hwasung -and $InstallIfDetected){
        Ensure-DriverFromInf -InfPath $HwasungInf
        Ensure-Printer -PrinterName 'TT_Hwasung' -DriverName $HwasungDriverName -PortName $HwasungPort
      } else { Log 'Hwasung not detected or InstallIfDetected=false -> skipping.' }
    }
    Log 'Install phase done.'
  }
  'TestASCII' {
    if(-not $PrinterName){ throw 'Please provide -PrinterName.' }
    Test-ASCIIPrint -Name $PrinterName
  }
  'SavePrefs' {
    if(-not $PrinterName){ throw 'Please provide -PrinterName.' }
    Save-PrinterPrefs -Name $PrinterName
  }
  'LoadPrefs' {
    if(-not $PrinterName){ throw 'Please provide -PrinterName.' }
    Load-PrinterPrefs -Name $PrinterName
  }
}

Log ('=== Printers_Forms ' + $Action + ' END ===')
