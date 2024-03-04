<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of Cadence OrCAD PSpice Designer Lite 17.2.

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of an Cadence OrCAD PSpice Designer Lite 17.2.
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

powershell.exe -Command "& { & '.\Deploy-PSpice.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-PSpice.ps1' -AllowRebootPassThru; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-PSpice.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"

.EXAMPLE

Deploy-PSpice.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-PSpice.ps1, Deploy-PSpice.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-PSpice.ps1
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
    [String]$appVendor = 'Cadence Design Systems, Inc.'
    [String]$appName = 'Cadence OrCAD PSpice Designer Lite 17.2'
    [String]$appVersion = '17.20.025'
    [String]$appArch = 'x86'
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [String]$appScriptDate = '03/02/2024'
    [string]$appScriptAuthor = 'Alex B.' # https://github.com/albddnbn/PSTerminalMenu
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [String]$installName = ''
    [String]$installTitle = 'PSpice A/D Lite 17.2'

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

        ## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
        Show-InstallationWelcome -CloseApps 'pspice,pspiceaa' -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt

        ## <Perform Pre-Installation tasks here>

        ## Make sure ORcad processes are closed:
        Get-Process | Where-Object { $_.Description -like "*Orcad*" } | Stop-Process -Force

        ## Remove existing installations of Cadence OrCAD PSpice Designer Lite 17.2
        ## Uses a custom uninstall script because running uninstallstring displays popup, even when run silently.
        Show-InstallationProgress -StatusMessage "Removing existing installations of $installTitle. Please wait.."
        $Applist = Get-InstalledApplication -name "*orcad*" -WildCard
        ForEach ($single_app in $applist) {
            if ($single_app.publisher -eq 'Cadence Design Systems, Inc.') {
                # get the uninstall-orcad.ps1 script from supportfiles
                $uninstall_script = Get-ChildItem -Path "$dirSupportFiles" -Filter "uninstall-orcad.ps1" -File -ErrorAction SilentlyContinue
                if (-not $uninstall_script) {
                    Write-Log -Message "Unable to find uninstall-orcad.ps1 script, exiting now." -Severity 3
                    Exit-Script -ExitCode 1
                }
                Write-Log -Message "Found $($uninstall_script.fullname), attempting to manually uninstall $installTitle now."
                . "$($uninstall_script.fullname)"
            }
        }

        ## Check for / install required VisualC++ Redistributeables
        $vc_redist_exes = Get-ChildItem -Path "$dirSupportFiles" -Filter "*vcredist*.exe" -File -ErrorAction SilentlyContinue
        ForEach ($vc_redist_file in $vc_redist_exes) {
            $exe_Arch = $($vc_redist_file.name -split '_')[1]
            $exe_arch = $exe_arch -replace '.exe', ''

            $check_for_installed = Get-RegistryKey -Key "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\12.0\VC\Runtimes\$exe_arch" -Value "Installed"

            if ($check_for_installed -eq 1) {
                Write-Log -Message "Visual C++ Redistributable $exe_arch already installed, skipping now."
                Continue
            }

            Write-Log -Message "Found $($vc_redist_file.fullname), attempting to install now."
            Execute-Process -Path "$($vc_Redist_file.fullname)" -Parameters "/install /quiet /norestart" -Windowstyle 'hidden'
            Start-Sleep -Seconds 5
        }        

        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        ## <Perform Installation tasks here>

        ## Get the setup.exe from ./Files and run with silent installation switches / .ini file.
        $SetupExe = Get-ChildItem -Path "$dirFiles\source" -Filter "setup.exe" -File -Erroraction SilentlyContinue
        $SilentInstall_Ini = Get-ChildItem -Path "$dirSupportfiles" -Filter "SilentInstall*.ini" -File -Erroraction SilentlyContinue
        if ((-not $setupexe) -or (-not $SilentInstall_Ini)) {
            Write-Log -Message "Unable to find either setup.exe or silentinstall .ini file, exiting now." -Severity 3
            Exit-Script -ExitCode 1
        }

        Write-Log -Message "Found $($setupexe.fullname) and $($SilentInstall_Ini.fullname), attempting to install $installTitle now."
        Execute-Process -Path "$($setupexe.fullname)" -Parameters "/w /clone_wait !quiet=$($silentinstall_ini.fullname)" -WindowStyle 'hidden'

        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>

        ## Display a message at the end of the install
        If (-not $useDefaultMsi) {
            Show-InstallationPrompt -Message "Installation of $installTitle complete, thank you for your patience." -ButtonRightText 'OK' -Icon Information -NoWait
        }
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'pspice,_cdnshelp' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress -StatusMessage "Attempting to remove any existing installations of $installTitle, please wait."

        ## <Perform Pre-Uninstallation tasks here>
        ## Make sure ORcad processes are closed:
        Get-Process | Where-Object { $_.Description -like "*Orcad*" } | Stop-Process -Force

        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'
        ## <Perform Uninstallation tasks here>
        
        ## Remove existing installations of Cadence OrCAD PSpice Designer Lite 17.2
        ## Uses a custom uninstall script because running uninstallstring displays popup, even when run silently.
        Show-InstallationProgress -StatusMessage "Removing existing installations of $installTitle. Please wait.."
        $Applist = Get-InstalledApplication -name "*orcad*" -WildCard
        ForEach ($single_app in $applist) {
            if ($single_app.publisher -eq 'Cadence Design Systems, Inc.') {
                # get the uninstall-orcad.ps1 script from supportfiles
                $uninstall_script = Get-ChildItem -Path "$dirSupportFiles" -Filter "uninstall-orcad.ps1" -File -ErrorAction SilentlyContinue
                if (-not $uninstall_script) {
                    Write-Log -Message "Unable to find uninstall-orcad.ps1 script, exiting now." -Severity 3
                    Exit-Script -ExitCode 1
                }
                Write-Log -Message "Found $($uninstall_script.fullname), attempting to manually uninstall $installTitle now."
                . "$($uninstall_script.fullname)"
            }
        }

        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'

        ## <Perform Post-Uninstallation tasks here>


    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'pspice,_cdnshelp' -CloseAppsCountdown 60

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

