if (-not (Test-Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard\")) {
    New-Item -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard\" -Force | Out-Null
    write-Host "Created reg at: Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard\"
}

Set-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" -Name "InitialKeyboardIndicators" -Value '2147483648' -Force

# may have to edit power options / .pol: 
<#
Still not working?
There appears to be a bug with the boot process properly reading this setting when the fast startup feature of Windows 10 is enabled.  Fast startup is a useful feature that shaves a few seconds off your boot time by hibernating a portion of the boot process.  As this hibernation image was created prior to the InitialKeyboardIndicators setting change, that may explain why the updated value is not properly loaded. You can turn off fast startup in Power Options and turn it back on later very easily. 
#>



