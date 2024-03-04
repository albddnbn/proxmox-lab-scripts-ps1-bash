$result = get-itempropertyvalue -path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" -name "InitialKeyboardIndicators"
if ($result -eq 2147483650) {
    write-host 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard\InitialKeyboardIndicators is set to 2147483650'
    Exit 0
}
else {
    write-host 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard\InitialKeyboardIndicators is NOT set to 2147483650'
    Exit 1
}