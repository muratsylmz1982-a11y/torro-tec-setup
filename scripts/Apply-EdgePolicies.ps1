[CmdletBinding()]
param([ValidateSet('Machine','User')][string]$Scope='Machine')

function Is-Admin {
  $id=[Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$base = if($Scope -eq 'Machine'){'HKLM:\SOFTWARE\Policies\Microsoft\Edge'} else {'HKCU:\SOFTWARE\Policies\Microsoft\Edge'}
if($Scope -eq 'Machine' -and -not (Is-Admin)){ throw "Bitte als Administrator starten." }

New-Item -Path $base -Force | Out-Null
$vals = @{
  HideFirstRunExperience=1; PromotionalTabsEnabled=0; DefaultBrowserSettingEnabled=0; AutoImportAtFirstRun=0;
  BrowserSignin=0; SyncDisabled=1; DefaultNotificationsSetting=2; DefaultGeolocationSetting=2;
  PasswordManagerEnabled=0; PasswordLeakDetectionEnabled=0; AutofillAddressEnabled=0; AutofillCreditCardEnabled=0;
  RestoreOnStartup=0; ShowRecommendationsEnabled=0; StandaloneHubsSidebarEnabled=0
}
foreach($k in $vals.Keys){ New-ItemProperty -Path $base -Name $k -PropertyType DWord -Value $vals[$k] -Force | Out-Null }

$cookiesKey = Join-Path $base 'CookiesAllowedForUrls'
New-Item -Path $cookiesKey -Force | Out-Null
New-ItemProperty -Path $cookiesKey -Name '1' -PropertyType MultiString -Value @('https://shop.tiptorro.com') -Force | Out-Null
