# scripts/LiveTV-SetLink.ps1
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Low")]
param(
  [switch]$Preview,                         # <- Preview-Alias für WhatIf
  [switch]$Root,
  [switch]$Desktop,
  [string]$TipRoot = 'C:\Tiptorro',
  [string]$IconPath = 'C:\Tiptorro\shortcuts\livetv.ico',
  [bool]$RequireSecondMonitor = $true,
  [string]$LogDir = "$env:ProgramData\TipTorro\Logs",
  [switch]$Replace
)

# Honor -Preview as WhatIf
if ($PSBoundParameters.ContainsKey('Preview')) { $WhatIfPreference = $true }

$ErrorActionPreference = 'Stop'
$script:LogFile    = $null
$script:HasFailure = $false

function Write-Log {
  param([string]$Message,[string]$Level='INFO')
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $line = "[{0}] [{1}] {2}" -f $ts,$Level,$Message
  Write-Host $line
  if($script:LogFile){ Add-Content -Path $script:LogFile -Value $line }
}

try {
  # Defaults: wenn nichts gewählt -> beide
  if(-not $PSBoundParameters.ContainsKey('Root') -and -not $PSBoundParameters.ContainsKey('Desktop')){
    $Root = $true; $Desktop = $true
  }

  # Log vorbereiten
  if(-not (Test-Path $LogDir)){ New-Item -ItemType Directory -Force $LogDir | Out-Null }
  $script:LogFile = Join-Path $LogDir ("livetv_setlink_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
  Write-Log ("Logfile: {0}" -f $script:LogFile)

  # Abhängigkeiten
  $CreateScript = Join-Path $TipRoot 'scripts\Create-LiveTV-Shortcut.ps1'
  $StartScript  = Join-Path $TipRoot 'scripts\Start-LiveTV.ps1'
  if(-not (Test-Path $CreateScript)){ throw "Missing: $CreateScript" }
  if(-not (Test-Path $StartScript)){  throw "Missing: $StartScript"  }

  # Signaturen nur protokollieren
  foreach($f in @($CreateScript,$StartScript)){
    try{
      $sig = Get-AuthenticodeSignature -FilePath $f
      Write-Log ("Signature {0}: {1}" -f $f, $sig.Status)
    }catch{
      Write-Log ("Signature check failed for {0}: {1}" -f $f,$_.Exception.Message) 'WARN'
    }
  }

  # Monitor prüfen
  Add-Type -AssemblyName System.Windows.Forms | Out-Null
  $hasSecond = [System.Windows.Forms.Screen]::AllScreens.Count -ge 2
  Write-Log ("Second monitor present: {0}" -f $hasSecond)

  # Ziele
  $RootLink = Join-Path $TipRoot 'livetv.lnk'
  $DeskPath = [Environment]::GetFolderPath('Desktop')
  $DeskLink = Join-Path $DeskPath 'LiveTV.lnk'

  function Ensure-Link {
    param([string]$TargetPath)
    $exists = Test-Path $TargetPath
    if($exists -and -not $Replace){
      Write-Log ("Skip (exists): {0}" -f $TargetPath)
      return
    }
    # kein ternärer Operator -> kompatibel
    if ($exists) { $action = 'Replace shortcut' } else { $action = 'Create shortcut' }

    if($PSCmdlet.ShouldProcess($TargetPath,$action)){
      $p = @{ ShortcutPath = $TargetPath }
      if(Test-Path $IconPath){ $p.IconPath = $IconPath } else { Write-Log ("Icon missing, continuing: {0}" -f $IconPath) 'WARN' }
      try{
        & $CreateScript @p
        Write-Log ("OK: {0}" -f $TargetPath)
      }catch{
        Write-Log ("FAIL {0}: {1}" -f $TargetPath, $_.Exception.Message) 'ERROR'
        $script:HasFailure = $true
      }
    }
  }

  if($Root){ Ensure-Link -TargetPath $RootLink }

  if($Desktop){
    if($RequireSecondMonitor -and -not $hasSecond){
      Write-Log "RequireSecondMonitor=True & only one monitor -> skipping Desktop link." 'WARN'
    } else {
      Ensure-Link -TargetPath $DeskLink
    }
  }

  # Exitcode: 0 ok, 1 Fehler, 3 nur Skip wg. Monitorbedingung
  $code = if($script:HasFailure){1} elseif($RequireSecondMonitor -and -not $hasSecond -and $Desktop){3} else {0}
  Write-Log ("ExitCode: {0}" -f $code)
  [Environment]::ExitCode = $code
}
catch {
  Write-Log ("Unhandled error: {0}" -f $_.Exception.Message) 'ERROR'
  [Environment]::ExitCode = 1
}
