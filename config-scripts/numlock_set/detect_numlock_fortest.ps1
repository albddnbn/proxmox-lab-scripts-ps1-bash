$result = get-itempropertyvalue -path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" -name "InitialKeyboardIndicators"
$result = [double]$result
## ControlSet001
$faststartup = get-ItemPropertyvalue -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled"
$faststartup = [double]$faststartup

if ($result -eq 2147483650) {
    if ($faststartup -eq 0) {
        write-host 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard\InitialKeyboardIndicators is set to 2147483650, fast startup off.'
        # Exit 0
    }
    if (Get-ScheduledTask -TaskName "Numlock VBS Startup" -ErrorAction SilentlyContinue) {
        write-host 'Scheduled task "Numlock VBS Startup" exists.'
        # Exit 0
    }
    else {
        write-host 'Scheduled task "Numlock VBS Startup" does not exist.'
        # Exit 1
    }
}
else {
    # write-host 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard\InitialKeyboardIndicators is NOT set to 2147483650'
    # Exit 1
}