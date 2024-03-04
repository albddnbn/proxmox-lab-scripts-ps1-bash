<#
.SYNOPSIS
	This script performs the installation or uninstallation of SketchUp Viewer.
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
    PowerShell.exe .\Deploy-SketchUpViewer.ps1 -DeploymentType "Install" -DeployMode "NonInteractive"
.EXAMPLE
    PowerShell.exe .\Deploy-SketchUpViewer.ps1 -DeploymentType "Install" -DeployMode "Silent"
.EXAMPLE
    PowerShell.exe .\Deploy-SketchUpViewer.ps1 -DeploymentType "Install" -DeployMode "Interactive"
.EXAMPLE
    PowerShell.exe .\Deploy-SketchUpViewer.ps1 -DeploymentType "Uninstall" -DeployMode "NonInteractive"
.EXAMPLE
    PowerShell.exe .\Deploy-SketchUpViewer.ps1 -DeploymentType "Uninstall" -DeployMode "Silent"
.EXAMPLE
    PowerShell.exe .\Deploy-SketchUpViewer.ps1 -DeploymentType "Uninstall" -DeployMode "Interactive"
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
    [string]$appVendor = 'Trimble, Inc.'
    [string]$appName = 'SketchUp Viewer'
    [string]$appVersion = ''
    [string]$appArch = ''
    [string]$appLang = ''
    [string]$appRevision = ''
    [string]$appScriptVersion = '1.0.0'
    [string]$appScriptDate = '09/24/2023'
    [string]$appScriptAuthor = 'Jason Bergner' # edited by Alex B.
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [string]$installName = ''
    [string]$installTitle = 'SketchUp Viewer'

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

        ## Show Welcome Message, Close SketchUp Viewer With a 60 Second Countdown Before Automatically Closing
        Show-InstallationWelcome -CloseApps 'viewer' -CloseAppsCountdown 60

        ## Show Progress Message (With a Message to Indicate the Application is Being Uninstalled)
        Show-InstallationProgress -StatusMessage "Removing Any Existing Version of $installTitle. Please Wait..."

        ## Uninstall SketchUp Pro and Viewer MSI

        # Remove-MSIApplications -Name "SketchUp 2023"
        Remove-MSIApplications -Name "SketchUp*" -WildCard -FilterApplication ('Publisher', 'Sketchup', 'Contains')

        Start-Sleep -Seconds 3
        # Sketchup Viewer's publisher is Trimble, Inc.
        Remove-MSIApplications -Name "*SketchUp*" -WildCard -FilterApplication ('Publisher', 'Trimble', 'Contains')

        Start-Sleep -Seconds 3

        $AppList = Get-InstalledApplication -Name "*SketchUp*" -Wildcard <# Remove sketchup pro and viewer exe #>
        ForEach ($App in $AppList) {
            # If ($App.Publisher -like "*Trimble*") {
            If ($App.UninstallString -notlike 'MsiExec.exe*') {
                $UninstPath = $($App.UninstallString).Replace('"', '').Replace(' -remove -runfromtemp', '') 
                If (Test-Path -Path $UninstPath) {
                    Write-Log -Message "Found $($UninstPath.FullName), now attempting to uninstall $installTitle."
                    Execute-Process -Path "$UninstPath" -Parameters "-remove -silent" -WindowStyle Hidden
                    Start-Sleep -Seconds 5
                }
            }
            # }
        }

        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Installation'

        # check for visual C++
        $CheckForVisualC = Get-InstalledApplication -Name "Visual C++ 2015-2019 Redistributable (x64)"
        ## Install Microsoft Visual C++ 2015-2019 Redistributable (x64)
        if (-not $CheckForVisualC) {
            $VC2019x64 = Get-ChildItem -Path "$dirFiles" -Filter 'vc_redist.x64.exe' -File -ErrorAction SilentlyContinue
            If ($VC2019x64) {
                Write-Log -Message "Found $($VC2019x64.FullName), now attempting to install Microsoft Visual C++ 2015-2019 Redistributable (x64)."
                Show-InstallationProgress "Installing Microsoft Visual C++ 2015-2019 Redistributable (x64). This may take some time. Please wait..."
                Execute-Process -Path "$VC2019x64" -Parameters "/install /quiet /norestart /log C:\Windows\Logs\Software\VisualC++2015-2019x64-Install.log" -WindowStyle Hidden -IgnoreExitCodes "1638"
                Start-Sleep -Seconds 5
            }
        }

        ## Install SketchUp Viewer
        $ExePath = Get-ChildItem -Path "$dirFiles" -Include SketchUp-Viewer.exe -File -Recurse -ErrorAction SilentlyContinue
        # $MsiPath = Get-ChildItem -Path "$dirFiles" -Include SketchUpViewer.msi -File -Recurse -ErrorAction SilentlyContinue
        # $Transform = Get-ChildItem -Path "$dirFiles" -Include SketchUpViewer.mst -File -Recurse -ErrorAction SilentlyContinue

        If ($ExePath.Exists) {
            Write-Log -Message "Found $($ExePath.FullName), now attempting to install $appName."
            Show-InstallationProgress "Installing SketchUp Viewer. This may take some time. Please wait..."
            Execute-Process -Path "$ExePath" -Parameters "/silent" -WindowStyle Hidden
            Start-Sleep -Seconds 5
        }
        Else {
            Write-Log -Message "Unable to find the SketchUp Viewer installer. Please ensure it is located in the $dirFiles folder." -Severity 3
            Exit-Script -ExitCode 1
        }
        ## Remove SketchUp Viewer Desktop Shortcut (If Present)
        If (Test-Path -Path "$envPublic\Desktop\SketchUp Viewer.lnk") {
            Write-Log -Message "Removing SketchUp Viewer Desktop Shortcut."
            Remove-Item -Path "$envPublic\Desktop\SketchUp Viewer.lnk" -Force -Recurse -ErrorAction SilentlyContinue 
        }
        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Installation'
        Write-Log -Message "Creating the Plugins Folder."
        New-Folder -Path "C:\ProgramData\SketchUp\SketchUp 2022\SketchUp\Plugins"


        Show-InstallationPrompt -Message "$installTitle successfully installed. Thank you for your patience." -ButtonRightText 'OK' -Icon Information -NoWait

    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, Close SketchUp Viewer With a 60 Second Countdown Before Automatically Closing
        Show-InstallationWelcome -CloseApps 'viewer' -CloseAppsCountdown 60

        ## Show Progress Message (With a Message to Indicate the Application is Being Uninstalled)
        Show-InstallationProgress -StatusMessage "Uninstalling the $appName Application. Please Wait..."

        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Uninstallation'

        ## Uninstall SketchUp Pro and Viewer MSI
        # Remove-MSIApplications -Name "SketchUp 2023"
        Remove-MSIApplications -Name "Sketch*Up*" -WildCard -FilterApplication ('Publisher', 'Sketchup', 'Contains')
        # Sketchup Viewer's publisher is Trimble, Inc.
        Remove-MSIApplications -Name "*Sketch*Up*" -WildCard -FilterApplication ('Publisher', 'Trimble', 'Contains')



        $AppList = Get-InstalledApplication -Name "*Sketch*Up*" -Wildcard <# Remove sketchup pro and viewer exe #>
        ForEach ($App in $AppList) {
            If ($App.Publisher -like "*Trimble*") {
                If ($App.UninstallString -notlike 'MsiExec.exe*') {
                    $UninstPath = $($App.UninstallString).Replace('"', '').Replace(' -remove -runfromtemp', '') 
                    If (Test-Path -Path $UninstPath) {
                        Write-Log -Message "Found $($UninstPath.FullName), now attempting to uninstall $installTitle."
                        Execute-Process -Path "$UninstPath" -Parameters "-remove -silent" -WindowStyle Hidden
                        Start-Sleep -Seconds 5
                    }
                }
            }
        }



        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Uninstallation'
        Write-Log -Message "Removing Sketchup folder from ProgramData."
        Remove-Folder -Path "C:\ProgramData\SketchUp"



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