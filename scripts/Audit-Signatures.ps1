[CmdletBinding()]
param(
  [switch]$Recurse = $true,
  [switch]$IgnoreScripts = $true,
  [string[]]$Whitelist
)

$root = 'C:\Tiptorro'
$logs = Join-Path $root 'logs'
New-Item -ItemType Directory -Force $logs | Out-Null
$ts   = Get-Date -Format 'yyyyMMdd_HHmmss'
$csv  = Join-Path $logs "audit_signatures_$ts.csv"
$log  = Join-Path $logs "audit_signatures_$ts.log"

# Whitelist aus Datei laden, wenn kein Parameter übergeben wurde
$defaultWhitelist = Join-Path $root 'state\audit.whitelist.txt'
if(-not $Whitelist -and (Test-Path $defaultWhitelist)){
  $Whitelist = Get-Content $defaultWhitelist | Where-Object { $_ -and $_ -notmatch '^\s*#' }
}
function Test-Whitelisted([string]$p){
  foreach($pat in ($Whitelist | Where-Object { $_ })){
    if($p -like $pat){ return $true }
  }
  return $false
}

# Zieldateien sammeln + Filter anwenden
$files = Get-ChildItem $root -File -Recurse:$Recurse | Where-Object {
  $_.Extension -in '.ps1','.psm1','.exe','.dll','.msi'
} | Where-Object {
  -not (Test-Whitelisted $_.FullName) -and @(
    $false -eq $IgnoreScripts -or ($_.Extension -notin '.ps1','.psm1')
  )[0]
}

# Prüfen
$results = foreach($f in $files){
  try{
    $sig = Get-AuthenticodeSignature -FilePath $f.FullName
    $signer   = if($sig -and $sig.SignerCertificate){ $sig.SignerCertificate.Subject } else { '-' }
    $notAfter = if($sig -and $sig.SignerCertificate){ $sig.SignerCertificate.NotAfter } else { $null }
    $hash = Get-FileHash -Path $f.FullName -Algorithm SHA256
    [pscustomobject]@{
      Path        = $f.FullName
      Name        = $f.Name
      Ext         = $f.Extension.ToLower()
      SizeBytes   = $f.Length
      SHA256      = $hash.Hash
      SignStatus  = $sig.Status
      Signer      = $signer
      NotAfter    = $notAfter
    }
  }catch{
    [pscustomobject]@{
      Path=$f.FullName; Name=$f.Name; Ext=$f.Extension.ToLower(); SizeBytes=$f.Length
      SHA256='-'; SignStatus='Error'; Signer='-'; NotAfter=$null
    }
  }
}

# CSV & Log
$results | Sort-Object Ext, Name | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8 -Force
$unsigned = $results | Where-Object { $_.SignStatus -ne 'Valid' }
$summary  = "Files={0}  Unsigned/Problem={1}" -f $results.Count, ($unsigned.Count)
$summary  | Tee-Object -File $log -Append | Out-Null
$unsigned | Select-Object Path,Ext,SignStatus,Signer | Format-Table -Auto | Out-String | Tee-Object -File $log -Append | Out-Null

Write-Host $summary
if($unsigned.Count -gt 0){ exit 1 } else { exit 0 }
