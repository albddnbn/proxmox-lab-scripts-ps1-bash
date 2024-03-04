<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
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
    powershell.exe -Command "& { & '.\Deploy-Chrome.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Chrome.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Chrome.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Chrome.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Chrome.ps1, Deploy-Chrome.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Chrome.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK 
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory = $false)]
	[ValidateSet('Install', 'Uninstall')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory = $false)]
	[ValidateSet('Interactive', 'Silent', 'NonInteractive')]
	[string]$DeployMode = 'Silent',
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
	[string]$appVendor = 'Google'
	[string]$appName = 'Chrome'
	[string]$appVersion = ''
	[string]$appArch = ''
	[string]$appLang = ''
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '9/29/2023'
	[string]$appScriptAuthor = '' # edited by abuddenb
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = 'Google Chrome'
	
	##* Do not modify section below
	#region DoNotModify
	
	## Variables: Exit Code
	[int32]$mainExitCode = 0
	
	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.7.0'
	[string]$deployAppScriptDate = '02/13/2018'
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
		
	If ($deploymentType -ine 'Uninstall') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## Close Chrome silently, block execution
		#Show-InstallationWelcome -CloseApps 'chrome=Google Chrome' -Silent -BlockExecution
		Show-InstallationWelcome -CloseApps 'chrome' -CloseAppsCountdown 60
		
		## Show Progress Message (with the default message)
		Show-InstallationProgress -StatusMessage "Removing Any Existing Versions of $installTitle. Please Wait..."
		
		## <Perform Pre-Installation tasks here>
		Remove-MSIApplications -Name 'chrome' -FilterApplication ('Publisher', 'Google', 'Contains')
		Start-Sleep -Seconds 5
		## Remove any Existing Versions of Chrome .exe
		# $AppList = Get-InstalledApplication -Name 'Chrome'        
		# ForEach ($App in $AppList) {
		# 	If ($App.UninstallString) {
		# 		$UninstPath = $($App.UninstallString).Replace('"', '')
		# 		$UninstPath = $UninstPath -split ".exe"
		# 		$UninstPath = $UninstPath[0] + ".exe"    
		# 		If (Test-Path -Path $UninstPath) {
		# 			Write-Log -Message "Found $($App.DisplayName) $($App.DisplayVersion) and a valid uninstall string, now attempting to uninstall."
		# 			Execute-Process -Path $UninstPath -Parameters '--uninstall --channel=stable --system-level --verbose-logging /S /qn'
		# 			Start-Sleep -Seconds 5
		# 		}
		# 	}
		# }
		
		
		##*===============================================
		##* INSTALLATION 
		##*===============================================
		[string]$installPhase = 'Installation'
		
		# 64 bit msi
		$MsiPath64 = Get-ChildItem -Path "$dirFiles" -Filter "googlechrome*64.msi" -File -ErrorAction SilentlyContinue
		$MsiPath32 = Get-ChildItem -Path "$dirFiles" -Filter "googlechromestandaloneenterprise*.msi" -File -ErrorAction SilentlyContinue
		## <Perform Installation tasks here>
		if ($MsiPath64.Exists) {
			Write-Log -Message "Found $($MSIPath64.FullName), now attempting to install $installTitle."
			Show-InstallationProgress "Installing $appname. This may take some time. Please wait..."
			#install 64bit Chrome
			Execute-MSI -Path "$($MSIPath64.fullname)" -Parameters "/qn"
		}
		elseif ($MSiPath32.Exists) {
			Write-Log -Message "Found $($MsiPath32.FullName), now attempting to install $appName."
			Show-InstallationProgress "Installing $appname. This may take some time. Please wait..."
			Execute-MSI -Path "$($MSIPath32.fullname)" -Parameters "/qn"
		}
		Else {
			Write-Log -Message "No MSI found in $dirFiles, can't install $installTitle" -Severity 3
			Exit-Script -ExitCode 1
		}
		
		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'
		
		## <Perform Post-Installation tasks here>

		## Display a message at the end of the instal
		Show-InstallationPrompt -Message "$appName installed successfully!" -ButtonRightText 'OK' -Icon Information -NoWait 
	}
	ElseIf ($deploymentType -ieq 'Uninstall') {
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'
		
		## Close Chrome silently, block execution
		Show-InstallationWelcome -CloseApps 'chrome' -Silent -BlockExecution
		
		## Show Progress Message (with the default message)
		Show-InstallationProgress
		
		## <Perform Pre-Uninstallation tasks here>
		
		
		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'
		$MsiPath64 = Get-ChildItem -Path "$dirFiles" -Filter "googlechrome*64.msi" -File -ErrorAction SilentlyContinue
		$MsiPath32 = Get-ChildItem -Path "$dirFiles" -Filter "googlechromestandaloneenterprise.msi" -File -ErrorAction SilentlyContinue
		# <Perform Uninstallation tasks here>
		if ($MsiPath64) {
			#uninstall 64bit Chrome
			Execute-MSI -Action 'Uninstall' -Path "$($MsiPath64.fullname)"
		}
		else {
			Execute-MSI -Action 'Uninstall' -Path "$($MsiPath32.fullname)"
		}
		# blankekt removal of chrome
		Remove-MSIApplications -Name "*Chrome*" -WildCard -FilterApplication ('Publisher', 'Google', 'Contains')
		# may need some cleanup of residual linnks after this

		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'
		
		## <Perform Post-Uninstallation tasks here>
		
		
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