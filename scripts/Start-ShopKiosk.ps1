<#
 Start-ShopKiosk.ps1
 - Mode Support (default): normal Edge window (tab) on monitor 1
 - Mode Kiosk: real kiosk window (no tabs) on monitor 1
 - Uses dedicated user-data-dirs to avoid white/locked windows
#>

[CmdletBinding()]
param(
  [string]$Url = "https://shop.tiptorro.com/v7",
  [ValidateSet('Support','Kiosk')][string]$Mode = 'Support',
  [int]$MonitorIndex = 1,
  [switch]$VerboseLog
)

$ErrorActionPreference = "Stop"
function Write-Log([string]$m){ if($VerboseLog){ Write-Host "[Shop] $m" } }

function Ensure-NativeMethods {
  if(-not ("Win32.NativeMethods" -as [type])){
    Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace Win32 {
  public static class NativeMethods {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
  }
}
"@ | Out-Null
  }
}
function Move-WindowToBounds {
  param([IntPtr]$Handle,[int]$Left,[int]$Top,[int]$Width,[int]$Height)
  Ensure-NativeMethods
  [Win32.NativeMethods]::MoveWindow($Handle,$Left,$Top,$Width,$Height,$true)|Out-Null
  Start-Sleep -Milliseconds 150
  [Win32.NativeMethods]::ShowWindowAsync($Handle,3)|Out-Null
  [Win32.NativeMethods]::SetForegroundWindow($Handle)|Out-Null
}

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

function Ensure-Extended {
  Add-Type -AssemblyName System.Windows.Forms | Out-Null
  $n=[System.Windows.Forms.Screen]::AllScreens.Count
  if($n -ge 2){ return $true }
  Write-Log "Only 1 monitor detected - trying DisplaySwitch /extend"
  try{
    Start-Process "$env:WINDIR\System32\DisplaySwitch.exe" -ArgumentList "/extend" -WindowStyle Hidden -Wait
    Start-Sleep -Seconds 2
    $n=[System.Windows.Forms.Screen]::AllScreens.Count
    return ($n -ge 2)
  }catch{ return $false }
}
function Get-Bounds {
  param([int]$idx)
  Add-Type -AssemblyName System.Windows.Forms | Out-Null
  $s=[System.Windows.Forms.Screen]::AllScreens
  if($idx -lt 1 -or $idx -gt $s.Count){ return [System.Windows.Forms.Screen]::PrimaryScreen.Bounds }
  return $s[$idx-1].Bounds
}

function Start-Edge-Shop {
  param([string]$TargetUrl,[string]$Mode)
  $edge = Resolve-EdgePath
  $base = "C:\ttedge"
  $dirSupport = Join-Path $base "shop_support"
  $dirKiosk   = Join-Path $base "shop_kiosk"
  New-Item -ItemType Directory -Force $base,$dirSupport,$dirKiosk | Out-Null

  if($edge){
    if($Mode -eq 'Kiosk'){
      $args = @("--kiosk",$TargetUrl,"--edge-kiosk-type=fullscreen","--no-first-run","--restore-last-session=false","--user-data-dir=$dirKiosk")
      Write-Log ("Launching kiosk: {0}" -f $edge)
      try{ return Start-Process -FilePath $edge -ArgumentList $args -PassThru }catch{ Write-Log ("Kiosk exe failed: {0}" -f $_.Exception.Message) }
      $args = @("--app=$TargetUrl","--start-fullscreen","--no-first-run","--restore-last-session=false","--user-data-dir=$dirKiosk")
      Write-Log "Fallback to --app window"
      try{ return Start-Process -FilePath $edge -ArgumentList $args -PassThru }catch{ Write-Log ("App exe failed: {0}" -f $_.Exception.Message) }
    } else {
      $args = @("--new-window",$TargetUrl,"--no-first-run","--restore-last-session=false","--user-data-dir=$dirSupport")
      Write-Log ("Launching support window: {0}" -f $edge)
      try{ return Start-Process -FilePath $edge -ArgumentList $args -PassThru }catch{ Write-Log ("Support exe failed: {0}" -f $_.Exception.Message) }
    }
  }
  Write-Log "Using protocol handler 'microsoft-edge:' (no flags)"
  try{ Start-Process -FilePath ("microsoft-edge:{0}" -f $TargetUrl) | Out-Null; return $null }catch{}
  try{ Start-Process -FilePath "cmd.exe" -ArgumentList @("/c","start","","microsoft-edge:$TargetUrl") -WindowStyle Hidden | Out-Null; return $null }catch{}
  throw "Edge could not be started."
}

try{
  if(-not (Ensure-Extended)){ Write-Log "Proceeding with single monitor." }
  $b = Get-Bounds -idx $MonitorIndex

  $null = Start-Edge-Shop -TargetUrl $Url -Mode $Mode

  # wait for any Edge window and position it
  $deadline=(Get-Date).AddSeconds(30); $h=[IntPtr]::Zero
  do{
    Start-Sleep -Milliseconds 300
    $p = Get-Process -Name "msedge" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }
    if($p){ $h = ($p | Sort-Object StartTime -Descending | Select-Object -First 1).MainWindowHandle }
  } while((Get-Date) -lt $deadline -and $h -eq [IntPtr]::Zero)

  if($h -ne [IntPtr]::Zero){
    Move-WindowToBounds -Handle $h -Left $b.X -Top $b.Y -Width $b.Width -Height $b.Height
    Write-Log ("Shop positioned on monitor {0}." -f $MonitorIndex)
  } else {
    Write-Warning "No Edge window handle found; positioning skipped."
  }
}
catch{
  Write-Error $_.Exception.Message
  exit 1
}
