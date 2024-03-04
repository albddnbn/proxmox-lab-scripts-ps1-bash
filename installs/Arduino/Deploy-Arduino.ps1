<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of Arduino IDE.

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of Arduino IDE.
- The script either performs an "Install" deployment type or an "Uninstall" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

PSApppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2023 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham and Muhammad Mashwani).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType

The type of deployment to perform. Default is: Install.

.PARAMETER DeployMode

Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru

Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode

Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging

Disables logging to file for the script. Default is: $false.

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Arduino.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Arduino.ps1' -AllowRebootPassThru; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Arduino.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"

.EXAMPLE

Deploy-Arduino.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-Arduino.ps1, Deploy-Arduino.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-Arduino.ps1
- 70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1

.LINK

https://psappdeploytoolkit.com
#>


[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [String]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [String]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false
)

Try {
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    }
    Catch {
    }

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [String]$appVendor = 'Arduino SA'
    [String]$appName = 'Arduino'
    [String]$appVersion = '2.2.1'
    [String]$appArch = 'x64'
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [String]$appScriptDate = '2/29/24'
    [String]$appScriptAuthor = 'Alex B.' # https://github.com/albddnbn
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [String]$installName = ''
    [String]$installTitle = 'Arduino IDE'

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [Int32]$mainExitCode = 0

    ## Variables: Script
    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.9.3'
    [String]$deployAppScriptDate = '02/05/2023'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    }
    Else {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [String]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging) {
            . $moduleAppDeployToolkitMain -DisableLogging
        }
        Else {
            . $moduleAppDeployToolkitMain
        }
    }
    Catch {
        If ($mainExitCode -eq 0) {
            [Int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') {
            $script:ExitCode = $mainExitCode; Exit
        }
        Else {
            Exit $mainExitCode
        }
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
        [String]$installPhase = 'Pre-Installation'

        ## <Perform Pre-Installation tasks here>

        ## Show Welcome Message, close related processes
        Show-InstallationWelcome -CloseApps 'Arduino IDE,arduino-cli,mdns-discovery,serial-discovery' -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt

        ## Show Progress Message
        Show-InstallationProgress -StatusMessage "Removing any existing installations of $installTitle. Please wait.."

        ## Uninstall all MSI installations of Arduino
        remove-msiapplications -name 'arduino' -filterapplication (, ('Publisher', 'Arduino', 'Contains'))

        $check_for_arduino_apps = get-installedapplication -name 'arduino'
        ## Uninstall system-wide installation
        ForEach ($single_app in $check_for_arduino_apps) {
            if ($single_app.uninstallstring -notlike "msiexec.exe *") {

                $uninstall_String = $single_app.uninstallstring
                $uninstall_exe_path = ($($uninstallstring -replace '"', '') -split '.exe')[0] + '.exe'

                $uninstall_args = ($($uninstallstring -replace '"', '') -split '.exe')[1]
                $uninstall_args += " /S"

                Execute-process -path "$uninstall_exe_path" -parameters "$uninstall_args" -windowstyle 'hidden'

            }
        }

        ## Uninstall any existing user installations of Arduino IDE
        $existing_users = Get-childitem -path 'C:\Users' -Directory -ErrorAction SilentlyContinue
        $existing_users | % {
            $user = $_.name
            $user_arduino = Get-ChildItem -Path "C:\Users\$user\AppData\Local\Programs\Arduino IDE" -Include Uninstall*.exe -File -Recurse SilentlyContinue
            if ($user_arduino) {
                Execute-Process "$($user_arduino.fullname)" -Parameters "/S" -WindowStyle 'Hidden'
                Write-Log -Message "Found and uninstalled Arduino IDE for $user."
            }
        }


        ## Remove Arduino directory from program files
        Remove-Item -Path "C:\Program Files\Arduino IDE" -Recurse -Force -ErrorAction SilentlyContinue

        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        $arduino_msi = get-childitem -path "$dirFiles" -filter "arduino-ide_*_Windows_64bit.msi" -File -ErrorAction SilentlyContinue
        if (-not $arduino_msi) {
            Write-Log -Message "Couldn't find the Arduino MSI installer in $dirFiles" -Severity 3
            Exit-Script -Exitcode 1
        }
        Write-Log -Message "Found $($arduino_msi.fullname), installing now."

        Execute-MSI -Action 'install' -path "$($arduino_msi.fullname)"

        Start-Sleep -Seconds 5

        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>
        ## Display a message at the end of the install
        If (-not $useDefaultMsi) {
            Show-InstallationPrompt -Message "Installation of $installTitle is complete. Thank you for your time." -ButtonRightText 'OK' -Icon Information -NoWait
        }
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'Arduino IDE,arduino-cli,mdns-discovery,serial-discovery' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress -StatusMessage "Removing any existing versions of Arduino IDE."

        ## <Perform Pre-Uninstallation tasks here>

        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        ## <Perform Uninstallation tasks here>

        ## Uninstall all MSI installations of Arduino
        remove-msiapplications -name 'arduino' -filterapplication (, ('Publisher', 'Arduino', 'Contains'))

        $check_for_arduino_apps = get-installedapplication -name 'arduino'
        ## Uninstall system-wide installation
        ForEach ($single_app in $check_for_arduino_apps) {
            if ($single_app.uninstallstring -notlike "msiexec.exe *") {

                $uninstall_String = $single_app.uninstallstring
                $uninstall_exe_path = ($($uninstallstring -replace '"', '') -split '.exe')[0] + '.exe'

                $uninstall_args = ($($uninstallstring -replace '"', '') -split '.exe')[1]
                $uninstall_args += " /S"

                Execute-process -path "$uninstall_exe_path" -parameters "$uninstall_args" -windowstyle 'hidden'

            }
        }

        ## Uninstall any existing user installations of Arduino IDE
        $existing_users = Get-childitem -path 'C:\Users' -Directory -ErrorAction SilentlyContinue
        $existing_users | % {
            $user = $_.name
            $user_arduino = Get-ChildItem -Path "C:\Users\$user\AppData\Local\Programs\Arduino IDE" -Include Uninstall*.exe -File -Recurse SilentlyContinue
            if ($user_arduino) {
                Execute-Process "$($user_arduino.fullname)" -Parameters "/S" -WindowStyle 'Hidden'
                Write-Log -Message "Found and uninstalled Arduino IDE for $user."
            }
        }

        ## Remove Arduino directory from program files
        Remove-Item -Path "C:\Program Files\Arduino IDE" -Recurse -Force -ErrorAction SilentlyContinue

        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'

        ## <Perform Post-Uninstallation tasks here>
        Show-InstallationPrompt -Message "Uninstallation of $installTitle is complete. Thank you for your time." -ButtonRightText 'OK' -Icon Information -NoWait
    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'LabStatsClient,LabStatsUserSpace' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Repair tasks here>

        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'

        ## Handle Zero-Config MSI Repairs
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }
        ## <Perform Repair tasks here>

        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [String]$installPhase = 'Post-Repair'

        ## <Perform Post-Repair tasks here>


    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
