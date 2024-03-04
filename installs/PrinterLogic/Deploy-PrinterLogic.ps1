<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of the PrinterLogic Printer Client software (https://docs.printerlogic.com/End_Users/PrinterLogic_Client.htm?TocPath=End%20User%20Guides%7C_____1).

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of Printer Installer Client software (from PrinterLogic).
- The script either performs an "Install" deployment type or an "Uninstall" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall Printer Installer Client software (from PrinterLogic).

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

powershell.exe -Command "& { & '.\Deploy-PrinterLogic.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-PrinterLogic.ps1' -AllowRebootPassThru; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-PrinterLogic.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"

.EXAMPLE

Deploy-PrinterLogic.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-PrinterLogic.ps1, Deploy-PrinterLogic.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-PrinterLogic.ps1
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
    [String]$appVendor = 'PrinterLogic'
    [String]$appName = 'Printer Installer Client'
    [String]$appVersion = '25.0.0.930'
    [String]$appArch = 'x86'
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [string]$appScriptDate = '03-01-2024'
    [string]$appScriptAuthor = 'Alex B.' # https://github.com/albddnbn/PSTerminalMenu
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [String]$installName = ''
    [String]$installTitle = 'PrinterLogic Client Software'

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

    ## PrinterLogic Chrome and Edge extensions 
    $PrinterLogicExtRegKeys = @(
        [PSCustomObject]@{
            Key      = "HKLM:\Software\Wow6432Node\Microsoft\Edge\Extensions\cpbdlogdokiacaifpokijfinplmdiapa"
            Property = "update_url"
            Value    = "https://edge.microsoft.com/extensionwebstorebase/v1/crx"
        },
        [PSCustomObject]@{
            Key      = "HKLM:\Software\Wow6432Node\Google\Chrome\Extensions\bfgjjammlemhdcocpejaompfoojnjjfn"
            Property = "update_url"
            Value    = "https://clients2.google.com/service/update2/crx"
        }
    )

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'

        ## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
        Show-InstallationWelcome -CloseApps 'PrinterInstaller,PrinterInstallerClient,PrinterInstallerClientLauncher,PrinterInstallerClientInterface' -AllowDefer -DeferTimes 3 -PersistPrompt

        ## Show Progress Message
        Show-InstallationProgress -StatusMessage "Removing Existing versions of $installTitle. Please wait..."

        ## <Perform Pre-Installation tasks here>
        Write-Log -Message "Removing existing versions of $installTitle."
        #performs blanket removal of a apps with Printer in the display names, that have Printerlogic in publisher name.
        Remove-MSIApplications -Name "Printer Installer Client"

        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        ## <Perform Installation tasks here>

        $MsiPath = Get-ChildItem -Path "$dirFiles" -Filter "*.msi" -File -ErrorAction SilentlyContinue
        if ($MsiPath.Exists) {
            Write-Host "Found $($MsiPath.FullName), not attempting to install $installTitle..."
            Show-InstallationProgress -StatusMessage "Installing $installTitle. This may take some time, thank you for your patience..." 

            Execute-MSI -Action 'Install' -Path "$dirFiles\PrinterInstallerClient.msi" -Parameters 'REBOOT=ReallySuppress /QN'
        }
        else {
            Write-Log -Message "INSTALLER NOT FOUND: Please put the $installTitle .msi file into the $dirFiles directory." -Severity 3
            Exit-Script -ExitCode 1
        }

        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>

        # if the AddExtensions switch is set, install the Chrome/Edge extensions by editing registry (Install-Extensions.ps1)
        # NOTE: at this point, users still have to 'enable' the extension in their browser
        # if ($AddExtensions) {

        Show-InstallationProgress -StatusMessage "Adding Chrome/Edge extensions. You will still have to 'enable' them in your browser!"
        Write-Log -Message "Adding Chrome/Edge extensions."
        ForEach ($regKEy in $PrinterLogicExtRegKeys) {
            Set-RegistryKey -Key $regKey.Key -Name $regKey.Property -Value $regKey.Value -Type 'dword'

        }

        Update-Desktop
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, close $installTitle with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'msedge,PrinterInstaller,PrinterInstallerClient,PrinterInstallerClientLauncher' -CloseAppsCountdown 60

        ## <Perform Pre-Uninstallation tasks here>
        ## Show Progress Message
        Show-InstallationProgress -StatusMessage "Removing Existing versions of $installTitle. Please wait..."

        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        ## <Perform Uninstallation tasks here>
        Write-Log -Message "Removing existing versions of $installTitle."
        Remove-MSIApplications -Name "Printer*" -Wildcard -FilterApplication ('Publisher', 'PrinterLogic', 'Contains')
        Start-Sleep -Seconds 2
        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'
        # attempt to remove any browser extensions installed to hklm
        # check for those keys:
        $CheckingForEdgeKey = Get-ChildItem -Path "HKLM:\Software\Wow6432Node\Microsoft\Edge\Extensions\" | Where-Object { $_.PSChildName -eq 'cpbdlogdokiacaifpokijfinplmdiapa' }
        $CheckingForChromeKey = Get-ChildItem -Path "HKLM:\Software\Wow6432Node\Google\Chrome\Extensions\" | Where-Object { $_.PSChildName -eq 'bfgjjammlemhdcocpejaompfoojnjjfn' }
        if ($CheckingForEdgeKey) {
            Write-Log -Message "Found Edge extension key, removing..."
            Remove-RegistryKey -Key "HKLM:\Software\Wow6432Node\Microsoft\Edge\Extensions\cpbdlogdokiacaifpokijfinplmdiapa" -Recurse -ContinueOnError $true -ErrorAction SilentlyContinue
            # sleep for a second just in case
            Start-Sleep -Seconds 1      
        }
        if ($CheckingForChromeKey) {
            Write-Log -Message "Found Chrome extension key, removing..."
            Remove-RegistryKey -Key "HKLM:\Software\Wow6432Node\Google\Chrome\Extensions\bfgjjammlemhdcocpejaompfoojnjjfn" -Recurse -ContinueOnError $true -ErrorAction SilentlyContinue
            # sleep for a second just in case
            Start-Sleep -Seconds 1
        }
        Update-Desktop
        # ForEach ($regKey in $PrinterLogicExtRegKeys) {
        #     Remove-RegistryKey -Key $regKey.Key -Recurse -ContinueOnError $true -ErrorAction SilentlyContinue
        #     # sleep for a second just in case
        #     Start-Sleep -Seconds 1
        #     Test-RegistryValue -Key $regKEy.Key -Name $regKey.Property -ContinueOnError $true -ErrorAction SilentlyContinue
        
        
        # }
        # Show-InstallationPrompt -Title "$installTitle uninstallation complete" -Message "$installTitle has finished uninstalling. Thank you for your time." -ButtonRightText 'OK' -Icon Information -NoWait

    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'msedge,PrinterInstaller,PrinterInstallerClient,PrinterInstallerClientLauncher,PrinterInstallerClientInterface' -CloseAppsCountdown 60

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
