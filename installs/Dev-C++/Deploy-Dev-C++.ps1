<#
.SYNOPSIS
    This script performs the installation or uninstallation of Dev-C++.
    # LICENSE #
    PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
    Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
    This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
    You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
    The script is provided as a template to perform an install or uninstall of Dev-C++.
    The script either performs an "Install" deployment type or an "Uninstall" deployment type.
    The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
    The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
    The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
    Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
    Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
    Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
    Disables logging to file for the script. Default is: $false.
.EXAMPLE
    PowerShell.exe .\Deploy-ApplicationName.ps1 -DeploymentType "Install" -DeployMode "NonInteractive"
.EXAMPLE
    PowerShell.exe .\Deploy-Dev-C++.ps1 -DeploymentType "Install" -DeployMode "Silent"
.EXAMPLE
    PowerShell.exe .\Deploy-Dev-C++.ps1 -DeploymentType "Install" -DeployMode "Interactive"
.EXAMPLE
    PowerShell.exe .\Deploy-Dev-C++.ps1 -DeploymentType "Uninstall" -DeployMode "NonInteractive"
.EXAMPLE
    PowerShell.exe .\Deploy-Dev-C++.ps1 -DeploymentType "Uninstall" -DeployMode "Silent"
.EXAMPLE
    PowerShell.exe .\Deploy-Dev-C++.ps1 -DeploymentType "Uninstall" -DeployMode "Interactive"
.NOTES
    Toolkit Exit Code Ranges:
    60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
    69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
    70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
    http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [string]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [string]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false,
    [ ValidateSet(
        'public',
        'private'
    )  ]
    [string]$INSTALL_TYPE = 'public'
)

Try {
    ## Set the script execution policy for this process
    Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [string]$appVendor = ''
    [string]$appName = 'Dev-C++'
    [string]$appVersion = ''
    [string]$appArch = ''
    [string]$appLang = ''
    [string]$appRevision = ''
    [string]$appScriptVersion = '1.0.0'
    [string]$appScriptDate = '03-01-2024'
    [string]$appScriptAuthor = 'Alex B.' # https://github.com/albddnbn/PSTerminalMenu
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [string]$installName = ''
    [string]$installTitle = 'Dev-C++'

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [int32]$mainExitCode = 0

    ## Variables: Script
    [string]$deployAppScriptFriendlyName = 'Deploy Application'
    [version]$deployAppScriptVersion = [version]'3.8.4'
    [string]$deployAppScriptDate = '26/01/2021'
    [hashtable]$deployAppScriptParameters = $psBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
    [string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
        If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
    }
    Catch {
        If ($mainExitCode -eq 0) { [int32]$mainExitCode = 60008 }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Installation'
        Write-Log -Message "Installation type set to: $INSTALL_TYPE" -Severity 2
        # Variable needs to be set - used to grab source files from ./Files/APPLICATION_NAME
        # also used to create the Application directoy in one of the Program Files directories.
        $APPLICATION_NAME = 'Dev-C++'
        # Location on local computer where source files will be copied ($APPLICATION_NAME = folder name)
        $SOURCE_FILE_DESTINATION = "C:\Program Files (x86)"
        $SOURCE_FILE_DESTINATION = Join-Path -Path "$SOURCE_FILE_DESTINATION" -ChildPath "$APPLICATION_NAME"


        ## Microsoft Intune Win32 App Workaround - Check If Running 32-bit Powershell on 64-bit OS, Restart as 64-bit Process
        If (!([Environment]::Is64BitProcess)) {
            If ([Environment]::Is64BitOperatingSystem) {

                Write-Log -Message "Running 32-bit Powershell on 64-bit OS, Restarting as 64-bit Process..." -Severity 2
                $Arguments = "-NoProfile -ExecutionPolicy ByPass -WindowStyle Hidden -File `"" + $myinvocation.mycommand.definition + "`""
                $Path = (Join-Path $Env:SystemRoot -ChildPath "\sysnative\WindowsPowerShell\v1.0\powershell.exe")

                Start-Process $Path -ArgumentList $Arguments -Wait
                Write-Log -Message "Finished Running x64 version of PowerShell"
                Exit

            }
            Else {
                Write-Log -Message "Running 32-bit Powershell on 32-bit OS"
            }
        }

        ## Insert process name(s) for software/application into quotes after CloseApps.
        Show-InstallationWelcome -CloseApps 'devcpp,devcppportable' -CloseAppsCountdown 60

        ## Show Progress Message (With a Message to Indicate the Application is Being Uninstalled)
        Show-InstallationProgress -StatusMessage "Removing Any Existing Version of $installTitle. Please Wait..."

        ## Uninstall existing .exe installations.
        $AppList = Get-InstalledApplication -Name "ApplicationName"     
        ForEach ($App in $AppList) {

            If (($App.UninstallString)) {
                $UninstPath = $($App.UninstallString).Replace('"', '')       
                If (Test-Path -Path $UninstPath) {
                    Write-log -Message "Found $($App.DisplayName) $($App.DisplayVersion) and a valid uninstall string, now attempting to uninstall."
                    if ($app.uninstallstring -like "*.exe *") {
                        ## Script attempts to parse out any arguments in the apps uninstall string.
                        $uninstall_str = $(($app.uninstallstring) -split (".exe")[0]) + ".exe"
                        $uninstall_args = $(($app.uninstallstring) -split (".exe")[1])

                        Execute-Process -Path "$uninstall_str" -Parameters "$uninstall_args" -WindowStyle 'Hidden'
                    }
                    else {
                        ## Uninstallation switches will have to be added here.
                        Execute-Process -Path $UninstPath -Parameters '/S /v/qn' -WindowStyle 'Hidden'
                        Start-Sleep -Seconds 5
                    }
                }
            }
        }

        ## Remove any existing source folder/files on the system.
        # 1. Remove SourceFolder (where reference copy of source files is stored on local computer)
        # 2. Also remove source files from C:\Users\Public\ if they are there.
        # 3. Remove any existing desktop shortcut at C:\Users\Public\Desktop\Fritzing.lnk
        ForEach ($filesystem_item in @("$SOURCE_FILE_DESTINATION", "C:\Users\Public\$APPLICATION_NAME", "C:\Users\Public\Desktop\$APPLICATION_NAME.lnk")) {
            Remove-File -Path "$filesystem_item" -Recurse
        }

        ## Remove any scheduled task containing the application name
        Get-ScheduledTask | Where-object { $_.taskname -like "*$APPLICATION_NAME*Install*" } | Unregister-ScheduledTask -Confirm:$false

     
        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Installation'

        ## Exe installer execution with supplied parameters:
        $exefile = Get-Childitem -PAth "$dirFiles" -Filter "*.exe" -file -erroraction SilentlyContinue
        if ($exefile) {
            Write-Log -Message "Found $($exefile.fullname), running installation."
            Execute-Process -Path "$($exefile.fullname)" -Parameters "/S"
        }

        ## Get application source files, copy to local source files in Program files (x86):
        $sourcefiles = Get-Childitem -Path "$dirFiles" -filter "$APPLICATION_NAME" -directory -erroraction silentlycontinue
        if (-not $sourcefiles) {
            Write-Log -Message "Couldn't find $APPLICATION_NAME folder in $dirFiles, exiting." -Severity 3
            Exit-Script -ExitCode 1
        }
        Write-Log -Message "Found $($sourcefiles.fullname), copying to $SOURCE_FILE_DESTINATION."

        if (-not (Test-Path "$SOURCE_FILE_DESTINATION" -ErrorAction SilentlyContinue)) {
            New-folder -Path "$SOURCE_FILE_DESTINATION"
        }

        Copy-Item -Path "$($sourcefiles.fullname)\*" -Destination "$SOURCE_FILE_DESTINATION" -Recurse

        Write-Log -Message "Source files copied to $SOURCE_FILE_DESTINATION."

        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Installation'

        $SKIPPED_USERS = @('Administrator', 'defaultuser0', 'Default', 'Default User', 'Public')

        ## Check for userinstall.ps1 script, used to copy source files to user directories, OR just to public directory
        ## depending on $INSTALL_TYPE variable.
        $userinstall_ps1 = Get-Childitem -path "$dirFiles" -filter 'userinstall.ps1' -File -Recurse -ErrorAction SilentlyContinue
        if (-not ($userinstall_ps1)) {
            Write-Log -Message "Couldn't find the userinstall.ps1 script in $dirFiles. This script is needed to copy source files to user directories, and needed for the scheduled task action. Exiting."
            Exit-Script -ExitCode 1
        }

        Write-Log -Message "Found $($userinstall_ps1.fullname), running installtype=$($INSTALL_TYPE.ToUpper()) copying to C:\temp for execution now."
        New-Folder 'C:\temp' # create folder if doesn't exist

        Copy-File -Path "$($userinstall_ps1.fullname)" -Destination "$SOURCE_FILE_DESTINATION" # copies file to application folder in prog files, for scheduled task execution
        Copy-File -Path "$($userinstall_ps1.fullname)" -Destination "C:\temp\" # copies script for user provisioning
        Start-Sleep -Seconds 1

        $userinstall_ps1 = Get-ChildItem "C:\temp\" -Filter "$($userinstall_ps1.name)" -File

        if ($INSTALL_TYPE -eq 'public') { $existing_users = @('Public') }
        elseif ($INSTALL_TYPE -eq 'private') {
            $existing_users = $(Get-ChildItem -Path 'C:\Users' -Directory | Where-object { $_.NAme -notin $SKIPPED_USERS } | Select -exp name)
        }
        Remove-Folder -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Bloodshed Dev-C++"


        ForEach ($single_user in $existing_users) {
            if (($single_user -notlike "*.DTCC*") -and ($single_user -notlike "*_admin")) {
                Execute-Process -Path "Powershell.exe" -Parameters "-executionpolicy bypass $($userinstall_ps1.fullname) -targetuser $single_user" -WindowStyle Hidden
            }
        }

        # Remove userinstall.ps1 script from C:\temp
        Remove-File -Path "$($userinstall_ps1.fullname)"

        # get userinstall from source folder:
        $userinstall_ps1 = Get-ChildItem -Path "$SOURCE_FILE_DESTINATION" -Filter "userinstall.ps1" -File -Recurse
        $userinstall_script_path = $userinstall_ps1.fullname

        ## SCHEDULED TASK CREATION:
        # Create Scheduled Task
        $taskTrigger = New-ScheduledTaskTrigger -atlogon # always needs to occur at user login
        $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File ""$userinstall_script_path"""

        $taskprincipal = New-ScheduledTaskPRincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $tasksettings = New-ScheduledTaskSettingsSet
        $task_object = new-scheduledtask -action $taskaction -principal $taskprincipal -trigger $taskTrigger -settings $tasksettings

        Register-ScheduledTask "$APPLICATION_NAME $INSTALL_TYPE Install" -InputObject $task_object

        # Create the desktop shortcut if it's a public installation (also present in userinstall.ps1 - this code section requires you to have an .ico file in dirFiles)
        # if ($installtype -eq 'public') {
        #     $fritzing_ico = Get-Childitem -path "$dirFiles\Fritzing" -Filter "fritzing.ico" -file -erroraction SilentlyContinue
        #     if (-not $fritzing_ico) {
        #         Write-Log -Message "Couldnt find the fritzing ico file in dirfiles\Fritzing." -Severity 2
        #     }
        #     else {
        #         New-Shortcut -Path "C:\Users\Public\Desktop\Fritzing.lnk" -TargetPath "C:\Users\Public\Documents\Fritzing\Fritzing.exe" -IconLocation "$($fritzing_ico.fullname)" -Description "Fritzing Application" -WorkingDirectory "C:\Users\Public"
        #     }
        # }



    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, Close Dev-C++ With a 60 Second Countdown Before Automatically Closing
        Show-InstallationWelcome -CloseApps 'devcpp,devcppportable' -CloseAppsCountdown 60

        ## Show Progress Message (With a Message to Indicate the Application is Being Uninstalled)
        Show-InstallationProgress -StatusMessage "Uninstalling the $appName Application. Please Wait..."

        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Uninstallation'
     

        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Uninstallation'


    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [string]$installPhase = 'Pre-Repair'

        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [string]$installPhase = 'Repair'


        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [string]$installPhase = 'Post-Repair'


    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [int32]$mainExitCode = 60001
    [string]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
