<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of an application(s).
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

powershell.exe -Command "& { & '.\Deploy-SceneBuilder.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-SceneBuilder.ps1' -AllowRebootPassThru; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-SceneBuilder.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"

.EXAMPLE

Deploy-SceneBuilder.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-SceneBuilder.ps1, Deploy-SceneBuilder.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-SceneBuilder.ps1
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
    [String]$appVendor = 'JavaFX'
    [String]$appName = 'SceneBuilder'
    [String]$appVersion = '21.0.0'
    [String]$appArch = 'x64'
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [string]$appScriptDate = '03-01-2024'
    [string]$appScriptAuthor = 'Alex B.' # https://github.com/albddnbn/PSTerminalMenu
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [String]$installName = ''
    [String]$installTitle = "JavaFX SceneBuilder"

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
        Show-InstallationWelcome -CloseApps 'scenebuilder' -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt

        ## Show Progress Message (with the default message)
        Show-InstallationProgress -StatusMessage "Removing existing installations of $installTitle. Please wait..."

        ## <Perform Pre-Installation tasks here>

        # check for any scene builder apps with publishers of gluon
        $AppList = Get-InstalledApplication -Name "*SceneBuilder*" -Wildcard
        ForEach ($App in $AppList) {
            If ($App.Publisher -like "*Gluon *") {
                If ($App.UninstallString) {
                    $UninstPath = $($App.UninstallString).Replace('"', '')        
                    If (Test-Path -Path $UninstPath) {
                        Write-Log -Message "Found $($App.DisplayName) $($App.DisplayVersion) and a valid uninstall string, now attempting to uninstall."
                        Execute-Process -Path $UninstPath -Parameters '/S'
                        Start-Sleep -Seconds 5
                    }
                }
            }
        }
        # uninstall msis
        Write-Log -Message "Running blanket uninstallation of any 'Scenebuilder' applications with a publisher containing 'Gluon'."
        Remove-MSIApplications -Name "*SceneBuilder*" -WildCard -FilterApplication ('Publisher', 'Gluon', 'Exact')

        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        ## <Perform Installation tasks here>
        $MsiPath = Get-ChildItem -Path $dirFiles -Filter "SceneBuilder-*.msi" -File -ErrorAction SilentlyContinue

        # select the latest version using filename
        If ($MsiPath) {
            if ($MSIPath.count -gt 1) {
                $MSIPAth = $msipath | Sort -property name -descending | Select -first 1
                Write-Log -Message "Found multiple installers for $installTitle in $dirFiles. Ended up choosing $($MSIPath.fullname)."
            }
            Write-Log -Message "Found $($MsiPath.FullName), now attempting to install $installTitle."
            Show-InstallationProgress "Installing the $installTitle. This may take some time. Please wait..."
            Execute-MSI -Action Install -Path "$MsiPath" -AddParameters "/quiet /norestart"
        }
        Else {
            Write-Log -Message "Unable to find installer for $installTitle. Exiting script..." -Severity 3
            Exit-Script -ExitCode 1
        }
        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>
        # create a SceneBuilder directory in public desktop
        New-Folder -Path "$env:Public\Desktop\SceneBuilder"
        # /o	Copies file ownership and discretionary access control list (DACL) information.
        # /x	Copies file audit settings and system access control list (SACL) information (implies /o).
        # /e	Copies all subdirectories, even if they're empty. Use /e with the /s and /t command-line options.        
        # /h	Copies files with hidden and system file attributes. By default, xcopy doesn't copy hidden or system files
        # /k	Copies files and retains the read-only attribute on destination files if present on the source files. By default, xcopy removes the read-only attribute.
        # /y suppress prompt for confirmation to overwrite existing files
        echo D | xcopy "$env:LOCALAPPDATA\SceneBuilder" "$env:PUBLIC\SceneBuilder" /O /X /E /H /K /y

        # create a shortcut on the public desktop
        New-ShortCut -Path "$env:Public\Desktop\SceneBuilder.lnk" -Target "$env:PUBLIC\SceneBuilder\SceneBuilder.exe" -WorkingDirectory "$env:PUBLIC\Documents\SceneBuilder" -Description "Link to $appname"

        ## Display a message at the end of the install
        If (-not $useDefaultMsi) {
            Show-InstallationPrompt -Message "$installTitle installation complete. Thank you for your patience." -ButtonRightText 'OK' -Icon Information -NoWait
        }
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'scenebuilder' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Uninstallation tasks here>


        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        Write-Log -Message "Attempting uninstall of $installTitle msi / exe installations..."
        ## <Perform Uninstallation tasks here>
        # uninstall scene builder
        # check for anything else
        $AppList = Get-InstalledApplication -Name "*SceneBuilder*" -Wildcard
        ForEach ($App in $AppList) {
            If ($App.Publisher -like "*Gluon *") {
                If ($App.UninstallString) {
                    $UninstPath = $($App.UninstallString).Replace('"', '')        
                    If (Test-Path -Path $UninstPath) {
                        Write-Log -Message "Found $($App.DisplayName) $($App.DisplayVersion) and a valid uninstall string, now attempting to uninstall."
                        Execute-Process -Path $UninstPath -Parameters '/S'
                        Start-Sleep -Seconds 5
                    }
                }
            }
        }
        # uninstall msis
        Remove-MSIApplications -Name "*SceneBuilder*" -WildCard -FilterApplication ('Publisher', 'Gluon', 'Exact')

        # check the public desktop for a SceneBuilder directory and remove it
        Write-Log -Message "Removing SceneBuilder directory/links from public desktop."
        Remove-Item -Path "$env:Public\Documents\SceneBuilder" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:Public\Desktop\SceneBuilder.lnk" -Force -ErrorAction SilentlyContinue


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
        Show-InstallationWelcome -CloseApps 'scenebuilder' -CloseAppsCountdown 60

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
