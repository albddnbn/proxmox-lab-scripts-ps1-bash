param(
    [string]$TargetUser,
    ## Step 1: SourceFolder - the Deploy-Application.ps1 script's Installation Phase should copy the application source files TO this SourceFolder location
    #          --> This script is an extension of Deploy-Application.ps1, and uses SourceFolder to copy source files TO the specified user's directory.
    [string]$SourceFolder = '(($sourcefolder$))',
    ## Step 2: Create TWO shortcuts for the application.
    #            1. Private installation shortcut should target 'C:\Users\%USERNAME%\ApplicationFolder\Application.exe' (or something similar, the %USERNAME% variable is used so the same shortcut can be copied to any user's start menu folder)
    #                 - **Should go in the base of the SourceFolder directory.
    #            2. Public installations only use a shortcut at C:\Users\Public\Desktop\Application.lnk, that points to: 'C:\Users\Public\ApplicationFolder\Application.exe'
    #                 - **Should go in it's own directory, in the SourceFolder\PublicInstall directory (can always change this in the code)
    
    # Shortcut #1
    [string]$UserShortcutPath = '(($startmenushortcut$))',
    # Shortcut #2
    [string]$PublicShortcutPath = '(($publicdesktopshortcut$))',
    ## Step 3: Set application name - dictates the name of the folder created at base of specified user's home directory.
    [string]$ApplicationName = '(($appname$))'
)
# creates full local source folder path
$SourceFolder = Join-Path -Path "$SourceFolder" -ChildPath "$ApplicationName"



# This is an 'extension log' to the PSADT log for the app that will be created - logs actions of this script.
# The line below will append the date/time in [], and then the log statement to the log file.
# "[$(Get-Date -Format 'MM/dd/yyyy hh:mm:ss')]  :: Log Statement" | Out-File "$LOGFILE" -Append
$LOGFILE = "C:\WINDOWS\Logs\Software\(($appname$))-install.log"

# creates the log file if it doesn't already exist
if (-not (Test-Path "$LOGFILE" -ErrorAction SilentlyContinue)) {
    New-Item -Path "$LOGFILE" -Itemtype 'file' | out-null 
}

## If TargetUser is NOT Supplied, this means the script is being run as a SCHEDULED TASK.
#     --> The following lines try to get the currently logged/logging in user using Get-Ciminstance, followed by using the 'explorer' process with -includeusername switch.
if (-not $TargetUser) {
    $TargetUser = get-ciminstance -class win32_computersystem | select -exp username
    if (-not $TargetUser) {
        $TargetUser = get-process -name 'explorer' -includeusername -erroraction silentlycontinue | select -exp username

    }
    # Removes any domain name prefix to the username
    $TargetUser = $TargetUser.split('\\')[-1]
}

## Grabs the TargetUser's home directory as a directory object (has multiple properties)
$home_drive_obj = Get-Childitem -Path 'C:\Users' -Filter "$TargetUser" -Directory -ErrorAction SilentlyContinue
if (-not $home_drive_obj) {
    return # ends function if the user has no home drive.
}

## Creates an $ApplicationName directory in user's home drive if it doesn't already exist.
if (-not (Test-Path "$($home_drive_obj.fullname)\$ApplicationName" -ErrorAction SilentlyContinue)) {
    New-Item -Path "$($home_drive_obj.fullname)\$ApplicationName" -ItemType 'Directory' | Out-null
    "[$(Get-Date -Format 'MM/dd/yyyy hh:mm:ss')] :: Created $app_folder_path directory for $TargetUser" | Out-File "$LOGFILE" -Append
}


###
##
# This is where Application Source Files are copied to the Application Folder in user's home drive:
Copy-item "$SourceFolder\*" -destination "$($home_drive_obj.fullname)\$ApplicationName" -recurse -ErrorAction silentlycontinue

##
###

##
# PUBLIC INSTALLATIONS:
if (($TargetUser.ToLower()) -eq 'public') {

    $public_shortcut_lnk = $PublicShortCutPath | Split-path -leaf
    
    # Validate path:
    if (-not (Test-path "$PublicShortcutPath")) {
        "[$(Get-Date -Format 'MM/dd/yyyy hh:mm:ss')] [ERROR] :: Couldn't find the public desktop shortcut at $PublicShortcutPath!" | Out-File "$LOGFILE" -Append
    }
    else {
        Copy-Item -Path "$PublicShortcutPath" -Destination "C:\Users\Public\Desktop\$public_shortcut_lnk"
        "[$(Get-Date -Format 'MM/dd/yyyy hh:mm:ss')] :: Copied $PublicShortcutPath to C:\Users\Public\Desktop\$public_shortcut_lnk" | Out-File "$LOGFILE" -Append
    }
} 
##
# PRIVATE INSTALLATIONS: If the user is anyone but 'public'... - they need a start menu shortcut, desktop is optional.
else {

    $user_startmenu_lnk = $UserShortcutPath | Split-Path -Leaf
    # Validate path:
    if (-not (Test-path "$UserShortcutPath")) {
        "[$(Get-Date -Format 'MM/dd/yyyy hh:mm:ss')] [ERROR] :: Couldn't find the public desktop shortcut at $UserShortcutPath!" | Out-File "$LOGFILE" -Append
    }
    else {

        ForEach ($shortcut_destination in @(
                # 'Desktop', ## UNCOMMENT TO ADD DESKTOP ICON.
                'AppData\Roaming\Microsoft\Windows\Start Menu\Programs'
            )) {
            Copy-ITem -Path "$UserShortcutpath" -Destination "C:\Users\$TargetUser\$shortcut_destination\$user_startmenu_lnk"

            "[$(Get-Date -Format 'MM/dd/yyyy hh:mm:ss')] :: Copied $PublicShortcutPath to C:\Users\$TargetUser\$shortcut_destination" | Out-File "$LOGFILE" -Append

        }
    }

}



