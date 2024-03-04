<#
.SYNOPSIS
    This script performs the installation or uninstallation of TeraTerm.
    # LICENSE #
    PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
    Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
    This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
    You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
    The script is provided as a template to perform an install or uninstall of an application(s).
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
    PowerShell.exe .\Deploy-(($appname=Name of Application$)).ps1 -DeploymentType "Install" -DeployMode "NonInteractive"
.EXAMPLE
    PowerShell.exe .\Deploy-TeraTerm.ps1 -DeploymentType "Install" -DeployMode "Silent"
.EXAMPLE
    PowerShell.exe .\Deploy-TeraTerm.ps1 -DeploymentType "Install" -DeployMode "Interactive"
.EXAMPLE
    PowerShell.exe .\Deploy-TeraTerm.ps1 -DeploymentType "Uninstall" -DeployMode "NonInteractive"
.EXAMPLE
    PowerShell.exe .\Deploy-TeraTerm.ps1 -DeploymentType "Uninstall" -DeployMode "Silent"
.EXAMPLE
    PowerShell.exe .\Deploy-TeraTerm.ps1 -DeploymentType "Uninstall" -DeployMode "Interactive"
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
    [switch]$DisableLogging = $false
)

Try {
    ## Set the script execution policy for this process
    Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [string]$appVendor = 'Tera Term Project'
    [string]$appName = 'Tera Term'
    [string]$appVersion = '5.1'
    [string]$appArch = 'x86'
    [string]$appLang = ''
    [string]$appRevision = ''
    [string]$appScriptVersion = '1.0.0'
    [string]$appScriptDate = '02/16/2024'
    [string]$appScriptAuthor = 'abuddenb'
    ## Notes - disk space 30 MB
    ## Do they need TeraTerm Menu? : https://teratermproject.github.io/manual/4/en/usage/TTMenu/TTMenu.html
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [string]$installName = ''
    [string]$installTitle = 'Tera Term'

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

        ## Show Welcome Message, Close TeraTerm With a 60 Second Countdown Before Automatically Closing
        Show-InstallationWelcome -CloseApps 'ttermpro,ttpmacro,keycode' -CloseAppsCountdown 60

        ## Show Progress Message (With a Message to Indicate the Application is Being Uninstalled)
        Show-InstallationProgress -StatusMessage "Removing Any Existing Version of TeraTerm. Please Wait..."

        ## Get Any Existing Versions of TeraTerm and try to uninstall (EXE)
        $AppList = Get-InstalledApplication -Name "Tera Term"   
        ForEach ($App in $AppList) {
            # This creates a check to make sure the tera term installation conforms to same setup as 5.1
            If ($($App.UninstallString | Split-Path -Leaf) -eq "unins000.exe") {

                $TeraTerm_InstallLocation = $($App.InstallLocation).Replace('"', '')

                $UninstPath = $($App.UninstallString).Replace('"', '')

                If (Test-Path -Path $UninstPath) {
                    Write-log -Message "Found $($App.DisplayName) $($App.DisplayVersion) and a valid uninstall string, now attempting to uninstall."
                    Execute-Process -Path $UninstPath -Parameters '/SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
                    Start-Sleep -Seconds 5
                    # Remove the corresponding Tera term folder
                    Remove-Folder -Path "$TeraTerm_InstallLocation"
                }
            }
        }

        ## Remove the TSPECIAL1.ttf Tera Term Font file:
        Remove-File -Path "C:\WINDOWS\Fonts\TSPECIAL1.ttf"

        ## Remove Registry Key for TeraTerm 5
        Remove-RegistryKey -Key "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{07A7E17A-F6D6-44A7-82E6-6BEE528CCA2A}_is1"


        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Installation'

        $teraterm_exe = Get-ChildItem -Path "$dirFiles" -Filter "teraterm-5.1.exe" -File -ErrorAction SilentlyContinue

        if (-not $teraterm_exe) {
            Write-Log -Message "Couldn't find TeraTerm installer in $dirFiles, attempting to download from the internet." -Severity 2

            $teraterm_url = "https://github.com/TeraTermProject/teraterm/releases/download/v5.1/teraterm-5.1.exe"
            $teraterm_exe = "$dirFiles\teraterm-5.1.exe"
            try {
                Invoke-WebRequest -Uri $teraterm_url -OutFile $teraterm_exe -ErrorAction Stop
            }
            catch {
                Write-Log -Message "Failed to download TeraTerm from $teraterm_url, error: $($_.Exception.Message)" -Severity 3
                # Show-DialogBox -Text "Failed to download TeraTerm from $teraterm_url, error: $($_.Exception.Message)" -Icon 'Stop'
                Exit-Script -ExitCode 1
            }
        }

        Write-Log -Message "Found $($teraterm_exe), running system installation now."
        
        ## Script will only reach this point if there is a teraterm_exe variable/file - if it couldn't find it / couldn't request it - script exits
        Execute-Process -Path "$($teraterm_exe.fullname)" -Parameters "/SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG=C:\Windows\Logs\Software\TeraTerm_exe_install.log /DIR=""C:\Program Files (x86)\TeraTerm"""
        Start-Sleep -Seconds 5

        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Installation'

        # Remove shortcut to cyglaunch - will not work unless cygterm64 is installed and .ini file for teraterm is configured
        Remove-File -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Tera Term 5\cyglaunch.lnk"

    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, Close TeraTerm With a 60 Second Countdown Before Automatically Closing
        Show-InstallationWelcome -CloseApps 'ttermpro,ttpmacro,keycode' -CloseAppsCountdown 60

        ## Show Progress Message (With a Message to Indicate the Application is Being Uninstalled)
        Show-InstallationProgress -StatusMessage "Uninstalling the $appName Application. Please Wait..."

        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Uninstallation'


        ## Remove Any Existing Versions of TeraTerm (EXE)
        $AppList = Get-InstalledApplication -Name "Tera Term" -WildCard       
        ForEach ($App in $AppList) {

            If ($($App.UninstallString | Split-Path -Leaf) -eq "unins000.exe") {
                $UninstPath = $($App.UninstallString).Replace('"', '')       
                If (Test-Path -Path $UninstPath) {
                    Write-log -Message "Found $($App.DisplayName) $($App.DisplayVersion) and a valid uninstall string, now attempting to uninstall."
                    Execute-Process -Path $UninstPath -Parameters '/SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
                    Start-Sleep -Seconds 5
                }
            }
        }

        ## Remove any TeraTerm folder in C:\Program files (x86), default location is teraterm5, script sets as TeraTerm
        $teraterm_folders = Get-ChildItem -Path "${$env:ProgramFiles(x86)}" -Filter "TeraTerm*" -Directory -ErrorAction SilentlyContinue | Select -Exp FullName
        $teraterm_font = Get-ChildItem -Path "C:\WINDOWS\Fonts" -Filter "TSPECIAL1.ttf" -File -Recurse -ErrorAction SilentlyContinue | Select -Exp FullName
        $teraterm_items = $teraterm_folders + $teraterm_font
        ForEach ($filesystem_item in $teraterm_items) {
            Write-Log -Message "Found $filesystem_item, now attempting to remove."
            Remove-File -Path "$filesystem_item" -Recurse
        }

        ## Remove Registry Key for TeraTerm 5
        Remove-RegistryKey -Key "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{07A7E17A-F6D6-44A7-82E6-6BEE528CCA2A}_is1"

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