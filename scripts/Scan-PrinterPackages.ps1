# Torro Tec - Scan Printer Packages (v1, ASCII)
# Scannt Ordner rekursiv nach *.inf und erzeugt CSV + Summary + Log.

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string[]]$Paths
)

$ErrorActionPreference = 'Continue'
$Root   = 'C:\Tiptorro'
$LogDir = Join-Path $Root 'logs'
$ts     = Get-Date -Format yyyyMMdd_HHmmss
$csv    = Join-Path $LogDir ("printer_package_scan_" + $ts + ".csv")
$sum    = Join-Path $LogDir ("printer_package_scan_summary_" + $ts + ".txt")
$log    = Join-Path $LogDir ("printer_package_scan_" + $ts + ".log")

function Log($m){ ("{0} {1}" -f (Get-Date).ToString("o"), $m) | Tee-Object -FilePath $log -Append | Out-Null }

function Get-InfValue {
  param([string]$Text,[string]$Key)
  $rx = "(?im)^\s*" + [regex]::Escape($Key) + "\s*=\s*(.+)$"
  $m  = [regex]::Match($Text, $rx)
  if($m.Success){ return $m.Groups[1].Value.Trim() } else { return $null }
}

function Resolve-CatalogFile {
  param([string]$InfText,[string]$InfDir)
  $cat = Get-InfValue -Text $InfText -Key 'CatalogFile.NTamd64'
  if(-not $cat){ $cat = Get-InfValue -Text $InfText -Key 'CatalogFile' }
  if(-not $cat){ return [pscustomobject]@{ Path=$null; Exists=$false; Sig='Unknown' } }
  $catPath = Join-Path $InfDir $cat
  if(Test-Path $catPath){
    try{
      $sig = Get-AuthenticodeSignature -FilePath $catPath
      $status = $sig.Status.ToString()
      return [pscustomobject]@{ Path=$catPath; Exists=$true; Sig=$status }
    } catch {
      return [pscustomobject]@{ Path=$catPath; Exists=$true; Sig='Unknown' }
    }
  } else {
    return [pscustomobject]@{ Path=$catPath; Exists=$false; Sig='Missing' }
  }
}

function Scan-Inf {
  param([System.IO.FileInfo]$Inf)
  # Robust lesen
  $text = Get-Content $Inf.FullName -Raw -ErrorAction SilentlyContinue
  if(-not $text){ $text = Get-Content $Inf.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue }

  $class     = Get-InfValue -Text $text -Key 'Class'
  $classGuid = Get-InfValue -Text $text -Key 'ClassGUID'
  $provider  = Get-InfValue -Text $text -Key 'Provider'
  $mfg       = Get-InfValue -Text $text -Key 'Manufacturer'
  $driverVer = Get-InfValue -Text $text -Key 'DriverVer'

  $isPrinter = ($class -match '(?i)printer') -or ($classGuid -match '(?i)4d36e979-e325-11ce-bfc1-08002be10318')
  $hasAmd64  = ($text -match '(?im)^\s*\[.*NTamd64.*\]') -or ($text -match '(?i)amd64|x64')

  $catInfo   = Resolve-CatalogFile -InfText $text -InfDir $Inf.DirectoryName

  [pscustomobject]@{
    InfPath          = $Inf.FullName
    InfName          = $Inf.Name
    Class            = $class
    ClassGuid        = $classGuid
    IsPrinterClass   = $isPrinter
    ArchHasNTamd64   = $hasAmd64
    Provider         = $provider
    Manufacturer     = $mfg
    DriverVer        = $driverVer
    CatalogPath      = $catInfo.Path
    CatalogExists    = $catInfo.Exists
    CatalogSignature = $catInfo.Sig
  }
}

$rows = @()
foreach($p in $Paths){
  if(-not (Test-Path $p)){ Log "WARN: Path not found: $p"; continue }
  Log "Scanning: $p"
  $infs = Get-ChildItem $p -Recurse -Filter '*.inf' -File -ErrorAction SilentlyContinue
  if(-not $infs -or $infs.Count -eq 0){ Log "No INF found in: $p"; continue }
  foreach($inf in $infs){
    try { $rows += Scan-Inf -Inf $inf }
    catch { Log ("ERROR scanning " + $inf.FullName + ": " + $_.Exception.Message) }
  }
}

if($rows.Count -gt 0){
  $rows | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
  Log ("CSV written: " + $csv)
  $ok = $rows | Where-Object { $_.IsPrinterClass -and $_.ArchHasNTamd64 -and $_.CatalogExists -and ($_.CatalogSignature -match 'Valid') }
  $bad= $rows | Where-Object { -not ($_.IsPrinterClass -and $_.ArchHasNTamd64 -and $_.CatalogExists) }

  @(
    '=== SUMMARY ===',
    'OK entries: ' + $ok.Count,
    'Problem entries: ' + $bad.Count,
    '',
    'OK list:',
    ($ok  | Select-Object InfName,Manufacturer,Provider,DriverVer,ArchHasNTamd64,CatalogSignature | Format-Table | Out-String),
    'Problem list:',
    ($bad | Select-Object InfName,Manufacturer,Provider,DriverVer,IsPrinterClass,ArchHasNTamd64,CatalogExists,CatalogSignature | Format-Table | Out-String)
  ) | Set-Content -Path $sum -Encoding UTF8
  Log ("Summary written: " + $sum)
} else {
  Log 'No INF files found in any provided path.'
}

Log 'Scan complete.'
