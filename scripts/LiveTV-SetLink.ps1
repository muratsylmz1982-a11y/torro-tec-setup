[CmdletBinding()]
param(
  [string]$LinksJson = "C:\Tiptorro\packages\LiveTVLinks\links.json",
  [switch]$ApplyNow,
  [int]$MonitorIndex = 2,
  [switch]$VerboseLog
)
$ErrorActionPreference = "Stop"
function Log([string]$m){ if($VerboseLog){ Write-Host "[LiveTV-SetLink] $m" } }

$stateDir  = "C:\Tiptorro\state"; New-Item -ItemType Directory -Force $stateDir | Out-Null
$stateFile = Join-Path $stateDir "livetv.selected.json"

# Links laden
if(!(Test-Path $LinksJson)){ throw "links.json not found: $LinksJson" }
$json = Get-Content $LinksJson -Raw | ConvertFrom-Json
$items = foreach($it in $json.items){ if($it.name -and $it.url){ [pscustomobject]@{Name=$it.name;Url=$it.url} } }
if(-not $items -or $items.Count -eq 0){ throw "links.json contains no valid entries." }

# Auswahlmaske
$chosen = $null
$ogv = Get-Command Out-GridView -EA SilentlyContinue
if($ogv){
  $sel = $items | Select-Object Name,Url | Out-GridView -Title "LiveTV-Link wählen (Wartungsmodus)" -OutputMode Single
  if($sel){ $chosen = $items | Where-Object { $_.Url -eq $sel.Url } | Select-Object -First 1 }
}
if(-not $chosen){
  Write-Host "LiveTV-Link auswählen:"
  for($i=0; $i -lt $items.Count; $i++){ Write-Host (" [{0}] {1}" -f ($i+1), $items[$i].Name) }
  do{
    $choice = Read-Host ("Nummer (1..{0})" -f $items.Count)
    [int]$n=0
    if([int]::TryParse($choice,[ref]$n) -and $n -ge 1 -and $n -le $items.Count){ $chosen=$items[$n-1]; break }
    Write-Host "Ungültig."
  }while($true)
}

# speichern
$chosen | ConvertTo-Json -Depth 3 | Set-Content -Path $stateFile -Encoding UTF8
Log "Gespeichert: $($chosen.Name) -> $($chosen.Url)"

if($ApplyNow){
  # laufende LiveTV-Kiosk-Instanz (Profil) beenden & neu starten
  $profile = "C:\ttedge\livetv_kiosk"
  try{
    $esc=[Regex]::Escape($profile)
    Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" -EA SilentlyContinue |
      Where-Object { $_.CommandLine -and ($_.CommandLine -match $esc) } |
      ForEach-Object { try{ Stop-Process -Id $_.ProcessId -Force -EA SilentlyContinue }catch{} }
  }catch{}
  Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -ArgumentList @("-ExecutionPolicy","Bypass","-File","C:\Tiptorro\scripts\Start-LiveTV.ps1","-MonitorIndex",$MonitorIndex) `
    -WindowStyle Hidden | Out-Null
  Log "LiveTV neu gestartet."
}
