[CmdletBinding()]
param(
    [string]$LinksJson = "C:\Tiptorro\packages\LiveTVLinks\links.json",
    [int]$MonitorIndex = 2,
    [string]$Pick,
    [switch]$Prompt,
    [switch]$VerboseLog
)

$ErrorActionPreference = "Stop"
function Write-Log([string]$m){ if($VerboseLog){ Write-Host "[LiveTV] $m" } }

function Resolve-EdgePath {
  $c = @(
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe",
    "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe",
    (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe' -EA SilentlyContinue).'(default)',
    (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe' -EA SilentlyContinue).'(default)',
    (Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe' -EA SilentlyContinue).'(default)'
  ) | Where-Object { $_ } | Select-Object -Unique
  foreach($p in $c){ if(Test-Path $p){ return $p } }
  try{ $w = (& where.exe msedge.exe) 2>$null | Select-Object -First 1; if($w -and (Test-Path $w)){ return $w } }catch{}
  return $null
}

function Ensure-Extended(){
  Add-Type -AssemblyName System.Windows.Forms | Out-Null
  $n=[System.Windows.Forms.Screen]::AllScreens.Count
  if($n -ge 2){ return $true }
  Write-Log "Only 1 monitor - trying /extend"
  try{
    Start-Process "$env:WINDIR\System32\DisplaySwitch.exe" -ArgumentList "/extend" -WindowStyle Hidden -Wait
    Start-Sleep -Seconds 2
    return ([System.Windows.Forms.Screen]::AllScreens.Count -ge 2)
  }catch{ return $false }
}

function Get-Bounds([int]$idx){
  Add-Type -AssemblyName System.Windows.Forms | Out-Null
  $s=[System.Windows.Forms.Screen]::AllScreens
  if($idx -lt 1 -or $idx -gt $s.Count){ return [System.Windows.Forms.Screen]::PrimaryScreen.Bounds }
  return $s[$idx-1].Bounds
}

function Get-Links([string]$path){
  if(!(Test-Path $path)){ throw "links.json not found: $path" }
  $json = Get-Content -Path $path -Raw | ConvertFrom-Json
  if(-not $json.items){ throw "links.json has no 'items' array." }
  $items = @(); foreach($it in $json.items){ if($it.name -and $it.url){ $items += [pscustomobject]@{Name=$it.name;Url=$it.url} } }
  if($items.Count -eq 0){ throw "links.json contains no valid entries." }
  $defaultIdx = 2
  if($json.PSObject.Properties.Name -contains "defaultMonitorIndex"){ $defaultIdx = [int]$json.defaultMonitorIndex }
  [pscustomobject]@{ Items=$items; DefaultMonitorIndex=$defaultIdx }
}

function Choose-Link($items,[string]$pick,[switch]$prompt){
  if($prompt){
    $ogv = Get-Command Out-GridView -EA SilentlyContinue
    if($ogv){
      $sel = $items | Select-Object Name,Url | Out-GridView -Title "LiveTV-Link w?hlen" -OutputMode Single
      if($sel){ return ($items | Where-Object { $_.Url -eq $sel.Url } | Select-Object -First 1) }
    }
    Write-Host "LiveTV-Link ausw?hlen:"
    for($i=0; $i -lt $items.Count; $i++){ Write-Host (" [{0}] {1}" -f ($i+1), $items[$i].Name) }
    do{
      $choice = Read-Host ("Nummer (1..{0})" -f $items.Count)
      [int]$n=0
      if([int]::TryParse($choice,[ref]$n) -and $n -ge 1 -and $n -le $items.Count){ return $items[$n-1] }
      Write-Host "Ung?ltig."
    } while($true)
  }
  if($pick){
    $m = $items | Where-Object { $_.Name -like ("*{0}*" -f $pick) } | Select-Object -First 1
    if($m){ return $m }
  }
  if($items.Count -eq 1){ return $items[0] }
  return $items[0]
}

try{
  if(-not (Ensure-Extended)){ Write-Log "Proceeding with single monitor." }

  $cfg = Get-Links -path $LinksJson
  if(-not $PSBoundParameters.ContainsKey('MonitorIndex') -or $MonitorIndex -lt 1){ $MonitorIndex = $cfg.DefaultMonitorIndex }
  $b = Get-Bounds -idx $MonitorIndex

  $sel = Choose-Link -items $cfg.Items -pick $Pick -prompt:$Prompt
  Write-Log ("Selected: {0} -> {1}" -f $sel.Name,$sel.Url)

  $edge = Resolve-EdgePath
  if(-not $edge){ throw "msedge.exe not found ? cannot start kiosk." }

  $dataDir = "C:\ttedge\livetv_kiosk"
  New-Item -ItemType Directory -Force $dataDir | Out-Null

  # Kiosk/App ohne Tabs + explizite Position/Gr??e auf Zielmonitor
  $args = @(
    "--kiosk",$sel.Url,
    "--edge-kiosk-type=fullscreen",
    "--window-position=$($b.X),$($b.Y)",
    "--window-size=$($b.Width),$($b.Height)",
    "--no-first-run","--restore-last-session=false",
    "--user-data-dir=$dataDir"
  )
  Write-Log "Launching Edge kiosk..."
  try{
    Start-Process -FilePath $edge -ArgumentList $args | Out-Null
  }catch{
    $args2 = @(
      "--app=$($sel.Url)","--start-fullscreen",
      "--window-position=$($b.X),$($b.Y)",
      "--window-size=$($b.Width),$($b.Height)",
      "--no-first-run","--restore-last-session=false",
      "--user-data-dir=$dataDir"
    )
    Write-Log ("Kiosk failed: {0} -> fallback --app" -f $_.Exception.Message)
    Start-Process -FilePath $edge -ArgumentList $args2 | Out-Null
  }
}
catch{
  Write-Error $_.Exception.Message
  exit 1
}
