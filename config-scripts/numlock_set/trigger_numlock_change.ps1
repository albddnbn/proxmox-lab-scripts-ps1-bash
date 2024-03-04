param(
    [switch]$InstallNumLock,
    [switch]$UninstallNumLock,
    [switch]$SchTask
)
$LOGFILE = "C:\WINDOWS\Logs\Software\numlock"
## ENABLE NUMLOCK
if ($InstallNumLock) {

    $LOGFILE = "$($LOGFILE)_enable_$(Get-Date -Format 'yyyy-MM-dd').log"

    ForEach ($filepath in @($LOGFILE, "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard\")) {
        if (-not (Test-Path $filepath)) {
            New-Item -Path $filepath -Force | Out-Null
            "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Created $filepath" | out-file -FilePath "$LOGFILE" -Append
        }
    }
    ## Disable Fast Startup
    Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Type DWORD -Value 0
    ## Set InitialKeyboardIndicators
    Set-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" -Name "InitialKeyboardIndicators" -Type String -Value '2147483650' -Force
    $regvalue = get-itempropertyvalue -path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" -Name "InitialKeyboardIndicators"
    
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: InitialKeyboardIndicators set to: $regvalue" | out-file -FilePath "$LOGFILE" -Append

    ## enable sch task if necessary / switch was used.
    if ($SchTask) {
        ## scheduled task
        # copy enable_numlock.vbs to c:\temp
        $enable_numlock_vbs = Get-Childitem -Path '.' -Filter "enable_numlock.vbs" -File -ErrorAction SilentlyContinue
        if ($enable_numlock_vbs) {
            Copy-Item -Path $enable_numlock_vbs.FullName -Destination "C:\temp\enable_numlock.vbs" -Force
            "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Copied enable_numlock.vbs to C:\temp" | out-file -FilePath "$LOGFILE" -Append
    
            ## Set scheduled task:
            $taskTrigger = New-ScheduledTaskTrigger -AtStartup
            $taskAction = New-ScheduledTaskAction -Execute "cscript.exe" -Argument "C:\temp\enable_numlock.vbs //nologo"
            $taskprincipal = New-ScheduledTaskPRincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
            $tasksettings = New-ScheduledTaskSettingsSet
            $task_object = new-scheduledtask -action $taskaction -principal $taskprincipal -trigger $taskTrigger -settings $tasksettings
            Register-ScheduledTask "Numlock VBS Startup" -InputObject $task_object
        }
        else {
            "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: enable_numlock.vbs not found" | out-file -FilePath "$LOGFILE" -Append
        }
    }
}
## DISABLE NUMLOCK
elseif ($UninstallNumLock) {
    $LOGFILE = "$($LOGFILE)_disable_$(Get-Date -Format 'yyyy-MM-dd').log"
    if (-not (Test-Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard\")) {
        New-Item -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard\" -Force | Out-Null
        write-Host "Created reg at: Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard\"
    }
    
    Set-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" -Name "InitialKeyboardIndicators" -Value '2147483648' -Force

    ## erase sch task if exists:
    $task = Get-ScheduledTask -TaskName "Numlock VBS Startup" -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName "Numlock VBS Startup" -Confirm:$false
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Removed scheduled task: Numlock VBS Startup" | out-file -FilePath "$LOGFILE" -Append
    }
}