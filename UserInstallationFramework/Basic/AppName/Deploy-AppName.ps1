<#
.SYNOPSIS
    This script performs the installation or uninstallation of (($appname$)).
    # LICENSE #
    PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
    Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
    This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
    You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
    The script is provided as a template to perform an install or uninstall of (($appname$)).
    The script either performs an "Install" deployment type or an "Uninstall" deployment type.
    The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
    The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall (($appname$)).
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
    PowerShell.exe .\Deploy-(($appname$)).ps1 -DeploymentType "Install" -DeployMode "NonInteractive"
.EXAMPLE
    PowerShell.exe .\Deploy-(($appname$)).ps1 -DeploymentType "Install" -DeployMode "Silent"
.EXAMPLE
    PowerShell.exe .\Deploy-(($appname$)).ps1 -DeploymentType "Install" -DeployMode "Interactive"
.EXAMPLE
    PowerShell.exe .\Deploy-(($appname$)).ps1 -DeploymentType "Uninstall" -DeployMode "NonInteractive"
.EXAMPLE
    PowerShell.exe .\Deploy-(($appname$)).ps1 -DeploymentType "Uninstall" -DeployMode "Silent"
.EXAMPLE
    PowerShell.exe .\Deploy-(($appname$)).ps1 -DeploymentType "Uninstall" -DeployMode "Interactive"
.NOTES
    Toolkit Exit Code Ranges:
    60000 - 68999: Reserved for built-in exit codes in Deploy-(($appname$)).ps1, Deploy-(($appname$)).exe, and AppDeployToolkitMain.ps1
    69000 - 69999: Recommended for user customized exit codes in Deploy-(($appname$)).ps1
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
    [Parameter(Mandatory = $false)]
    [switch]$Zipped = $false,
    [string]$scriptconfig_file = "script_config.json",
    [Parameter(Mandatory = $false)]
    [string]$APP_USERS_GROUP = "Everyone", # Group allowed to access source files at SOURCE_FILE_DESTINATION
    # [string]$APPLICATION_NAME = '(($appname$))',
    # [string]$SOURCE_FILE_DESTINATION = '(($sourcefolder$))', # folder that holds source folder. Ex: if you want BlackRocket source files in C:\BlackRocket, sourcefolder should be C:\
    [string]$SOURCE_BACKUP_DIR = 'C:\Program Files', # used for a backup of source files on local system (optional)
    [switch]$UseBackup = $false # specifies whether backup of source files should be created on local system.

)

Try {
    ## Set the script execution policy for this process
    Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [string]$appVendor = ''
    [string]$appName = '(($appname$))'
    [string]$appVersion = ''
    [string]$appArch = ''
    [string]$appLang = ''
    [string]$appRevision = ''
    [string]$appScriptVersion = '1.0.0'
    [string]$appScriptDate = ''
    [string]$appScriptAuthor = ''


    ## Variables added by Alex B.
    
    $script_config = Get-Content $scriptconfig_file -Raw | ConvertFrom-Json

    ## Create variables:
    $SOURCE_FILE_DESTINATION = $script_config.source_destination
    $APPLICATION_NAME = $script_config.application_name
    $APPLICATION__FRIENDLY_NAME = $script_config.friendly_name

    $SOURCE_FILE_DESTINATION = Join-Path -Path "$SOURCE_FILE_DESTINATION" -ChildPath "$APPLICATION_NAME"

    ## Single string - comma-separated list of processes to close before install/uninstall
    $CONFLICTING_PROCESSES = $script_config.conflicting_processes

    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [string]$installName = $APPLICATION_NAME
    [string]$installTitle = $APPLICATION__FRIENDLY_NAME

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

        ## Insert process name(s) for software/application into quotes after CloseApps.
        Show-InstallationWelcome -CloseApps "$CONFLICTING_PROCESSES" -CloseAppsCountdown 60

        ## Show Progress Message (With a Message to Indicate the Application is Being Uninstalled)
        Show-InstallationProgress -StatusMessage "Removing Any Existing Version of $installTitle. Please Wait..."

        Write-Log -Message "Removing any existing items at $SOURCE_FILE_DESTIONATION, and public desktop / start menu items for $APPLICATION_NAME."
        ForEach ($filesystem_item in @("$SOURCE_FILE_DESTINATION", "C:\Users\Public\Desktop\$APPLICATION_NAME", "C:\ProgramData\Microsoft\Windows\Start Menu\$APPLICATION_NAME")) {
            Write-Log -Message "Removing any files/folders at: $filesystem_item."
            Remove-Item -Path "$filesystem_item*" -Recurse -Force # -ErrorAction SilentlyContinue
        }

        ## CHECK FOR AND INSTALL ANY DEPENDENCIES USING DEPENDENCIES.JSON:
        if (-not (Test-Path "$dirSupportFiles\dependencies.json" -ErrorAction SilentlyContinue)) {
            Write-Log -Message "Did not find dependencies.json inside $dirFiles." -Severity 2
            Start-Sleep -Seconds 5
            # Exit-Script -ExitCode 1
        }
        # $dependencies_json = Get-Content -Path "$dirSupportFiles\dependencies.json" -Raw | ConvertFrom-Json

        $dependencies_obj = $script_config.dependencies

        # Cycle through each dependency object in the json file, and install.
        ForEach ($single_dependency in $dependencies_obj) {
            $installation_file = $single_dependency.file
            $dependency_app_name = $single_dependency.AppName
            $silentswitches = $single_dependency.silentswitches

            Write-Log -Message "Checking for $dependency_app_name on $env:COMPUTERNAME."

            if (-not (Get-InstalledApplication -Name "$dependency_app_name")) {
                Write-Log -Message "$dependency_app_name NOT FOUND on $env:COMPUTERNAME, attempting install using: $installation_file $silentswitches." -Severity 2
                $installation_file = Get-ChildItem -Path "$dirSupportFiles" -Filter "$installation_file" -File -ErrorAction SilentlyContinue
                if (-not $installation_file) {
                    Write-Log -MEssage "Couldn't find $($single_dependency.file) in $dirSupportFiles, exiting script." -Severity 3
                    Exit-Script -ExitCode 1
                }
                Write-Log -Message "Found $($installation_file.fullname), installing now."

                ## MSI dependency installation:
                if ($installation_file -like "*.msi") {
                    Execute-MSI -Action 'Install' -Path "$($installation_file.fullname)" -WindowStyle 'Hidden'
                    Start-Sleep -Seconds 5
                }
                ## Exe dependency install: should make an attempt to get the installation switches, or use S if no silentswitches are provided.
                else {
                    Execute-Process -Path "$($installation_file.fullname)" -Parameters "$silentswitches"
                    Start-Sleep -Seconds 5
                }
            }
        }

        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Installation'

        $Zipped = $script_config.source_files_zipped

        if ($Zipped) {

            ## Zipped Folder saves on package size. Much slower installation because of decompression.
            $sourcefiles = Get-Childitem -Path "$dirFiles" -filter "$APPLICATION_NAME.zip" -file -erroraction silentlycontinue
            if (-not $sourcefiles) {
                Write-Log -Message "Couldn't find $APPLICATION_NAME.zip file in $dirFiles, exiting." -Severity 3
                Exit-Script -ExitCode 1
            }
            Write-Log -Message "Found $($sourcefiles.fullname), expanding archive to $SOURCE_FILE_DESTINATION."

            Expand-Archive -Path "$($sourcefiles.fullname)" -DestinationPath "C:\" -EA SilentlyContinue
        }
        elseif (Test-Path "$dirFiles\$APPLICATION_NAME" -PathType Container -ErrorAction SilentlyContinue) {
            Write-Log -Message "Using robocopy with /MIR to copy sources files to $SOURCE_FILE_DESTINATION." -Severity 2

            ## /MIR = /E plus /PURGE.../PURGE will erase files/directories that exist in destination but not in source
            robocopy /E /NFL /NDL /NJH /NJS "$dirFiles\$APPLICATION_NAME" "$SOURCE_FILE_DESTINATION"

            Write-Log -Message "Source files copied to $SOURCE_FILE_DESTINATION."
        }
        else {
            Write-Host "Source_files_zipped set to $Zipped, and couldn't find the regular/unzipped $APPLICATION_NAME folder in $dirFiles. Exiting script." -Severity 3
            Exit-Script -ExitCode 1
        }

        ##*===============================================
        ##* POST-INSTALLATION - creation of shortcuts, ACLs, registry keys, etc. 
        ##*===============================================
        [string]$installPhase = 'Post-Installation'

        ## Create shortcuts using shortcuts.json
        # $shortcuts_json = Get-Childitem -Path "$dirSupportFiles" -File "shortcuts.json" -File -ErrorAction SilentlyContinue
        $shortcuts_obj = $script_config.shortcuts

        # if (-not $shortcuts_json) {
        #     Write-Log -Message "Sorry, couldn't find shortcuts.json in $dirSupportFiles. This is not a good sign, IF you wanted shortcuts created for your application. If you did not want shortcuts, this is OK." -Severity 2
        #     Start-Sleep -Seconds 5
        # }
        # else {
        if ($shortcuts_obj.length -ge 1) {
            Write-Log -Message "Creating shortcuts using objects contained in $($shortcuts_json.fullname)."
            $shortcuts_json = Get-Content -Path "$($shortcuts_json.fullname)" -Raw | ConvertFrom-Json

            ForEach ($shortcut_obj in $shortcuts_json) {

                $splat = @{
                    "Path"         = $shortcut_obj.ShortcutLocation
                    "TargetPath"   = $shortcut_obj.ShortcutTarget
                    "IconLocation" = $shortcut_obj.ShortcutIconPath
                    "Description"  = $shortcut_obj.ShortcutDescription
                }

                New-Shortcut @splat
                Write-Log -Message "Created shortcut w/target: $shortcut_target, location on system: $shortcut_location."
            }
        }
        else {
            Write-Log -Message "No shortcuts specified for creation in $dirSupportFiles/$scriptconfig_file."
        }
        # }


        ## ACL variables:
        $acl_group = $script_config.acl_info.target_group
        $acl_permissions = $script_config.acl_info.assigned_permissions

        Write-Log -Message "Configuring ACL to give $acl_group $acl_permissions permissions to $SOURCE_FILE_DESTINATION." -Severity 2

        ## Configure ACL for SOURCE_FILE_DESTINATION
        $acl = Get-ACL -Path "$SOURCE_FILE_DESTINATION"
        # $Everyone_AccessRule = [System.Security.AccessControl.FileSystemAccessRule]::new("Everyone", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
        # $App_Access_Rule = [System.Security.AccessControl.FileSystemAccessRule]::new("$APP_USERS_GROUP", "ReadAndExecute, Write, Modify", "ContainerInherit, ObjectInherit", "None", "Allow")
        $App_Access_Rule = [System.Security.AccessControl.FileSystemAccessRule]::new("$acl_group", "$acl_permissions", "ContainerInherit, ObjectInherit", "None", "Allow")

        $acl.AddAccessRule($App_Access_Rule)
        $acl | Set-ACL -Path "$SOURCE_FILE_DESTINATION"

        ## Create an Uninstall Key in the Registry at: HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\(($appname$))
        ## uses uninstall_reg_key.json to create the key.
        # $uninstall_reg_json = Get-ChildItem -Path "$dirSupportFiles" -Filter "uninstall_reg_key.json" -File -ErrorAction SilentlyContinue
        $uninstall_key_obj = $script_config.uninstall_key
        # if (-not $uninstall_reg_json) {
        #     Write-Log -Message "Sorry, couldn't find uninstall_reg_key.json in $dirSupportFiles. This is not a good sign, IF you wanted an uninstall key created for your application. If you did not want an uninstall key, this is OK." -Severity 2
        #     Start-Sleep -Seconds 5
        # }
        # else {
        if ($uninstall_key_obj.length -ge 1) {
            Write-Log -Message "Creating uninstall registry entry for $APPLICATION_NAME."

            New-Folder -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$APPLICATION_NAME"
            # $uninstall_reg_json = Get-Content -Path "$($uninstall_reg_json.fullname)" -Raw | ConvertFrom-Json

            ForEach ($item in $uninstall_key_obj) {
                Set-RegistryKey -Key "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$APPLICATION_NAME" -Name $item.Name -Value $item.Value -Type $item.Type
            }
            Write-Log -Message "Creatied uninstall registry key at HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$APPLICATION_NAME."
        }
        # }  

        ## Compile the uninstall.exe using PS2EXE
        
        $uninstall_exe_script = @"

        Write-Host "Removing any existing directory at: $SOURCE_FILE_DESTINATION."
        ForEach (`$installation_dir in @(
                "$SOURCE_FILE_DESTINATION",
                "C:\Users\Public\Desktop\$APPLICATION_NAME",
                "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\$APPLICATION_NAME"
            )) {
            # Remove-Folder -Path "`$installation_dir"
            Remove-Item -Path "`$installation_dir*" -Force -Recurse -ErrorAction SilentlyContinue
        }

        Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$APPLICATION_NAME" -Recurse -Force -ErrorAction SilentlyContinue

"@
        if (-not (Get-PAckageProvider -Name 'Nuget' -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        }
        if (-not (Get-Module -Name PS2EXE -ListAvailable -ErrorAction SilentlyContinue)) {
            Install-Module -Name PS2EXE -Force
        }

        $uninstall_exe_script | Out-File -FilePath "$dirFiles\uninstall.ps1" -Force
        $uninstall_exe_script = "$dirFiles\uninstall.ps1"
        $uninstall_exe = "$SOURCE_FILE_DESTINATION\uninstall.exe"

        Write-Log -Message "Creating uninstall.exe using PS2EXE."

        Invoke-PS2exe $uninstall_exe_script $uninstall_exe -requireAdmin -Description "Uninstall the $APPLICATION_NAME application."

        ## Restart Windows Explorer
        Update-Desktop

        Show-InstallationPrompt -Message "Installation of $APPLICATION_NAME has completed.`rThank you for your patience, and have a great day!" -ButtonRightText 'OK' -Icon Information -NoWait

    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Uninstallation'

        $script_config = Get-Content $scriptconfig_file -Raw | ConvertFrom-Json

        ## Create variables:
        $SOURCE_FILE_DESTINATION = $script_config.source_destination
        $APPLICATION_NAME = $script_config.application_name

        $SOURCE_FILE_DESTINATION = Join-Path -Path "$SOURCE_FILE_DESTINATION" -ChildPath "$APPLICATION_NAME"

        ## Show Welcome Message, Close (($appname$)) With a 60 Second Countdown Before Automatically Closing
        Show-InstallationWelcome -CloseApps '(($exe$))' -CloseAppsCountdown 60

        ## Show Progress Message (With a Message to Indicate the Application is Being Uninstalled)
        Show-InstallationProgress -StatusMessage "Uninstalling the $appName Application. Please Wait..."

        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Uninstallation'

        ## Remove the application directory and any shortcuts
        Write-Log -Message "Removing any existing directory at: $SOURCE_FILE_DESTINATION."
        ForEach ($installation_dir in @(
                "$SOURCE_FILE_DESTINATION",
                "C:\Users\Public\Desktop\$APPLICATION_NAME",
                "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\$APPLICATION_NAME"
            )) {
            # Remove-Folder -Path "$installation_dir"
            Remove-Item -Path "$installation_dir*" -Recurse -ErrorAction SilentlyContinue
        }

        if ($UseBackup) {
            $SOURCE_BACKUP_DIR = Join-Path -Path "$SOURCE_BACKUP_DIR" -ChildPath "$APPLICATION_NAME"

            Remove-Item -Path "$SOURCE_BACKUP_DIR" -Recurse -Force
        }


        ## Remove the uninstall registry key
        Remove-RegistryKey -Key "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$APPLICATION_NAME" -Recurse -Force

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
