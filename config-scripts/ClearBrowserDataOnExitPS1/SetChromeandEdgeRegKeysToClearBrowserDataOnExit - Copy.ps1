$testforchromekey = Test-Path -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ClearBrowsingDataOnExitList" -erroraction silentlycontinue
if (-not $testforchromekey) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "ClearBrowsingDataOnExitList" -Force
}

New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "SyncDisabled" -Value 1 -PropertyType DWord -Force

$chromehash = @{
    "1" = "browsing_history"
    "2" = "download_history"
    "3" = "cookies_and_other_site_data"
    "4" = "cached_images_and_files"
    "5" = "password_signin"
    "6" = "autofill"
    "7" = "site_settings"
    "8" = "hosted_app_data"
}
ForEach ($key in $chromehash.keys) {
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ClearBrowsingDataOnExitList" -Name $key -Value $chromehash[$key] -PropertyType String -Force
}

# $testforedgekey = Test-Path -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ClearBrowsingDataOnExitList" -erroraction silentlycontinue
# if (-not $testforedgekey) {
#     New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "ClearBrowsingDataOnExitList" -Force
# }

New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "ClearBrowsingDataOnExit" -Value 1 -PropertyType DWORD -Force
