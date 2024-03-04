<#
.SYNOPSIS
    This script performs the installation or uninstallation of any version of Oracle Java SE Development Kit 8.
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
    PowerShell.exe .\Deploy-JavaJDK.ps1 -DeploymentType "Install" -DeployMode "NonInteractive"
.EXAMPLE
    PowerShell.exe .\Deploy-JavaJDK.ps1 -DeploymentType "Install" -DeployMode "Silent"
.EXAMPLE
    PowerShell.exe .\Deploy-JavaJDK.ps1 -DeploymentType "Install" -DeployMode "Interactive"
.EXAMPLE
    PowerShell.exe .\Deploy-JavaJDK.ps1 -DeploymentType "Uninstall" -DeployMode "NonInteractive"
.EXAMPLE
    PowerShell.exe .\Deploy-JavaJDK.ps1 -DeploymentType "Uninstall" -DeployMode "Silent"
.EXAMPLE
    PowerShell.exe .\Deploy-JavaJDK.ps1 -DeploymentType "Uninstall" -DeployMode "Interactive"
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
    [string]$appVendor = 'Oracle Corporation'
    [string]$appName = 'Java(TM) SE Development Kit 21.0.1 (64-bit)'
    [string]$appVersion = '21.0.1.0'
    [string]$appArch = 'x64'
    [string]$appLang = ''
    [string]$appRevision = ''
    [string]$appScriptVersion = '1.0.0'
    [string]$appScriptDate = '09/19/2023' # 3/2/2024
    [string]$appScriptAuthor = 'Jason Bergner' # edited: Alex B.
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [string]$installName = 'Java SE Development Kit 20'
    [string]$installTitle = 'Java(TM) SE Development Kit'

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

        ## Show Welcome Message, Close Java With a 60 Second Countdown Before Automatically Closing
        Show-InstallationWelcome -CloseApps 'java,javaw,jusched,jqs' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress -StatusMessage "Removing Any Existing Versions of $installTitle. Please Wait..."

        ## Remove Any Existing Versions of Java SE Development Kit
        $java_jdk_installations = Get-InstalledApplication -Name "Java*Development*Kit*" -WildCard
        ForEach ($single_java_listing in $java_jdk_installations) {
            if ($single_java_listing.publisher -like "*Oracle*") {
                $product_code = $single_java_listing.productcode
                Write-Log -Message "Found $($single_java_listing.displayname), attempting to uninstall." -Severity 2
                Execute-MSI -Action 'Uninstall' -Path "$product_code"
                Start-Sleep -Seconds 5
            }
        }

     
        # Create C:\ProgramData\Oracle\Java directory if not present
        Write-Log -Message "Creating C:\ProgramData\Oracle\Java directory if not present."
        $OracleJavaDir = "C:\ProgramData\Oracle\Java"
        if (!(Test-Path $OracleJavaDir)) {
            New-Folder -Path $OracleJavaDir
        }
    
        # Copy Java Configuration File to C:\ProgramData\Oracle\Java\
        Write-Log -Message "Copying Java Configuration File to C:\ProgramData\Oracle\Java\."
        Copy-File -Path "$dirSupportFiles\java.settings.cfg" -Destination $OracleJavaDir


        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Installation'

        Write-Log -Message "Script is built for: 64-bit OS Architecture" -Severity 1 -Source $deployAppScriptFriendlyName

        $ExePath64 = Get-ChildItem -Path "$dirFiles" -Filter "jdk*windows-x64_bin.exe" -File -ErrorAction SilentlyContinue

        If ($ExePath64) {
            if ($ExePath64.count -gt 1) {
                Write-Log -Message "Found $($ExePath64.count) files matching search for installer, selecting latest version."
                $ExePath64 = $ExePath64 | Sort-Object -Property VersionInfo.FileVersion -Descending | Select-Object -First 1
            }
            Write-Log -Message "Found $($ExePath64.FullName), now attempting to install the $installTitle (64-bit)."
            ## Install Oracle Java SE Development Kit 8 (64-bit)
            Show-InstallationProgress "Installing $installTitle. This may take some time. Please wait..."
            Execute-Process -Path "$ExePath64" -Parameters "/s AUTO_UPDATE=0 EULA=0 NOSTARTMENU=1 REBOOT=0 WEB_ANALYTICS=0 SPONSORS=0 /L C:\Windows\Logs\Software\JDK_8x64-Install.log" -WindowStyle Hidden
            # Execute-Process -Path "$ExePath64" -Parameters "/s INSTALLCFG=$ConfigFilePath /L C:\Windows\Logs\Software\JDK_8x64-Install.log" -WindowStyle Hidden
            Start-Sleep -Seconds 3
        }


        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Installation'

        ## Create C:\Windows\Sun\Java\Deployment directory if not present
        Write-Log -Message "Creating C:\Windows\Sun\Java\Deployment directory if not present."
        $SunJavaDeploymentDir = "C:\Windows\Sun\Java\Deployment"
        if (!(Test-Path $SunJavaDeploymentDir)) {
            New-Folder -Path $SunJavaDeploymentDir
        }
    
        ## Copy Java Configuration Files to C:\Windows\Sun\Java\Deployment\
        Write-Log -Message "Copying Java Configuration Files to $SunJavaDeploymentDir."
        Copy-File -Path "$dirSupportFiles\deployment.config" -Destination $SunJavaDeploymentDir
        Copy-File -Path "$dirSupportFiles\deployment.properties" -Destination $SunJavaDeploymentDir

    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, Close Java With a 60 Second Countdown Before Automatically Closing
        Show-InstallationWelcome -CloseApps 'java,javaw,jusched,jqs' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress -StatusMessage "Removing Any Existing Versions of $installTitle. Please Wait..."


        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Uninstallation'

        ## Remove Any Existing Versions of Java SE Development Kit
        $java_jdk_installations = Get-InstalledApplication -Name "Java*Development*Kit*" -WildCard
        ForEach ($single_java_listing in $java_jdk_installations) {
            if ($single_java_listing.publisher -like "*Oracle*") {
                $product_code = $single_java_listing.productcode
                Write-Log -Message "Found $($single_java_listing.displayname), attempting to uninstall." -Severity 2
                Execute-MSI -Action 'Uninstall' -Path "$product_code"
                Start-Sleep -Seconds 5
            }
        }

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

        ## Show Progress Message (with the default message)
        Show-InstallationProgress


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