param(
    [string]$TargetUser,
    # 1.  basename of this path = name of the directory created in each user's home drive,
    # 2.  the directory that contains the source files on local computer to be copied from, as well.
    # Ex: C:\program files (x86)\Dev-Cpp will create Dev-Cpp folder in each users directory.
    [string]$SourceFolder = 'C:\Program Files (x86)\Fritzing',
    # Path to a shortcut that will let user click / execute the application.
    # The Shortcuts target should be: C:\users\%username%\test\test.exe so it will work for any user.
    # you can create a shortcut and copy it over to the appllication's directory in program files.
    [string]$ShortcutPath = 'C:\Program Files (x86)\Fritzing\Fritzing.lnk',
    # used for directory creation in prog files / user's home drive
    [string]$ApplicationName = 'Fritzing'
)
# create log if doesn't exist:
$LOGFILE = "C:\WINDOWS\Logs\Software\Fritzing-userpublic-install.log"
if (-not (Test-Path "$LOGFILE" -ErrorAction SilentlyContinue)) {
    New-Item -Path "$LOGFILE" -Itemtype 'file' | out-null
}
# TargetUser can be supplied for existing users while cycling through directories in C:\Users
# If TargetUser is not supplied - get the currently logged in user through one of two ways
if (-not $TargetUser) {
    $TargetUser = get-ciminstance -class win32_computersystem | select -exp username
    if (-not $TargetUser) {
        $TargetUser = get-process -name 'explorer' -includeusername -erroraction silentlycontinue | select -exp username

    }
    # remove domain name prefix
    $TargetUser = $TargetUser.split('\\')[-1]
}
$home_drive_obj = Get-Childitem -Path 'C:\Users' -Filter "$TargetUser" -Directory -ErrorAction SilentlyContinue
if (-not $home_drive_obj) {
    return
}

# creates an $ApplicationName directory in user's home drive if it doesn't already exist.
if (-not (Test-Path "$($home_drive_obj.fullname)\$ApplicationName" -ErrorAction SilentlyContinue)) {
    New-Item -Path "$($home_drive_obj.fullname)\$ApplicationName" -ItemType 'Directory' | Out-null
    "[$(Get-Date -Format 'MM/dd/yyyy hh:mm:ss')] :: Created $app_folder_path directory for $TargetUser" | Out-File "$LOGFILE" -Append
}

Copy-item "$SourceFolder\*" -destination "$($home_drive_obj.fullname)\$ApplicationName" -recurse -ErrorAction silentlycontinue

# Now that files have been copied - if it's Public user, then just copy over desktop shortcut
if (($TargetUser.ToLower()) -eq 'public') {
    $fritzing_lnk = Get-Childitem -Path "C:\Program Files (x86)\Fritzing\PublicInstall" -Filter "Fritzing.lnk" -File -ErrorAction SilentlyContinue
    if (-not ($fritzing_lnk)) {
        "[$(Get-Date -Format 'MM/dd/yyyy hh:mm:ss')] :: Unable to find Fritzing.lnk in C:\Program Files (x86)\Fritzing\PublicInstall" | Out-File "$LOGFILE" -Append
    }
    else {
        Copy-Item "$($fritzing_lnk.fullname)" -Destination 'C:\Users\Public\Desktop\Fritzing.lnk'
        "[$(Get-Date -Format 'MM/dd/yyyy hh:mm:ss')] :: Copied Fritzing.lnk to C:\Users\Public\Desktop" | Out-File "$LOGFILE" -Append
    }
} 
# If it's anyone BUT public user - provision normally and set start menu shortcut.
else {
    # separate file/folder and then copy the shortcut to user's desktop and start menu
    $app_user_shortcut = Get-Childitem -PAth "$SourceFolder" -filter "Fritzing.lnk" -file -erroraction silentlycontinue
    if ($app_user_shortcut) {

        ForEach ($filepath in @('Desktop', 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs')) {
            try {
                Copy-Item "$($app_user_shortcut.fullname)" -Destination "$homedrive\$filepath" -Force
            }
            catch {
                Write-Host "Error copying shortcut to $homedrive\$filepath" -foregroundcolor red
            }
        }

    }
    else {
        Write-Host "Shortcut not found" -foregroundcolor red
    }
}



