<#
.SYNOPSIS
    This script performs the installation or uninstallation of Fritzing.
    # LICENSE #
    PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
    Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
    This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
    You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
    The script is provided as a template to perform an install or uninstall of the Fritzing application.
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
    PowerShell.exe .\Deploy-Fritzing.ps1 -DeploymentType "Install" -DeployMode "NonInteractive"
.EXAMPLE
    PowerShell.exe .\Deploy-Fritzing.ps1 -DeploymentType "Install" -DeployMode "Silent"
.EXAMPLE
    PowerShell.exe .\Deploy-Fritzing.ps1 -DeploymentType "Install" -DeployMode "Interactive"
.EXAMPLE
    PowerShell.exe .\Deploy-Fritzing.ps1 -DeploymentType "Uninstall" -DeployMode "NonInteractive"
.EXAMPLE
    PowerShell.exe .\Deploy-Fritzing.ps1 -DeploymentType "Uninstall" -DeployMode "Silent"
.EXAMPLE
    PowerShell.exe .\Deploy-Fritzing.ps1 -DeploymentType "Uninstall" -DeployMode "Interactive"
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
    ## ADDED
    [ValidateSet('private', 'public')]
    [string]$INSTALL_TYPE = 'public'
)

Try {
    ## Set the script execution policy for this process
    Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    ## A new and improved fork of Bloodshed Dev-C++
    ## https://sourceforge.net/projects/orwelldevcpp/
    [string]$appVendor = 'Fritzing'
    [string]$appName = 'Fritzing'
    [string]$appVersion = ''
    [string]$appArch = 'x64'
    [string]$appLang = ''
    [string]$appRevision = ''
    [string]$appScriptVersion = '1.0.0'
    [string]$appScriptDate = '3/2/2024'
    [string]$appScriptAuthor = 'Alex B.' # https://github.com/albddnbn/PSTerminalMenu
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [string]$installName = 'Fritzing'
    [string]$installTitle = 'Fritzing'

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

        Write-Log -Message "Installation type set to: $INSTALL_TYPE" -Severity 2
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Installation'

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

        ## Show Welcome Message, Close Fritzing With a 60 Second Countdown Before Automatically Closing
        Show-InstallationWelcome -CloseApps 'fritzing' -CloseAppsCountdown 60

        ## Show Progress Message (With a Message to Indicate the Application is Being Uninstalled)
        Show-InstallationProgress -StatusMessage "Removing traces of the Fritzing application/software. Please wait..."
        
        # 1. Remove C:\Program Files (x86)\Fritzing (where reference copy of source files is stored on local computer)
        # 2. Also remove Fritzing source files from C:\Users\Public\Documents if they are there.
        # 3. Remove any existing desktop shortcut at C:\Users\Public\Desktop\Fritzing.lnk
        ForEach ($fritzing_filesystem_item in @('C:\Program Files (x86)\Fritzing', 'C:\Users\Public\Documents\Fritzing', 'C:\Users\Public\Desktop\Fritzing.lnk')) {
            Remove-File -Path "$fritzing_filesystem_item" -Recurse -ErrorAction SilentlyContinue
        }
        ## Remove any 'Fritzing' scheduled task set to provision source files for future users.
        Get-ScheduledTask | Where-object { $_.taskname -like "*Fritzing*" } | Unregister-ScheduledTask -Confirm:$false

        Remove-Item -Path "C:\Program Files (x86)\Fritzing" -Recurse -ErrorAction SilentlyContinue
        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Installation'

        # 1. get fritzing folder in files
        # 2. copy to program files (x86), copy shortcut tailoed to %username% to this dir
        # 3. copy from prog files (x86) to all existing users, set their start menu icons
        # 3. set scheduled task to do same thing for any new users logging in.
        $fritzing_folder = Get-Childitem -path "$dirFiles" -filter "Fritzing" -directory -erroraction SilentlyContinue
        if (-not $fritzing_folder) {
            Write-Log -Message "Fritzing directory not found" -Severity 3
            Exit-Script -ExitCode 1
        }
        Write-Log -Message "Found $($fritzing_folder.fullname), copying to C:\Program Files (x86)\Fritzing."
        Copy-Item -Path "$($fritzing_folder.fullname)" -Destination "C:\Program Files (x86)" -Recurse -Force


        ## Install for users or public depending on $INSTALL_TYPE
        $SKIPPED_USERS = @('Administrator', 'defaultuser0', 'Default', 'Default User')

        $INSTALL_TYPE = $INSTALL_TYPE.tolower()
        # 'private' = all users in C:\users except ones listed in $SKIPPED_USERS
        # 'public'  = only the public user
        if ($INSTALL_TYPE -eq 'private') { $existing_users = $(Get-Childitem -path 'C:\Users' -directory | Where-object { $_.Name -notin $SKIPPED_USERS } | Select -Exp Name) }
        elseif ($INSTALL_TYPE -eq 'public') { $existing_users = @('Public') }

        $userinstall_ps1 = Get-Childitem -path "$dirFiles\Fritzing" -filter 'userinstall.ps1' -File -ErrorAction SilentlyContinue
        if (-not ($userinstall_ps1)) {
            Write-Log -Message "Couldn't find the userinstall.ps1 script in $dirFiles\Fritzing, exiting."
            Exit-Script -ExitCode 1
        }
        Write-Log -Message "Found $($userinstall_ps1.fullname), running installtype=$($INSTALL_TYPE.ToUpper()) copying to C:\temp for execution now."
        New-Folder -Path 'C:\temp'

        Copy-File -Path "$($userinstall_ps1.fullname)" -Destination "C:\temp\"
        Start-Sleep -Seconds 1

        $userinstall_ps1 = Get-ChildItem "C:\temp\" -Filter "$($userinstall_ps1.name)" -File

        ForEach ($single_user in $existing_users) {
            if (($single_user -notlike "*.DTCC*") -and ($single_user -notlike "*_admin")) {
                Execute-Process -Path "Powershell.exe" -Parameters "-executionpolicy bypass $($userinstall_ps1.fullname) -targetuser $single_user" -WindowStyle Hidden
            }
        }

        # Remove userinstall.ps1 script from C:\temp
        Remove-File -Path "$($userinstall_ps1.fullname)"

        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Installation'


        ## Set scheduled task to run the userinstall.ps1 script at user login
        $USER_INSTALL_SCRIPT_PATH = 'C:\Program Files (x86)\Fritzing\userinstall.ps1'

        # Create Scheduled Task
        $taskTrigger = New-ScheduledTaskTrigger -atlogon # always needs to occur at user login
        $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File ""$USER_INSTALL_SCRIPT_PATH"""

        $taskprincipal = New-ScheduledTaskPRincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $tasksettings = New-ScheduledTaskSettingsSet
        $task_object = new-scheduledtask -action $taskaction -principal $taskprincipal -trigger $taskTrigger -settings $tasksettings

        Register-ScheduledTask "Fritzing $INSTALL_TYPE Install" -InputObject $task_object

        # Create the desktop shortcut if it's a public installation.
        if ($INSTALL_TYPE.tolower() -eq 'public') {
            New-Shortcut -Path "C:\Users\Public\Desktop\Fritzing.lnk" -TargetPath "C:\Users\Public\Fritzing\Fritzing.exe" -IconLocation "C:\Program Files (x86)\Fritzing\Fritzing.ico" -Description "Fritzing" -WorkingDirectory "C:\Users\Public"
        }


    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, Close Fritzing With a 60 Second Countdown Before Automatically Closing
        Show-InstallationWelcome -CloseApps 'fritzing' -CloseAppsCountdown 60

        ## Show Progress Message (With a Message to Indicate the Application is Being Uninstalled)
        Show-InstallationProgress -StatusMessage "Removing any existing Fritzing directory in prog files (x86) and in the public user folder, also removing scheduled task."

              
        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        # 1. Remove C:\Program Files (x86)\Fritzing (where reference copy of source files is stored on local computer)
        # 2. Also remove Fritzing source files from C:\Users\Public\Documents if they are there.
        # 3. Remove any existing desktop shortcut at C:\Users\Public\Desktop\Fritzing.lnk
        ForEach ($fritzing_filesystem_item in @('C:\Program Files (x86)\Fritzing', 'C:\Users\Public\Documents\Fritzing', 'C:\Users\Public\Desktop\Fritzing.lnk')) {
            Remove-File -Path "$fritzing_filesystem_item" -Recurse -ErrorAction SilentlyContinue
        }
        ## Remove any 'Fritzing' scheduled task set to provision source files for future users.
        Get-ScheduledTask | Where-object { $_.taskname -like "*Fritzing*" } | Unregister-ScheduledTask -Confirm:$false


        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Uninstallation'
        
        Remove-Item -Path "C:\Program Files (x86)\Fritzing" -Recurse -ErrorAction SilentlyContinue


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
