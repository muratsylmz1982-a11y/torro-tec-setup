[CmdletBinding()]param()
$root='C:\Tiptorro'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Logging/PS-Runner/Opener ---
function Write-Log([System.Windows.Forms.TextBox]$tb,[string]$t){
  if(-not $tb){ return }
  $line = "{0}  {1}`r`n" -f (Get-Date -Format 'HH:mm:ss'), $t
  $tb.AppendText($line)
  $tb.SelectionStart = $tb.TextLength
  $tb.ScrollToCaret()
}


function Run-PS([string]$psArgs,[switch]$Elevate,[System.Windows.Forms.TextBox]$tb){
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
  $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass $psArgs"
  $psi.UseShellExecute = $true
  if($Elevate){ $psi.Verb = 'runas' }
  try{ [void][System.Diagnostics.Process]::Start($psi); if($tb){ Write-Log $tb "Started: powershell $psArgs" } }
  catch{ if($tb){ Write-Log $tb "Abgebrochen/Fehler: $($_.Exception.Message)" } }
}
function Open-Latest([string]$pattern,[System.Windows.Forms.TextBox]$tb){
  $f = Get-ChildItem (Join-Path $root 'logs') -Filter $pattern -ErrorAction SilentlyContinue | Sort LastWriteTime -desc | Select -First 1
  if($f){ Start-Process $f.FullName; if($tb){ Write-Log $tb "Opened: $($f.Name)" } } else { if($tb){ Write-Log $tb "Kein Log gefunden ($pattern)" } }
}

# --- PS5.1 kleine Helfer ---
function Get-Prop($obj,[string]$name){
  $p = $obj.PSObject.Properties[$name]
  if($p){ return $p.Value } else { return $null }
}
function First-NonEmpty([object[]]$vals,[object]$fallback=$null){
  foreach($v in $vals){ if($null -ne $v -and "$v" -ne ''){ return $v } }
  return $fallback
}

# --- Health/Audit Status ---
function Get-HealthStatus {
  $log = Get-ChildItem (Join-Path $root 'logs') -Filter 'healthcheck_*.log' -ErrorAction SilentlyContinue | Sort LastWriteTime -desc | Select -First 1
  if(-not $log){ return [pscustomobject]@{ Status='Unknown'; Ok=0; Warn=0; Err=0; When=$null; Path=$null } }
  $line = (Get-Content $log.FullName | Where-Object { $_ -match 'Summary:\s*OK=\d+\s*WARN=\d+\s*ERROR=\d+' } | Select -Last 1)
  if($line -match 'OK=(\d+)\s+WARN=(\d+)\s+ERROR=(\d+)'){
    $ok=[int]$Matches[1]; $w=[int]$Matches[2]; $e=[int]$Matches[3]
    $st = if($e -gt 0){'Red'} elseif($w -gt 0){'Yellow'} else {'Green'}
    return [pscustomobject]@{ Status=$st; Ok=$ok; Warn=$w; Err=$e; When=$log.LastWriteTime; Path=$log.FullName }
  }
  return [pscustomobject]@{ Status='Unknown'; Ok=0; Warn=0; Err=0; When=$log.LastWriteTime; Path=$log.FullName }
}
function Get-AuditStatus {
  $csv = Get-ChildItem (Join-Path $root 'logs') -Filter 'audit_signatures_*.csv' -ErrorAction SilentlyContinue | Sort LastWriteTime -desc | Select -First 1
  if(-not $csv){ return [pscustomobject]@{ Status='Unknown'; Total=0; Bad=0; BadBin=0; When=$null; Path=$null } }
  $rows = Import-Csv $csv.FullName
  $total = ($rows | Measure-Object).Count
  $badAll = ($rows | Where-Object { $_.SignStatus -ne 'Valid' })
  $bad = ($badAll | Measure-Object).Count
  $badBin = ($badAll | Where-Object { $_.Ext -in '.exe','.dll','.msi' } | Measure-Object).Count
  $st = if($badBin -gt 0){'Red'} elseif($bad -gt 0){'Yellow'} else {'Green'}
  return [pscustomobject]@{ Status=$st; Total=$total; Bad=$bad; BadBin=$badBin; When=$csv.LastWriteTime; Path=$csv.FullName }
}
function Set-Light([System.Windows.Forms.Panel]$panel,[System.Windows.Forms.Label]$label,[string]$state,[string]$text){
  switch($state){
    'Green'  { $panel.BackColor=[System.Drawing.Color]::LimeGreen; $label.Text = "OK  | $text" }
    'Yellow' { $panel.BackColor=[System.Drawing.Color]::Gold;      $label.Text = "WARN| $text" }
    'Red'    { $panel.BackColor=[System.Drawing.Color]::IndianRed; $label.Text = "ERROR| $text" }
    default  { $panel.BackColor=[System.Drawing.Color]::LightGray; $label.Text = "UNKNOWN| $text" }
  }
}

# --- LiveTV Helpers (Dateien/State) ---
function Load-LinksJson {
  $file = Join-Path $root 'links.json'
  if(!(Test-Path $file)){ return @() }
  try{
    $raw = Get-Content $file -Raw | ConvertFrom-Json
    $items = @()

    if($raw -is [System.Collections.IEnumerable]){
      foreach($it in $raw){
        $name = First-NonEmpty @(
          (Get-Prop $it 'Name'), (Get-Prop $it 'Title'), (Get-Prop $it 'Label'), (Get-Prop $it 'id')
        ) '(ohne Name)'
        $url  = First-NonEmpty @(
          (Get-Prop $it 'Url'),  (Get-Prop $it 'URL'), (Get-Prop $it 'Link'), (Get-Prop $it 'href')
        ) $null
        if($url){ $items += [pscustomobject]@{ Name=$name; Url=$url } }
      }
    } else {
      foreach($k in $raw.PSObject.Properties.Name){
        $arr = $raw.$k
        if($arr -is [System.Collections.IEnumerable]){
          foreach($it in $arr){
            $name = First-NonEmpty @(
              (Get-Prop $it 'Name'), (Get-Prop $it 'Title'), (Get-Prop $it 'Label'), (Get-Prop $it 'id')
            ) $k
            $url  = First-NonEmpty @(
              (Get-Prop $it 'Url'),  (Get-Prop $it 'URL'), (Get-Prop $it 'Link'), (Get-Prop $it 'href')
            ) $null
            if($url){ $items += [pscustomobject]@{ Name=$name; Url=$url } }
          }
        }
      }
    }
    return $items
  }catch{ return @() }
}
function Load-SelectedLive {
  $sel = Join-Path $root 'state\livetv.selected.json'
  if(!(Test-Path $sel)){ return $null }
  try{ return Get-Content $sel -Raw | ConvertFrom-Json } catch { return $null }
}
function Save-SelectedLive([string]$name,[string]$url){
  $state = Join-Path $root 'state'
  New-Item -ItemType Directory -Force $state | Out-Null
  $obj = [pscustomobject]@{ name=$name; url=$url; updated=(Get-Date).ToString('o') }
  $obj | ConvertTo-Json | Set-Content (Join-Path $root 'state\livetv.selected.json') -Encoding UTF8
}

# --- Form & Layout ---
$f = New-Object System.Windows.Forms.Form
$f.Text = 'Torro Tec Control Panel'
$f.Width = 980; $f.Height = 640
$f.StartPosition = 'CenterScreen'

$tab = New-Object System.Windows.Forms.TabControl
$tab.Dock = 'Top'; $tab.Height = 420

$tabs = @{
  Setup       = (New-Object System.Windows.Forms.TabPage -Property @{Text='Setup'})
  Diagnostics = (New-Object System.Windows.Forms.TabPage -Property @{Text='Diagnostics'})
  Security    = (New-Object System.Windows.Forms.TabPage -Property @{Text='Security'})
  Status      = (New-Object System.Windows.Forms.TabPage -Property @{Text='Status'})
  Tools       = (New-Object System.Windows.Forms.TabPage -Property @{Text='Tools'})
  Terminal    = (New-Object System.Windows.Forms.TabPage -Property @{Text='Terminal'})
  Kasse       = (New-Object System.Windows.Forms.TabPage -Property @{Text='Kasse'})
}
$tab.TabPages.AddRange(@(
  $tabs.Setup,$tabs.Terminal,$tabs.Kasse,$tabs.Diagnostics,$tabs.Security,$tabs.Status,$tabs.Tools
))

$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true; $log.ReadOnly = $true; $log.ScrollBars = 'Vertical'
$log.Dock='Fill'

function Add-Button($parent,$text,$x,$y,$onClick){
  $b = New-Object System.Windows.Forms.Button
  $b.Text=$text; $b.Left=$x; $b.Top=$y; $b.Width=300; $b.Height=34
  $b.Add_Click($onClick); $parent.Controls.Add($b); return $b
}
function Add-Label($parent,$text,$x,$y,$w=300){
  $l = New-Object System.Windows.Forms.Label
  $l.Text=$text; $l.Left=$x; $l.Top=$y; $l.Width=$w; $l.Height=22
  $parent.Controls.Add($l); return $l
}

# --- Setup ---
Add-Button $tabs.Setup 'OneClick Setup (Phase 8, Admin)' 20 20 { Run-PS "-File `"$root\scripts\OneClick-Phase8.ps1`" -PromptLiveTV -SetAutostart -MonitorIndex 2" -Elevate -tb $log }
Add-Button $tabs.Setup 'Shortcuts (Phase 9) erstellen'   20 60 {
  $ps = @"
`$ErrorActionPreference='Stop'
`$root='$root'
`$psExe = `"$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe`"
`$ws=New-Object -ComObject WScript.Shell
`$desk=`"$env:PUBLIC\Desktop`"
function New-Shortcut(`$p,`$t,`$a){ if(Test-Path `$p){return}; `$s=`$ws.CreateShortcut(`$p); `$s.TargetPath=`$t; `$s.Arguments=`$a; `$s.WorkingDirectory=(Split-Path `$t); `$s.Save() }
`$argLiveTV = "-ExecutionPolicy Bypass -File `"`$root\scripts\Start-LiveTV.ps1`"` -MonitorIndex 2"
`$argShop   = "-ExecutionPolicy Bypass -File `"`$root\scripts\Start-ShopKiosk.ps1`"` -Mode Kiosk"
`$argMaint  = "-ExecutionPolicy Bypass -File `"`$root\scripts\Start-Maintenance.ps1`"`"
New-Shortcut (Join-Path `$desk 'LiveTV (Monitor 2).lnk') `"$psExe`" `$argLiveTV
New-Shortcut (Join-Path `$root 'livetv.lnk')             `"$psExe`" `$argLiveTV
New-Shortcut (Join-Path `$desk 'Torro Maintenance.lnk')  `"$psExe`" `$argMaint
"@
  Run-PS "-Command $ps" -tb $log; Write-Log $log 'Shortcuts angestoßen.'
}
Add-Button $tabs.Setup 'Maintenance (PIN) Shortcut anlegen' 20 100 {
  $ps = @"
`$ws=New-Object -ComObject WScript.Shell
`$desk=`"$env:PUBLIC\Desktop`"
`$ps = `"$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe`"
`$arg = '-ExecutionPolicy Bypass -File `"`$root\scripts\Start-Maintenance-Gated.ps1`"`'
`$lnk = Join-Path `$desk 'Torro Maintenance (PIN).lnk'
if(!(Test-Path `$lnk)){
  `$s=`$ws.CreateShortcut(`$lnk); `$s.TargetPath=`$ps; `$s.Arguments=`$arg; `$s.WorkingDirectory='C:\Tiptorro\scripts'; `$s.Save()
} else {
  # Fallback wenn Gated-Skript nicht existiert
  if(!(Test-Path `"$root\scripts\Start-Maintenance-Gated.ps1`") -and !(Test-Path `"$root\scripts\Start-Maintenance.ps1`")){
    Write-Output 'Maintenance-Skripte fehlen.'
  }
}
"@
  Run-PS "-Command $ps" -tb $log
}
function Load-LinksJson {
  $file = Join-Path $root 'links.json'
  if(!(Test-Path $file)){ return @() }
  try{
    $raw = Get-Content $file -Raw | ConvertFrom-Json
    $items = @()
    if($raw -is [System.Collections.IEnumerable]){
      foreach($it in $raw){
        $name = Get-Prop $it 'Name'; if(-not $name){ $name = First-NonEmpty @((Get-Prop $it 'Title'),(Get-Prop $it 'Label'),(Get-Prop $it 'id'),'(ohne Name)') }
        $url  = First-NonEmpty @((Get-Prop $it 'Url'),(Get-Prop $it 'URL'),(Get-Prop $it 'Link'),(Get-Prop $it 'href'))
        if($url){ $items += [pscustomobject]@{ Name=$name; Url=$url } }
      }
    } else {
      foreach($k in $raw.PSObject.Properties.Name){
        $arr = $raw.$k
        if($arr -is [System.Collections.IEnumerable]){
          foreach($it in $arr){
            $name = First-NonEmpty @((Get-Prop $it 'Name'),(Get-Prop $it 'Title'),(Get-Prop $it 'Label'),(Get-Prop $it 'id'),$k)
            $url  = First-NonEmpty @((Get-Prop $it 'Url'),(Get-Prop $it 'URL'),(Get-Prop $it 'Link'),(Get-Prop $it 'href'))
            if($url){ $items += [pscustomobject]@{ Name=$name; Url=$url } }
          }
        }
      }
    }
    return $items 
  }catch{ return @() }
}
function Load-SelectedLive {
  $sel = Join-Path $root 'state\livetv.selected.json'
  if(!(Test-Path $sel)){ return $null }
  try{ return Get-Content $sel -Raw | ConvertFrom-Json } catch { return $null }
}
function Save-SelectedLive([string]$name,[string]$url){
  $state = Join-Path $root 'state'
  New-Item -ItemType Directory -Force $state | Out-Null
  $obj = [pscustomobject]@{ name=$name; url=$url; updated=(Get-Date).ToString('o') }
  $obj | ConvertTo-Json | Set-Content (Join-Path $root 'state\livetv.selected.json') -Encoding UTF8
}

function Build-LiveTVSection {
  param(
    [System.Windows.Forms.TabPage]$Parent,
    [int]$X = 20,
    [int]$Y = 120
  )
  $cmb = New-Object System.Windows.Forms.ComboBox
  $cmb.Left=$X; $cmb.Top=$Y; $cmb.Width=600; $cmb.DropDownStyle='DropDownList'
  $Parent.Controls.Add($cmb)

  $lblUrl = Add-Label $Parent 'URL: -' $X ($Y+40) 900
  $cmb.Tag = $lblUrl            # <— Label-Referenz am ComboBox-Objekt ablegen
  $lblSel = Add-Label $Parent 'Auswahl: (nicht gespeichert)' $X ($Y+65) 900

  $nud = New-Object System.Windows.Forms.NumericUpDown
  $nud.Left=$X+620; $nud.Top=$Y-2; $nud.Width=60; $nud.Minimum=1; $nud.Maximum=8; $nud.Value=2
  $Parent.Controls.Add($nud)
  Add-Label $Parent 'Monitor' ($X+685) ($Y+2) 60 | Out-Null

  $btnReload = Add-Button $Parent 'links.json neu laden' $X ($Y+100) { }
  $btnOpen   = Add-Button $Parent 'links.json öffnen'   ($X+320) ($Y+100) { }
  $btnSave   = Add-Button $Parent 'Auswahl speichern'   $X ($Y+140) { }
  $btnStart  = Add-Button $Parent 'LiveTV jetzt starten' ($X+319) ($Y+140) { }

  # Verknüpfe Controls über Tag (robust gg. Scope)
  $btnReload.Tag = @{ Combo=$cmb }
  $btnOpen.Tag   = @{ }
  $btnSave.Tag   = @{ Combo=$cmb; LabelSel=$lblSel }
  $btnStart.Tag  = @{ Combo=$cmb; Nud=$nud }

  $btnReload.Add_Click({
    $combo = $this.Tag.Combo
    if(-not $combo){ return }
    $items = Load-LinksJson
    $combo.Items.Clear()
    foreach($i in $items){ [void]$combo.Items.Add("$($i.Name) | $($i.Url)") }
    if($combo.Items.Count -gt 0){ $combo.SelectedIndex = 0 }
    Write-Log $log ("Links geladen: {0}" -f $combo.Items.Count)
  })
  $btnOpen.Add_Click({
    $f = Join-Path $root 'links.json'
    if(Test-Path $f){ Start-Process $f } else { Write-Log $log 'links.json fehlt' }
  })
  $btnSave.Add_Click({
    $combo = $this.Tag.Combo; $lbl = $this.Tag.LabelSel
    if($combo -and $combo.SelectedItem){
      $parts = $combo.SelectedItem.ToString().Split('|',2)
      $name=$parts[0].Trim(); $url=$parts[1].Trim()
      Save-SelectedLive $name $url
      if($lbl){ $lbl.Text = "Auswahl gespeichert: $name" }
      Write-Log $log "LiveTV Auswahl gespeichert."
    }
  })
  $btnStart.Add_Click({
    $combo = $this.Tag.Combo; $nud = $this.Tag.Nud
    $mon = if($nud){ $nud.Value } else { 2 }
    Run-PS "-File `"$root\scripts\Start-LiveTV.ps1`" -MonitorIndex $mon" -tb $log
  })

    $cmb.Add_SelectedIndexChanged({
    try {
      $sender = $this
      if ($sender -and $sender.SelectedItem) {
        $parts = $sender.SelectedItem.ToString().Split('|',2)
        $lbl   = $sender.Tag
        if ($lbl -and $lbl -is [System.Windows.Forms.Label]) {
          $lbl.Text = "URL: " + $parts[1].Trim()
        }
      }
    } catch {}
  })


  # Initial laden + ggf. letzte Auswahl markieren
  $btnReload.PerformClick()
  $sel = Load-SelectedLive
  if($sel -and $cmb.Items.Count -gt 0){
    $idx = 0
    for($i=0;$i -lt $cmb.Items.Count;$i++){ if($cmb.Items[$i].ToString().Contains($sel.url)){ $idx=$i; break } }
    $cmb.SelectedIndex = $idx
    $lblSel.Text = "Auswahl erkannt: $($sel.name)"
  }
}


# --- Diagnostics ---
Add-Button $tabs.Diagnostics 'HealthCheck ausführen'            20 20 { Run-PS "-File `"$root\scripts\HealthCheck.ps1`" -Verbose" -tb $log }
Add-Button $tabs.Diagnostics 'HealthCheck – letztes Log öffnen' 20 60 { Open-Latest 'healthcheck_*.log' $log }

# --- Security ---
Add-Button $tabs.Security 'Audit Signatures' 20 20  { Run-PS "-File `"$root\scripts\Audit-Signatures.ps1`" -Verbose" -tb $log }
Add-Button $tabs.Security 'Hash Baseline erzeugen'   20 60  {
  $s = Join-Path $root 'scripts\Generate-HashManifest.ps1'
  if(Test-Path $s){ Run-PS "-File `"$s`"" -tb $log } else { Write-Log $log 'Generate-HashManifest.ps1 fehlt' }
}
Add-Button $tabs.Security 'Hash Baseline prüfen'     20 100 {
  $s = Join-Path $root 'scripts\Verify-HashManifest.ps1'
  if(Test-Path $s){ Run-PS "-File `"$s`"" -tb $log } else { Write-Log $log 'Verify-HashManifest.ps1 fehlt' }
}
Add-Button $tabs.Security 'Audit – neueste CSV öffnen' 20 140 {
  $f = Get-ChildItem (Join-Path $root 'logs') -Filter 'audit_signatures_*.csv' -ErrorAction SilentlyContinue | Sort LastWriteTime -desc | Select -First 1
  if($f){ Start-Process $f.FullName; Write-Log $log "Opened: $($f.Name)" } else { Write-Log $log 'Kein Audit-CSV gefunden' }
}

# --- Status (Ampel) ---
$grp1 = New-Object System.Windows.Forms.GroupBox
$grp1.Text='HealthCheck'; $grp1.Left=20; $grp1.Top=20; $grp1.Width=420; $grp1.Height=140
$tabs.Status.Controls.Add($grp1)

$hcLight = New-Object System.Windows.Forms.Panel; $hcLight.Left=15; $hcLight.Top=30; $hcLight.Width=24; $hcLight.Height=24; $grp1.Controls.Add($hcLight)
$hcText  = Add-Label $grp1 '—' 50 32 340
$hcWhen  = Add-Label $grp1 'Letzter Lauf: —' 50 60 340
Add-Button $grp1 'HealthCheck jetzt' 50 90 { Run-PS "-File `"$root\scripts\HealthCheck.ps1`" -Verbose" -tb $log }

$grp2 = New-Object System.Windows.Forms.GroupBox
$grp2.Text='Security Audit'; $grp2.Left=460; $grp2.Top=20; $grp2.Width=420; $grp2.Height=140
$tabs.Status.Controls.Add($grp2)

$auLight = New-Object System.Windows.Forms.Panel; $auLight.Left=15; $auLight.Top=30; $auLight.Width=24; $auLight.Height=24; $grp2.Controls.Add($auLight)
$auText  = Add-Label $grp2 '—' 50 32 340
$auWhen  = Add-Label $grp2 'Neueste CSV: —' 50 60 340
Add-Button $grp2 'Audit jetzt' 50 90 { Run-PS "-File `"$root\scripts\Audit-Signatures.ps1`" -Verbose" -tb $log }

$btnRefresh = Add-Button $tabs.Status 'Status aktualisieren' 20 180 {
  $h = Get-HealthStatus
  Set-Light $hcLight $hcText $h.Status ("OK={0} WARN={1} ERROR={2}" -f $h.Ok,$h.Warn,$h.Err)
  if($h.When){ $hcWhen.Text = "Letzter Lauf: " + $h.When.ToString('dd.MM.yyyy HH:mm') } else { $hcWhen.Text = "Letzter Lauf: —" }

  $a = Get-AuditStatus
  Set-Light $auLight $auText $a.Status ("Total={0} Bad={1} (Bin={2})" -f $a.Total,$a.Bad,$a.BadBin)
  if($a.When){ $auWhen.Text = "Neueste CSV: " + $a.When.ToString('dd.MM.yyyy HH:mm') } else { $auWhen.Text = "Neueste CSV: —" }

  Write-Log $log "Status aktualisiert."
}

# Auto-Refresh alle 30s
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 30000
$timer.Add_Tick({ $btnRefresh.PerformClick() })
$timer.Start()
[void]$btnRefresh.PerformClick()

# --- Tools ---
Add-Button $tabs.Tools 'Ordner öffnen: scripts' 20 20  { Start-Process (Join-Path $root 'scripts') }
Add-Button $tabs.Tools 'Ordner öffnen: logs'    20 60  { Start-Process (Join-Path $root 'logs') }
Add-Button $tabs.Tools 'Ordner öffnen: ttedge'  20 100 { if(Test-Path 'C:\ttedge'){ Start-Process 'C:\ttedge' } else { Write-Log $log 'C:\ttedge fehlt' } }

# --- Terminal (Kiosk + Geldgeräte + Status) ---

# Reihe 1: OneClick | Maintenance | ccTalk
Add-Button $tabs.Terminal 'OneClick Setup (Phase 8, Admin)' 20 20 {
  Run-PS "-File `"$root\scripts\OneClick-Phase8.ps1`" -PromptLiveTV -SetAutostart -LiveTVMonitorIndex 2" -Elevate -tb $log
}
Add-Button $tabs.Terminal 'Maintenance öffnen (PIN/normal)' 340 20 {
  $g = Join-Path $root 'scripts\Start-Maintenance-Gated.ps1'
  $n = Join-Path $root 'scripts\Start-Maintenance.ps1'
  if(Test-Path $g){ Run-PS "-File `"$g`"" -tb $log }
  elseif(Test-Path $n){ Run-PS "-File `"$n`"" -tb $log }
  else { Write-Log $log 'Maintenance-Skripte fehlen' }
}
Add-Button $tabs.Terminal 'Geldgeräte-Assistent (ccTalk)' 660 20 {
  $md = Join-Path $root 'packages\MoneyDevices.ps1'
  if(Test-Path $md){
    Run-PS "-File `"$md`"" -tb $log
  } else {
    $cc = Join-Path $root 'packages\cctalk\ccTalk Devices.exe'
    if(Test-Path $cc){ Start-Process $cc; Write-Log $log 'ccTalk Devices gestartet.' }
    else { Write-Log $log 'MoneyDevices.ps1 / ccTalk Tools nicht gefunden.' }
  }
}

# Reihe 2: LiveTV (M2) | Shop normal | Start Shop Kiosk
Add-Button $tabs.Terminal 'Start LiveTV (Monitor 2)' 20 60 {
  Run-PS "-File `"$root\scripts\Start-LiveTV.ps1`" -MonitorIndex 2" -tb $log
}
Add-Button $tabs.Terminal 'Shop (normal, kein Kiosk)' 340 60 {
  Run-PS "-Command Start-Process msedge.exe https://shop.tiptorro.com/v7" -tb $log
}
Add-Button $tabs.Terminal 'Start Shop Kiosk' 660 60 {
  Run-PS "-File `"$root\scripts\Start-ShopKiosk.ps1`" -Mode Kiosk" -tb $log
}

# Reihe 3 – Device Manager
Add-Button $tabs.Terminal 'DeviceManager installieren/aktualisieren (Admin)' 20 100 {
  $msi = Join-Path $root 'packages\device-manager\DeviceManager.Service.Setup.msi'
  $alt = Join-Path $root 'packages\device-manager\DeviceManager.msi'
  $exe = Join-Path $root 'packages\device-manager\setup.exe'
  if ( (Test-Path $msi) -or (Test-Path $alt) ) {
    $use = if (Test-Path $msi) { $msi } else { $alt }
    Run-PS "-Command Start-Process msiexec.exe -ArgumentList '/i `"$use`" /qn' -Wait" -Elevate -tb $log
  } elseif (Test-Path $exe) {
    Run-PS "-Command Start-Process `"$exe`" -ArgumentList '/S' -Wait" -Elevate -tb $log
  } else {
    Write-Log $log 'DeviceManager-Installer nicht gefunden.'
  }
}
Add-Button $tabs.Terminal 'DeviceManager: Start' 340 100 {
  Run-PS "-Command sc.exe start `"DeviceManager.Bootstrapper`"" -Elevate -tb $log
}
Add-Button $tabs.Terminal 'DeviceManager: Stop'  660 100 {
  Run-PS "-Command sc.exe stop  `"DeviceManager.Bootstrapper`"" -Elevate -tb $log
}

# Reihe 4: HealthCheck | Audit
Add-Button $tabs.Terminal 'HealthCheck ausführen' 20 140 {
  Run-PS "-File `"$root\scripts\HealthCheck.ps1`" -Verbose" -tb $log
}
Add-Button $tabs.Terminal 'Audit Signatures' 340 140 {
  Run-PS "-File `"$root\scripts\Audit-Signatures.ps1`" -Verbose" -tb $log
}

# LiveTV-Auswahlbereich (inkl. „Auswahl speichern“ + „LiveTV jetzt starten“ nebeneinander)
Build-LiveTVSection -Parent $tabs.Terminal -X 20 -Y 180


# --- Kasse (ohne Kiosk) ---
Add-Button $tabs.Kasse 'Drucker OneClick (Star/Hwasung, Epson interaktiv)' 20 20 {
  Run-PS "-File `"$root\scripts\Printers_Forms.ps1`" -Action OneClick -Verbose" -Elevate -tb $log
}
Add-Button $tabs.Kasse 'TeamViewer Setup (Silent + Reg)' 20 60 {
  $tvExe = Join-Path $root 'packages\teamviewer\TeamViewer_Setup.exe'
  $tvReg = Join-Path $root 'packages\teamviewer\TeamViewer_Settings.reg'
  if(Test-Path $tvExe){ Run-PS "/c `"$tvExe`" /S" -tb $log } else { Write-Log $log 'TeamViewer_Setup.exe fehlt' }
  if(Test-Path $tvReg){ Run-PS "-Command reg import `"$tvReg`"" -tb $log } else { Write-Log $log 'TeamViewer_Settings.reg fehlt' }
}
Add-Button $tabs.Kasse 'Desko Penta Installer öffnen' 20 100 {
  $desko = Join-Path $root 'packages\desko\DESKO_Device_Setup.exe'
  if(Test-Path $desko){ Run-PS "/c `"$desko`"" -tb $log } else { Write-Log $log 'DESKO_Device_Setup.exe fehlt' }
}
Add-Button $tabs.Kasse 'Datawin (TT_OMR_Datawin.exe) öffnen' 20 140 {
  $dw = Join-Path $root 'packages\datawin\TT_OMR_Datawin.exe'
  if(Test-Path $dw){ Run-PS "/c `"$dw`"" -tb $log } else { Write-Log $log 'TT_OMR_Datawin.exe fehlt' }
}
Add-Button $tabs.Kasse 'LiveTV im normalen Edge (ohne Kiosk)' 20 180 {
  Run-PS "-File `"$root\scripts\Start-LiveTV.ps1`" -MonitorIndex 2 -NoKiosk" -tb $log
}
# LiveTV-Block unten in Kasse
Build-LiveTVSection -Parent $tabs.Kasse -X 20 -Y 220

# Compose UI (Log fix: unten andocken, feste Höhe)
$f.Controls.Add($tab)

$log.BorderStyle = 'FixedSingle'
$log.BackColor   = [System.Drawing.Color]::White
$log.ForeColor   = [System.Drawing.Color]::Black
$log.Font        = New-Object System.Drawing.Font('Consolas',9)
$log.WordWrap    = $false
$log.Dock        = 'Bottom'
$log.Height      = 180
$f.Controls.Add($log)

Write-Log $log 'Panel gestartet – Log bereit.'
[void]$f.ShowDialog()


