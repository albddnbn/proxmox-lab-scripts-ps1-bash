function Get-ComputersLDAP {
    <#
    .SYNOPSIS
        Generates executable using the PS2exe powershell module that will map a printer.
        Either PrinterLogic or on print server, specified by $PrinterType parameter.

    .DESCRIPTION
        PrinterLogic  - Printer Installer Client software must be installed on machines where executable is being used.
        Print servers - Print server must be accessible over the network, on machines where executable will be used.

    .PARAMETER Printername
        Name of the printer to map. Ex: 'printer-c136-01'
        PrinterLogic - needs to match printer's name as listed in PrinterLogic Printercloud instance.
        Print server - needs to match printer's hostname as listed in print server and on DNS server.

    .PARAMETER PrinterType
        Set to 'printerlogic' or the name of a printer server, ex: 's-ps-02', 'org-printserv-001'

    .EXAMPLE
        Generate-PrinterLogicExe -PrinterName "printer-c136-01"

    .NOTES
        Executable will be created in the 'executables' directory.
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    param(
        [parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    # process {
    try {

        if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
            Write-Error "Security group filtering won't work because `$env:USERDNSDOMAIN is not available!"
            Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
        }
        else {

            # if no domain specified fallback to PowerShell environment variable
            if ([string]::IsNullOrEmpty($searchRoot)) {
                $searchRoot = $env:USERDNSDOMAIN
            }

            $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
            $searcher.Filter = "(&(objectclass=computer)(cn=$ComputerName*))"
            $searcher.SearchRoot = "LDAP://$searchRoot"
            # $distinguishedName = $searcher.FindOne().Properties.distinguishedname
            # $searcher.Filter = "(member:1.2.840.113556.1.4.1941:=$distinguishedName)"

            [void]$searcher.PropertiesToLoad.Add("name")

            $list = [System.Collections.Generic.List[String]]@()

            $results = $searcher.FindAll()
            foreach ($result in $results) {
                $resultItem = $result.Properties
                [void]$List.add($resultItem.name)
            }

            return $list

        }
    }
    catch {
        #Nothing we can do
        Write-Warning $_.Exception.Message
        return $null
    }
    # }
}

Export-ModuleMember -Function Get-ComputersLDAP

function Get-AssetInformation {
    <#
    .SYNOPSIS
        Attempts to use Dell Command Configure to get asset tag, if not available uses built-in powershell cmdlets.

    .DESCRIPTION
        Function will work as a part of the Terminal menu or outside of it.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER OutputFile
        'n' = terminal output only
        Entering anything else will create an output file in the 'reports' directory, in a folder with name based on function name, and OutputFile input.
        Ex: Outputfile = 'A220', output file(s) will be in $env:PSMENU_DIR\reports\AssetInfo - A220\

    .EXAMPLE
        Get-AssetInformation

    .EXAMPLE
        Get-AssetInformation -TargetComputer s-c127-01 -Outputfile C127-01-AssetInfo

    .NOTES
        Monitor details show up in .csv but not .xlsx right now - 12.1.2023
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [string]$Outputfile = ''
    )
    ## 1. Handling TargetComputer input if not supplied through pipeline.
    ## 2. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
    ## 3. Define scriptblock that retrieves asset info from local computer.
    ## 4. Create empty results container.
    BEGIN {
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
        
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        ## 2. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        $str_title_var = "AssetInfo"
        if ($Outputfile.tolower() -eq 'n') {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
        }
        else {
            if ((Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) -and ($null -ne $env:PSMENU_DIR)) {
                if ($Outputfile.toLower() -eq '') {
                    $REPORT_DIRECTORY = "$str_title_var"
                }
                else {
                    $REPORT_DIRECTORY = $outputfile            
                }
                $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
                if ($outputfile.tolower() -eq '') {
                    $iterator_var = 0
                    while ($true) {
                        $outputfile = "reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$thedate"
                        if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                            $iterator_var++
                            $outputfile = "reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$([string]$iterator_var)"


                        }
                        else {
                            break
                        }
                    }

                    if (-not (Test-Path $($outputfile | split-path -parent) -ErrorAction SilentlyContinue)) {
                        New-Item -ItemType Directory -Path $($outputfile | split-path -parent) | Out-Null
                    }
                }
            }
        }
        ## 3. Asset info scriptblock used to get local asset info from each target computer.
        $asset_info_scriptblock = {
            # computer model (ex: 'precision 3630 tower'), BIOS version, and BIOS release date
            $computer_model = get-ciminstance -class win32_computersystem | select -exp model
            $biosversion = get-ciminstance -class win32_bios | select -exp smbiosbiosversion
            $bioreleasedate = get-ciminstance -class win32_bios | select -exp releasedate
            # Asset tag from BIOS (tested with dell computer)
            try {
                $command_configure_exe = Get-ChildItem -Path "${env:ProgramFiles(x86)}\Dell\Command Configure\x86_64" -Filter "cctk.exe" -File -ErrorAction Silentlycontinue
                # returns a string like: 'Asset=2001234'
                $asset_tag = &"$($command_configure_exe.fullname)" --asset
                $asset_tag = $asset_tag -replace 'Asset=', ''
            }
            catch {
                $asset_tag = Get-Ciminstance -class win32_systemenclosure | select -exp smbiosassettag
                # asus motherboard returned 'default string'
                if ($asset_tag.ToLower() -eq 'default string') {
                    $asset_tag = 'No asset tag set in BIOS'
                }    
            }
            $computer_serial_num = get-ciminstance -class win32_bios | select -exp serialnumber
            # get monitor info and create a string from it (might be unnecessary, or a lengthy approach):
            $monitors = Get-CimInstance WmiMonitorId -Namespace root\wmi -ComputerName $ComputerName | Select Active, ManufacturerName, UserFriendlyName, SerialNumberID, YearOfManufacture
            $monitor_string = ""
            $monitor_count = 0
            $monitors | ForEach-Object {
                $_.UserFriendlyName = [System.Text.Encoding]::ASCII.GetString($_.UserFriendlyName)
                $_.SerialNumberID = [System.Text.Encoding]::ASCII.GetString($_.SerialNumberID -notmatch 0)
                $_.ManufacturerName = [System.Text.Encoding]::ASCII.GetString($_.ManufacturerName)
                $manufacturername = $($_.ManufacturerName).trim()
                $monitor_string += "Maker: $manufacturername,Mod: $($_.UserFriendlyName),Ser: $($_.SerialNumberID),Yr: $($_.YearOfManufacture)"
                $monitor_count++
            }
        
            $obj = [PSCustomObject]@{
                model               = $computer_model
                biosversion         = $biosversion
                bioreleasedate      = $bioreleasedate
                asset_tag           = $asset_tag
                computer_serial_num = $computer_serial_num
                monitors            = $monitor_string
                NumMonitors         = $monitor_count
            }
            return $obj
        }
        ## 4. Create empty results container
        $results = [system.collections.arraylist]::new()
        write-host "$($Targetcomputer -join ', ')" -ForegroundColor cyan

    }
    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. If machine was responsive, Collect local asset information from computer
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {
            if ($single_computer) {

                ## test with ping first:
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {
                    Write-Host "Pinged $single_computer successfully, attempting to get asset info."
                    $target_asset_info = Invoke-Command -ComputerName $single_computer -ScriptBlock $asset_info_scriptblock | Select PSComputerName, * -ExcludeProperty RunspaceId, PSshowcomputername -ErrorAction SilentlyContinue
                    if ($target_asset_info) {
                        $results.add($target_asset_info) | out-null
                    }
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer didn't respond to one ping, skipping." -ForegroundColor Yellow
                }
            }
        }
    }

    ## 1. If there were any results - output them to terminal and/or report files as necessary.
    END {
        if ($results) {
            ## Sort the results
            $results = $results | sort -property pscomputername
            if ($outputfile.tolower() -eq 'n') {
                $results | out-gridview -Title $str_title_var
            }
            else {
                $results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation
                ## Try ImportExcel
                try {
                    ## xlsx attempt:
                    $params = @{
                        AutoSize             = $true
                        TitleBackgroundColor = 'Blue'
                        TableName            = $str_title_var
                        TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                        BoldTopRow           = $true
                        WorksheetName        = $str_title_var
                        PassThru             = $true
                        Path                 = "$Outputfile.xlsx" # => Define where to save it here!
                    }
                    $Content = Import-Csv "$Outputfile.csv"
                    $xlsx = $Content | Export-Excel @params # -ErrorAction SilentlyContinue
                    $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
                    $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
                    Close-ExcelPackage $xlsx
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: ImportExcel module not found, skipping xlsx creation." -Foregroundcolor Yellow
                }
                Invoke-item "$($outputfile | split-path -Parent)"
            }
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        Read-Host "Press enter to return results."
        return $results
    }
}

Export-ModuleMember -Function Get-AssetInformation

function Get-ComputerDetails {
    <#
    .SYNOPSIS
        Collects: Manufacturer, Model, Current User, Windows Build, BIOS Version, BIOS Release Date, and Total RAM from target machine(s).
        Outputs: A .csv and .xlsx report file if anything other than 'n' is supplied for the $OutputFile parameter.

    .DESCRIPTION

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER OutputFile
        'n' or 'N' = terminal output only
        Entering anything else will create an output file in the 'reports' directory, in a folder with name based on function name, and OutputFile input.
        Ex: Outputfile = 'A220-Info', output file(s) will be in the $env:PSMENU_DIR\reports\2023-11-1\A220-Info\ directory.

    .EXAMPLE
        Output details for a single hostname to "sa227-28-details.csv" and "sa227-28-details.xlsx" in the 'reports' directory.
        Get-ComputerDetails -TargetComputer "t-client-28" -Outputfile "tclient-28-details"

    .EXAMPLE
        Output details for all hostnames starting with g-pc-0 to terminal.
        Get-ComputerDetails -TargetComputer 'g-pc-0' -outputfile 'n'

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [string]$Outputfile
    )

    ## 1. define date variable (used for filename creation)
    ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
    ## 3. Outputfile path needs to be created regardless of how Targetcomputer is submitted to function
    BEGIN {
        ## 1. define date variable (used for filename creation)
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
        
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }
        ## 3. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        $str_title_var = "PCdetails"
        if ($Outputfile.tolower() -eq 'n') {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
        }
        else {
            if ((Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) -and ($null -ne $env:PSMENU_DIR)) {
                if ($Outputfile.toLower() -eq '') {
                    $REPORT_DIRECTORY = "$str_title_var"
                }
                else {
                    $REPORT_DIRECTORY = $outputfile            
                }
                $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
                if ($outputfile.tolower() -eq '') {
                    $iterator_var = 0
                    while ($true) {
                        $outputfile = "reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$thedate"
                        if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                            $iterator_var++
                            $outputfile += "$([string]$iterator_var)"
                        }
                        else {
                            break
                        }
                    }


                }
                try {
                    $outputdir = $outputfile | split-path -parent
                    if (-not (Test-Path $outputdir -ErrorAction SilentlyContinue)) {
                        New-Item -ItemType Directory -Path $($outputfile | split-path -parent) | Out-Null
                    }
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $Outputfile has no parent directory." -Foregroundcolor Yellow
                }


            }
        }
        ## 4. Create empty results container
        $results = [system.collections.arraylist]::new()
    }

    ## Collects computer details from specified computers using CIM commands  
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {
            if ($single_computer) {
                # ping test
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {

                    ## Save results to variable
                    $single_result = Invoke-Command -ComputerName $single_computer -Scriptblock {
                        # Gets active user, computer manufacturer, model, BIOS version & release date, Win Build number, total RAM, last boot time, and total system up time.
                        # object returned to $results list
                        $computersystem = Get-CimInstance -Class Win32_Computersystem
                        $bios = Get-CimInstance -Class Win32_BIOS
                        $operatingsystem = Get-CimInstance -Class Win32_OperatingSystem

                        $lastboot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
                        $uptime = ((Get-Date) - $lastboot).ToString("dd\.hh\:mm\:ss")
                        $obj = [PSCustomObject]@{
                            Manufacturer    = $($computersystem.manufacturer)
                            Model           = $($computersystem.model)
                            CurrentUser     = $((get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username)
                            WindowsBuild    = $($operatingsystem.buildnumber)
                            BiosVersion     = $($bios.smbiosbiosversion)
                            BiosReleaseDate = $($bios.releasedate)
                            TotalRAM        = $((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum / 1gb)
                            LastBoot        = $lastboot
                            SystemUptime    = $uptime
                        }
                        $obj
                    } | Select PSComputerName, * -ExcludeProperty RunspaceId, PSshowcomputername -ErrorAction SilentlyContinue

                    $results.add($single_result) | out-null
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is offline." -Foregroundcolor Yellow
                }
            }
        }
    }

    ## Output of results to CSV, XLSX, terminal, or gridview depending on the $OutputFile parameter
    END {
        if ($results) {
            ## Sort the results
            $results = $results | sort -property pscomputername
            if ($outputfile.tolower() -eq 'n') {
                # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
                if ($results.count -le 2) {
                    $results | Format-List
                    # $results | Out-GridView
                }
                else {
                    $results | out-gridview -Title $str_title_var
                }
            }
            else {
                $results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation
                ## Try ImportExcel
                try {
                    ## xlsx attempt:
                    $params = @{
                        AutoSize             = $true
                        TitleBackgroundColor = 'Blue'
                        TableName            = $str_title_var
                        TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                        BoldTopRow           = $true
                        WorksheetName        = $str_title_var
                        PassThru             = $true
                        Path                 = "$Outputfile.xlsx" # => Define where to save it here!
                    }
                    $Content = Import-Csv "$Outputfile.csv"
                    $xlsx = $Content | Export-Excel @params
                    $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
                    $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
                    Close-ExcelPackage $xlsx
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: ImportExcel module not found, skipping xlsx creation." -Foregroundcolor Yellow
                }
                try {
                    Invoke-item "$($outputfile | split-path -Parent)"
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Could not open output folder." -Foregroundcolor Yellow
                    Invoke-item "$outputfile.csv"
                }
            }
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        Read-Host "Press enter to return results."
        return $results
    }
}

Export-ModuleMember -Function Get-ComputerDetails

function Get-ConnectedPrinters {
    <#
    .SYNOPSIS
        Checks the target computer, and returns the user that's logged in, and the printers that user has access to.

    .DESCRIPTION
        This function, unlike some others, only takes a single string DNS hostname of a target computer.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER OutputFile
        'n' or 'no' = terminal output only
        Entering anything else will create an output file in the 'reports' directory, in a folder with name based on function name, and OutputFile input.
        Ex: Outputfile = 'A220', output file(s) will be in $env:PSMENU_DIR\reports\AssetInfo - A220\

    .PARAMETER FolderTitleSubstring
        If specified, the function will create a folder in the 'reports' directory with the specified substring in the title, appended to the $REPORT_DIRECTORY String (relates to the function title).

    .EXAMPLE
        Get-ConnectedPrinters -TargetComputer 't-client-07'

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [string]$Outputfile = ''
    )

    ## 1. Handle Targetcomputer input if it's not supplied through pipeline.
    ## 2. Create output filepath if necessary.
    ## 3. Scriptblock that is executed on each target computer to retrieve connected printer info.
    BEGIN {
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
        
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }      
        
        ## 2. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        $str_title_var = "Printers"
        if ($Outputfile.tolower() -eq 'n') {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
        }
        else {
            if ((Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) -and ($null -ne $env:PSMENU_DIR)) {
                if ($Outputfile.toLower() -eq '') {
                    $REPORT_DIRECTORY = "$str_title_var"
                }
                else {
                    $REPORT_DIRECTORY = $outputfile            
                }
                $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
                if ($outputfile.tolower() -eq '') {
                    $iterator_var = 0
                    while ($true) {
                        $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$thedate"
                        if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                            $iterator_var++
                            $outputfile += "$([string]$iterator_var)"
                        }
                        else {
                            break
                        }
                    }
                }
                ## Try to get output directory path and make sure it exists.
                try {
                    $outputdir = $outputfile | split-path -parent
                    if (-not (Test-Path $outputdir -ErrorAction SilentlyContinue)) {
                        New-Item -ItemType Directory -Path $($outputfile | split-path -parent) | Out-Null
                    }
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $Outputfile has no parent directory." -Foregroundcolor Yellow
                }
            }
        }
        ## 3. Scriptblock - lists connected/default printers
        $list_local_printers_block = {
            # Everything will stay null, if there is no user logged in
            $obj = [PScustomObject]@{
                Username          = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username
                DefaultPrinter    = $null
                ConnectedPrinters = $null
            }

            # Only need to check for connected printers if a user is logged in.
            if ($obj.Username) {
                # get connected printers:
                get-ciminstance -class win32_printer | select name, Default | ForEach-Object {
                    if (($_.name -notin ('Microsoft Print to PDF', 'Fax')) -and ($_.name -notlike "*OneNote*")) {
                        if ($_.name -notlike "Send to*") {
                            $obj.ConnectedPrinters = "$($obj.ConnectedPrinters), $($_.name)"
                        }
                    }   
                }
            }
            $obj
        }
        ## Create empty results container to use during process block
        $results = [system.collections.arraylist]::new()
    }

    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. If machine was responseive, run the 'get connected printers' scriptblock.
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {
            ## 1. TargetComputer can't be $null or '', it will display error during test-connection
            if ($single_computer) {
                ## 2. Single ping test to target computer
                $pingreply = Test-connection $single_computer -Count 1 -Quiet
                if ($pingreply) {
                    ## 3. If computer responded - collect printer info and add to results list.
                    $connected_printer_info = Invoke-Command -ComputerName $single_computer -Scriptblock $list_local_printers_block | Select PSComputerName, * -ExcludeProperty RunspaceId, PSshowcomputername -ErrorAction SilentlyContinue
                    $results.Add($connected_printer_info) | out-null
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer didn't respond to one ping, skipping." -Foregroundcolor Yellow
                }
            }
        }
    }

    ## 1. If there are results - sort them by the hostname (pscomputername) property.
    ## 2. If the user specified 'n' for outputfile - just output to terminal or gridview.
    ## 3. Create .csv/.xlsx reports as necessary.
    END {
        if ($results) {
            ## 1. Sort any existing results by computername
            $results = $results | sort -property pscomputername
            ## 2. Output to gridview if user didn't choose report output.
            if ($outputfile.tolower() -eq 'n') {
                $results | out-gridview -Title $str_title_var
            }
            else {
                ## 3. Create .csv/.xlsx reports if possible
                $results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation
                ## Try ImportExcel
                try {
                    $params = @{
                        AutoSize             = $true
                        TitleBackgroundColor = 'Blue'
                        TableName            = $str_title_var
                        TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                        BoldTopRow           = $true
                        WorksheetName        = $str_title_var
                        PassThru             = $true
                        Path                 = "$Outputfile.xlsx" # => Define where to save it here!
                    }
                    $Content = Import-Csv "$Outputfile.csv"
                    $xlsx = $Content | Export-Excel @params
                    $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
                    $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
                    Close-ExcelPackage $xlsx
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: ImportExcel module not found, skipping xlsx creation." -Foregroundcolor Yellow
                }
                ## Try opening directory (that might contain xlsx and csv reports), default to opening csv which should always exist
                try {
                    Invoke-item "$($outputfile | split-path -Parent)"
                }
                catch {
                    # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Could not open output folder." -Foregroundcolor Yellow
                    Invoke-item "$outputfile.csv"
                }
            }
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        Read-Host "Press enter to return results."
        return $results
    }
}

Export-ModuleMember -Function Get-ConnectedPrinters

function Get-CurrentUser {
    <#
    .SYNOPSIS
        Gets user logged into target system(s).
        Checks if teams or zoom processes are running and returns True/False for each in report/terminal output.

    .DESCRIPTION
        Creates report with current user, computer model, and if Teams or Zoom are running.
        If no output file is specified, terminal output only ($Outputfile = 'n').

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: g-labpc- will create a list of all hostnames that start with 
        g-labpc- (g-labpc-01. g-labpc-02, g-labpc-03..).

    .PARAMETER OutputFile
        'n' = terminal output only
        Entering anything else will create an output file in the 'reports' directory, in a folder with name based on function name, and OutputFile input.
        Ex: Outputfile = 'A220', output file(s) will be in $env:PSMENU_DIR\reports\AssetInfo - A220\

    .EXAMPLE
        1. Get users on all S-A231 computers:
        Get-CurrentUser -Targetcomputer "s-a231-"

    .EXAMPLE
        2. Get user on a single target computer:
        Get-CurrentUser -TargetComputer "t-client-28"

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [string]$Outputfile = ''
    )
    ## 1. Handle Targetcomputer input if it's not supplied through pipeline.
    ## 2. Create output filepath if necessary.
    ## 3. Create empty results arraylist to hold results from each target machine (collected during the PROCESS block).
    BEGIN {
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
        
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        ## 2. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        $str_title_var = "CurrentUsers"
        if ($Outputfile.tolower() -eq 'n') {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
        }
        else {
            if ((Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) -and ($null -ne $env:PSMENU_DIR)) {
                if ($Outputfile.toLower() -eq '') {
                    $REPORT_DIRECTORY = "$str_title_var"
                }
                else {
                    $REPORT_DIRECTORY = $outputfile            
                }
                $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
                if ($outputfile.tolower() -eq '') {
                    $iterator_var = 0
                    while ($true) {
                        $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$thedate"
                        if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                            $iterator_var++
                            $outputfile += "$([string]$iterator_var)"
                        }
                        else {
                            break
                        }
                    }
                }
                ## Try to get output directory path and make sure it exists.
                try {
                    $outputdir = $outputfile | split-path -parent
                    if (-not (Test-Path $outputdir -ErrorAction SilentlyContinue)) {
                        New-Item -ItemType Directory -Path $($outputfile | split-path -parent) | Out-Null
                    }
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $Outputfile has no parent directory." -Foregroundcolor Yellow
                }
            }
        }

        ## 3. Create empty results container
        $results = [system.collections.arraylist]::new()
    }

    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. If machine was responseive, run scriptblock to logged in user, info on teams/zoom processes, etc.
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            ## 1. empty Targetcomputer values will cause errors to display during test-connection / rest of code
            if ($single_computer) {
                ## 2. Send one test ping
                $ping_result = Test-Connection $single_computer -count 1 -Quiet
                if ($ping_result) {
                    # Get Computers details and create an object
                    $logged_in_user_info = Invoke-Command -ComputerName $single_computer -Scriptblock {
                        $obj = [PSCustomObject]@{
                            Model        = (get-ciminstance -class win32_computersystem).model
                            CurrentUser  = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username
                            TeamsRunning = $(if (Get-PRocess -Name 'Teams' -ErrorAction SilentlyContinue) { $true } else { $false })
                            ZoomRunning  = $(if (Get-PRocess -Name 'Zoom' -ErrorAction SilentlyContinue) { $true } else { $false })

                        }
                        $obj
                    } | Select PSComputerName, * -ExcludeProperty RunspaceId, PSshowcomputername -ErrorAction SilentlyContinue
                    $results.add($logged_in_user_info) | out-null
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is offline." -Foregroundcolor Yellow
                }
            }
        }
    }
    ## 1. If there are results - sort them by the hostname (pscomputername) property.
    ## 2. If the user specified 'n' for outputfile - just output to terminal or gridview.
    ## 3. Create .csv/.xlsx reports as necessary.
    END {
        if ($results) {
            ## 1. Sort any existing results by computername
            $results = $results | sort -property pscomputername
            ## 2. Output to gridview if user didn't choose report output.
            if ($outputfile.tolower() -eq 'n') {
                $results | out-gridview -title $str_title_var
            }
            else {
                ## 3. Create .csv/.xlsx reports if possible
                $results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation
                ## Try ImportExcel
                try {
                    $params = @{
                        AutoSize             = $true
                        TitleBackgroundColor = 'Blue'
                        TableName            = $str_title_var
                        TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                        BoldTopRow           = $true
                        WorksheetName        = $str_title_var
                        PassThru             = $true
                        Path                 = "$Outputfile.xlsx" # => Define where to save it here!
                    }
                    $Content = Import-Csv "$Outputfile.csv"
                    $xlsx = $Content | Export-Excel @params
                    $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
                    $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
                    Close-ExcelPackage $xlsx
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: ImportExcel module not found, skipping xlsx creation." -Foregroundcolor Yellow
                }
                ## Try opening directory (that might contain xlsx and csv reports), default to opening csv which should always exist
                try {
                    Invoke-item "$($outputfile | split-path -Parent)"
                }
                catch {
                    # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Could not open output folder." -Foregroundcolor Yellow
                    Invoke-item "$outputfile.csv"
                }
            }
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        Read-Host "Press enter to return results."
        return $results
    }
}

Export-ModuleMember -Function Get-CurrentUser

function Get-InstalledDotNetversions {
    <#
    .SYNOPSIS
        Gets a list of installed dotnet versions on target computers. Returns results.

    .DESCRIPTION
        Creates report if anything except 'n' is supplied for Outputfile.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: g-labpc- will create a list of all hostnames that start with 
        g-labpc- (g-labpc-01. g-labpc-02, g-labpc-03..).

    .PARAMETER OutputFile
        'n' = terminal output only
        Entering anything else will create an output file in the 'reports' directory, in a folder with name based on function name, and OutputFile input.
        Ex: Outputfile = 'A220', output file(s) will be in $env:PSMENU_DIR\reports\AssetInfo - A220\

    .EXAMPLE
        1. Get dotnet versions on single computer, output results to terminal/gridview
        Get-InstalledDotNetVersions -TargetComputer "t-client-01" -outputfile 'n'

    .EXAMPLE
        2. Get user on group of computers with hostnames starting with t-client-, output default filename reports
        Get-InstalledDotNetVersions -TargetComputer "t-client-" -outputfile ''

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [string]$Outputfile = ''
    )
    ## 1. Handle Targetcomputer input if it's not supplied through pipeline.
    ## 2. Create output filepath if necessary.
    ## 3. Create empty results arraylist to hold results from each target machine (collected during the PROCESS block).
    BEGIN {
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
        
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        ## 2. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        $str_title_var = "InstalledDotNet"
        if ($Outputfile.tolower() -eq 'n') {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
        }
        else {
            if ((Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) -and ($null -ne $env:PSMENU_DIR)) {
                if ($Outputfile.toLower() -eq '') {
                    $REPORT_DIRECTORY = "$str_title_var"
                }
                else {
                    $REPORT_DIRECTORY = $outputfile            
                }
                $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
                if ($outputfile.tolower() -eq '') {
                    $iterator_var = 0
                    while ($true) {
                        $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$thedate"
                        if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                            $iterator_var++
                            $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$([string]$iterator_var)"
                        }
                        else {
                            break
                        }
                    }
                }

                ## Try to get output directory path and make sure it exists.
                try {
                    $outputdir = $outputfile | split-path -parent
                    if (-not (Test-Path $outputdir -ErrorAction SilentlyContinue)) {
                        New-Item -ItemType Directory -Path $($outputfile | split-path -parent) | Out-Null
                    }
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $Outputfile has no parent directory." -Foregroundcolor Yellow
                }
            }
        }

        ## 3. Create empty results container
        $results = [system.collections.arraylist]::new()
    }

    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. If machine was responseive, run scriptblock to logged in user, info on teams/zoom processes, etc.
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            ## 1. empty Targetcomputer values will cause errors to display during test-connection / rest of code
            if ($single_computer) {
                ## 2. Send one test ping
                $ping_result = Test-Connection $single_computer -count 1 -Quiet
                if ($ping_result) {
                    # Get Computers details and create an object
                    $target_installed_dotnet = Invoke-Command -ComputerName $single_computer -Scriptblock {
                        Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | `
                            Get-ItemProperty -Name version -EA 0 | Where { $_.PSChildName -Match '^(?!S)\p{L}' } |`
                            Select PSChildName, version
                    } | Select PSComputerName, * -ExcludeProperty RunspaceId, PSshowcomputername -ErrorAction SilentlyContinue
                    $results.add($target_installed_dotnet) | out-null
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is offline." -Foregroundcolor Yellow
                }
            }
        }
    }
    ## 1. If there are results - sort them by the hostname (pscomputername) property.
    ## 2. If the user specified 'n' for outputfile - just output to terminal or gridview.
    ## 3. Create .csv/.xlsx reports as necessary.
    END {
        if ($results) {
            ## 1. Sort any existing results by computername
            $results = $results | sort -property pscomputername
            ## 2. Output to gridview if user didn't choose report output.
            if ($outputfile.tolower() -eq 'n') {
                $results | out-gridview -"Installed .NET Versions"
            }
            else {
                ## 3. Create .csv/.xlsx reports if possible
                $results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation
                ## Try ImportExcel
                try {
                    $params = @{
                        AutoSize             = $true
                        TitleBackgroundColor = 'Blue'
                        TableName            = $str_title_var
                        TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                        BoldTopRow           = $true
                        WorksheetName        = $str_title_var
                        PassThru             = $true
                        Path                 = "$Outputfile.xlsx" # => Define where to save it here!
                    }
                    $Content = Import-Csv "$Outputfile.csv"
                    $xlsx = $Content | Export-Excel @params
                    $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
                    $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
                    Close-ExcelPackage $xlsx
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: ImportExcel module not found, skipping xlsx creation." -Foregroundcolor Yellow
                }
                ## Try opening directory (that might contain xlsx and csv reports), default to opening csv which should always exist
                try {
                    Invoke-item "$($outputfile | split-path -Parent)"
                }
                catch {
                    # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Could not open output folder." -Foregroundcolor Yellow
                    Invoke-item "$outputfile.csv"
                }
            }
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        Read-Host "Press enter to return results."
        return $results
    }
}

Export-ModuleMember -Function Get-InstalledDotNetversions

Function Get-IntuneHardwareIDs {
    <#
    .SYNOPSIS
        Generates a .csv containing hardware ID info for target device(s), which can then be imported into Intune / Autopilot.
        If $Targetcomputer = '', function is run on local computer.
        Specify GroupTag using DeviceGroupTag parameter.

    .DESCRIPTION
        Uses Get-WindowsAutopilotInfo from: https://github.com/MikePohatu/Get-WindowsAutoPilotInfo/blob/main/Get-WindowsAutoPilotInfo.ps1
        Get-WindowsAutopilotInfo.ps1 is in the supportfiles directory, so it doesn't have to be installed/downloaded from online.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: g-labpc- will create a list of all hostnames that start with 
        g-labpc- (g-labpc-01. g-labpc-02, g-labpc-03..).

    .PARAMETER DeviceGroupTag
        Specifies the group tag that will be set in target devices' hardware ID info.
        DeviceGroupTag value is used with the -GroupTag parameter of Get-WindowsAutopilotInfo.

    .PARAMETER OutputFile
        Used to create the name of the output .csv file, output to local computer.
        If not supplied, an output filepath will be created using formatted string.

    .EXAMPLE
        Get Intune Hardware IDs from all computers in room A227 on Stanton campus:
        Get-IntuneHardwareIDs -TargetComputer "t-client-" -OutputFile "TClientIDs" -DeviceGroupTag 'Student Laptops'

    .EXAMPLE
        Get Intune Hardware ID of single target computer
        Get-IntuneHardwareIDs -TargetComputer "t-client-01" -OutputFile "TClient01-ID"

    .NOTES
        Needs utility functions and menu environment variables to run at this point in time.
        Basically just a wrapper for the Get-WindowsAutopilotInfo function, not created by abuddenb.
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [string]$OutputFile = '',
        [string]$DeviceGroupTag
    )
    ## 1. Set date and report directory variables.
    ## 2. Handle Targetcomputer input if it's not supplied through pipeline.
    ## 3. Create output filepath
    ## 4. Find Get-WindowsAutopilotInfo script and dot source - hopefully from Supportfiles.
    ##    *Making change soon to get rid of the Run-GetWindowsAutopilotinfo file / function setup [02-27-2024].
    BEGIN {
        ## 1. Date / Report Directory (for output file creation / etc.)
        $thedate = Get-Date -Format 'yyyy-MM-dd'

        ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
        
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        ## 3. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        if ((Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) -and ($null -ne $env:PSMENU_DIR)) {
            if ($Outputfile.toLower() -ne '') {
                $REPORT_DIRECTORY = "$outputfile"
            }
            else {
                $REPORT_DIRECTORY = "IntuneHardwareIDs"          
            }
            $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
            if ($outputfile.tolower() -eq '') {
                $iterator_var = 0
                while ($true) {
                    $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$REPORT_DIRECTORY-$thedate"
                    if ((Test-Path "$outputfile.csv" -ErrorAction Silentcontinue)) {
                        $iterator_var++
                        $outputfile += "$([string]$iterator_var)"                    
                    }
                    else {
                        break
                    }
                }
            }
            ## Try to get output directory path and make sure it exists.
            try {
                $outputdir = $outputfile | split-path -parent
                if (-not (Test-Path $outputdir -ErrorAction SilentlyContinue)) {
                    New-Item -ItemType Directory -Path $($outputfile | split-path -parent) | Out-Null
                }
            }
            catch {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $Outputfile has no parent directory." -Foregroundcolor Yellow
            }
        }

        ## make sure there's a .csv on the end of output file?
        if ($outputfile -notlike "*.csv") {
            $outputfile += ".csv"
        }
        ## 4. Find Get-WindowsAutopilotInfo script and dot source - hopefully from Supportfiles, will check internet if necessary.
        $getwindowsautopilotinfo = Get-ChildItem -Path "$env:SUPPORTFILES_DIR" -Filter "Get-WindowsAutoPilotInfo.ps1" -File -ErrorAction SilentlyContinue
        if (-not $getwindowsautopilotinfo) {
            # Attempt to download script if there's Internet
            $check_internet_connection = Test-NetConnection "google.com" -ErrorAction SilentlyContinue
            if ($check_internet_connection.PingSucceeded) {
                # check for nuget / install
                $check_for_nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
                if ($null -eq $check_for_nuget) {
                    # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: NuGet not found, installing now."
                    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
                }
                Install-Script -Name 'Get-WindowsAutopilotInfo' -Force 
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: " -NoNewline
                Write-Host "No internet connection detected, unable to generate hardware ID .csv." -ForegroundColor Red
                return
            }
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Get-WindowsAutopilotInfo.ps1 not found in supportfiles directory, unable to generate hardware ID .csv." -ForegroundColor Red
            return
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Found $($getwindowsautopilotinfo.fullname), importing.`r" -NoNewline
            Get-ChildItem "$env:SUPPORTFILES_DIR" -recurse | unblock-file
        }
    }

    ## 1/2. Filter Targetcomputer for null/empty values and ping test machine.
    ## 3. If machine was responsive:
    ##    - Attempt to use cmdlet to get hwid
    ##    - if Fails (unrecognized because wasn't installed using install-script)
    ##    - Execute from support files.
    ##    * I read that using a @splat like this for parameters gives you the advantage of having only one set to modify,
    ##      as opposed to having to modify two sets of parameters (one for each command in the try/catch)
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            ## 1. empty Targetcomputer values will cause errors to display during test-connection / rest of code
            if ($single_computer) {
                ## 2. Send one test ping
                $ping_result = Test-Connection $single_computer -count 1 -Quiet
                ## 3. Responsive machines...
                if ($ping_result) {
                    ## Define parameters to be used when executing Get-WindowsAutoPilotInfo
                    $params = @{
                        ComputerName = $single_computer
                        OutputFile   = "$outputfile"
                        GroupTag     = $DeviceGroupTag
                        Append       = $true
                    }
                    ## Attempt to use cmdlet from installing script from internet, if fails - revert to script in support 
                    ## files (it should have to exist at this point).
                    try {
                        . "$($getwindowsautopilotinfo.fullname)" @params
                    }
                    catch {
                        Get-WindowsAutoPilotInfo @params
                    }
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer didn't respond to one ping, skipping" -ForegroundColor Yellow
                }
            }
        }
    }
    ## 1. Open the folder that will contain reports if necessary.
    END {
        ## 1. Open reports folder
        ## Try opening directory (that might contain xlsx and csv reports), default to opening csv which should always exist
        try {
            Invoke-item "$($outputfile | split-path -Parent)"
        }
        catch {
            # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Could not open output folder." -Foregroundcolor Yellow
            Invoke-item "$outputfile"
        }

        Read-Host "Press enter to return to menu."
    }
}

Export-ModuleMember -Function Get-IntuneHardwareIDs

function Ping-TestReport {
    <#
    .SYNOPSIS
        Pings a group of computers a specified amount of times, and outputs the successes / total pings to a .csv and .xlsx report.

    .DESCRIPTION
        Script will output to ./reports/<date>/ folder. It calculates average response time, and packet loss percentage.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER PingCount
        Number of times to ping each computer.

    .PARAMETER OutputFile
        'n' or 'no' = terminal output only
        Entering anything else will create an output file in the 'reports' directory, in a folder with name based on function name, and OutputFile input.
        Ex: Outputfile = 'Room1', output file(s) will be in $env:PSMENU_DIR\reports\AssetInfo - Room1\

    .EXAMPLE
        Ping-TestReport -Targetcomputer "g-client-" -PingCount 10 -Outputfile "GClientPings"
    
    .EXAMPLE
        Ping-TestReport -Targetcomputer "g-client-" -PingCount 2

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        $PingCount,
        [string]$Outputfile = ''
    )
    ## 1. Set date and AM / PM variables
    ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
    ## 3. If provided, use outputfile input to create report output filepath.
    ## 4. Create arraylist to store results
    BEGIN {
        ## 1. Set date and AM / PM variables
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        $am_pm = (Get-Date).ToString('tt')

        ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
        
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        ## 2. If provided, use outputfile input to create report output filepath.
        ## Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        if ($outputfile) {
            $str_title_var = "$outputfile-$(Get-Date -Format 'hh-MM')$($am_pm)"
        }
        else {
            $str_title_var = "Pings-$(Get-Date -Format 'hh-MM')$($am_pm)"
        }

        if ($Outputfile.tolower() -eq 'n') {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
        }
        else {
            if ((Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) -and ($null -ne $env:PSMENU_DIR)) {
                if ($Outputfile.toLower() -eq '') {
                    $REPORT_DIRECTORY = "$str_title_var"
                }
                else {
                    $REPORT_DIRECTORY = $outputfile            
                }
                $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
                if ($outputfile.tolower() -eq '') {
                    $iterator_var = 0
                    while ($true) {
                        $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$str_title_var"
                        if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                            $iterator_var++
                            $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$([string]$iterator_var)"
                        }
                        else {
                            break
                        }
                    }
                }

                ## Try to get output directory path and make sure it exists.
                try {
                    $outputdir = $outputfile | split-path -parent
                    if (-not (Test-Path $outputdir -ErrorAction SilentlyContinue)) {
                        New-Item -ItemType Directory -Path $($outputfile | split-path -parent) | Out-Null
                    }
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $Outputfile has no parent directory." -Foregroundcolor Yellow
                }
            }
        }
        ## 3. Create arraylist to store results
        $results = [system.collections.arraylist]::new()

        $PingCount = [int]$PingCount
    }

    ## 1. Ping EACH Target computer / record results into ps object, add to arraylist (results_container)
    ## 2. Set object property values:
    ## 3. Send pings - object property values are derived from resulting object
    ## 4. Number of responses
    ## 5. Calculate average response time for successful responses
    ## 6. Calculate packet loss percentage
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {
            ## 1. empty Targetcomputer values will cause errors to display during test-connection / rest of code
            if ($single_computer) {
                ## 2. Create object to store results of ping test on single machine
                $obj = [pscustomobject]@{
                    Sourcecomputer       = $env:COMPUTERNAME
                    ComputerHostName     = $single_computer
                    TotalPings           = $pingcount
                    Responses            = 0
                    AvgResponseTime      = 0
                    PacketLossPercentage = 0
                }
                ## 3. Send $PINGCOUNT number of pings to target device, store results
                $send_pings = Test-Connection -ComputerName $single_computer -count $PingCount -ErrorAction SilentlyContinue
                ## 4. Set number of responses from target machine
                $obj.responses = $send_pings.count
                ## 5. Calculate average response time for successful responses
                $sum_of_response_times = $($send_pings | measure-object responsetime -sum)
                if ($obj.Responses -eq 0) {
                    $obj.AvgResponseTime = 0
                }
                else {
                    $obj.avgresponsetime = $sum_of_response_times.sum / $obj.responses
                }
                ## 6. Calculate packet loss percentage - divide total pings by responses
                $total_drops = $obj.TotalPings - $obj.Responses
                $obj.PacketLossPercentage = ($total_drops / $($obj.TotalPings)) * 100

                ## 7. Add object to container created in BEGIN block
                $results.add($obj) | Out-Null
            }
        }
    }

    ## Report file creation or terminal output
    END {
        if ($results) {
            ## 1. Sort any existing results by computername
            $results = $results | sort -property pscomputername
            ## 2. Output to gridview if user didn't choose report output.
            if ($outputfile.tolower() -eq 'n') {
                $results | out-gridview
            }
            else {
                ## 3. Create .csv/.xlsx reports if possible
                $results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation
                ## Try ImportExcel
                try {
                    $params = @{
                        AutoSize             = $true
                        TitleBackgroundColor = 'Blue'
                        TableName            = $str_title_var
                        TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                        BoldTopRow           = $true
                        WorksheetName        = $str_title_var
                        PassThru             = $true
                        Path                 = "$Outputfile.xlsx" # => Define where to save it here!
                    }
                    $Content = Import-Csv "$Outputfile.csv"
                    $xlsx = $Content | Export-Excel @params
                    $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
                    $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
                    Close-ExcelPackage $xlsx
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: ImportExcel module not found, skipping xlsx creation." -Foregroundcolor Yellow
                }
                ## Try opening directory (that might contain xlsx and csv reports), default to opening csv which should always exist
                try {
                    Invoke-item "$($outputfile | split-path -Parent)"
                }
                catch {
                    # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Could not open output folder." -Foregroundcolor Yellow
                    Invoke-item "$outputfile.csv"
                }
            }
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        Read-Host "`nPress [ENTER] to return results."
        return $results
    }
}

Export-ModuleMember -Function Ping-TestReport

function Scan-ForAppOrFilePath {
    <#
    .SYNOPSIS
        Scan a group of computers for a specified file/folder or application, and output the results to a .csv and .xlsx report.

    .DESCRIPTION
        The script searches application DisplayNames when the -type 'app' argument is used, and searches for files/folders when the -type 'path' argument is used.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER SearchType
        The type of search to perform. 
        This can be either 'app' or 'path'. 
        If 'app' is specified, the script will search for the specified application in the registry. 
        If 'path' is specified, the script will search for the specified file/folder path on the target's filesystem.

    .PARAMETER Item
        The item to search for. 
        If the -SearchType 'app' argument is used, this should be the application's DisplayName. 
        If the -SearchType 'path' argument is used, this should be the path to search for, Ex: C:\users\public\test.txt.

    .PARAMETER OutputFile
        Used to create the output filename/path if supplied.

    .EXAMPLE
        Scan-ForAppOrFilePath -ComputerList 't-client-01' -SearchType 'app' -Item 'Microsoft Teams' -outputfile 'teams'

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Path', 'App', 'File', 'Folder')]
        [String]$SearchType,
        [Parameter(Mandatory = $true)]
        [String]$Item,
        [String]$Outputfile
    )
    ## 1. Set date
    ## 2. Handle targetcomputer if not submitted through pipeline
    ## 3. Create output filepath, clean any input file search paths that are local,  
    ## and handle TargetComputer input / filter offline hosts.
    BEGIN {
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
        
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        ## 3. Outputfile handling - either create default, create filenames using input - report files are mandatory 
        ##    in this function.
        $str_title_var = "$SearchType-scan"
        if ((Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) -and ($null -ne $env:PSMENU_DIR)) {
            if ($Outputfile.toLower() -eq '') {
                $REPORT_DIRECTORY = "$str_title_var"
            }
            else {
                $REPORT_DIRECTORY = $outputfile            
            }
            $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
            if ($outputfile.tolower() -eq '') {

                $iterator_var = 0
                while ($true) {
                    $outputfile = "reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$thedate"
                    if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                        $iterator_var++
                        $outputfile = "reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$([string]$iterator_var)"
                    }
                    else {
                        break
                    }
                }
            }
            try {
                $outputdir = $outputfile | split-path -parent
                if (-not (Test-Path $outputdir -ErrorAction SilentlyContinue)) {
                    New-Item -ItemType Directory -Path $($outputfile | split-path -parent) | Out-Null
                }
            }
            catch {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $Outputfile has no parent directory." -Foregroundcolor Yellow
            }
        }
        
        ## Collecting the results
        $results = [System.Collections.ArrayList]::new()
    }
    ## 1/2. Check Targetcomputer for null/empty values and test ping.
    ## 3. If machine was responsive, check for file/folder or application, add to $results.
    ##    --> If searching for filepaths - creates object with some details / file attributes
    ##    --> If searching for apps - creates object with some details / app attributes
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            ## 1.
            if ($single_computer) {

                ## 2. Test with ping first:
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {
                    ## File/Folder search
                    if (@('path', 'file', 'folder') -contains $SearchType.ToLower()) {

                        $search_result = Invoke-Command -ComputerName $single_computer -ScriptBlock {
                            $obj = [PSCustomObject]@{
                                Name           = $env:COMPUTERNAME
                                Path           = $using:item
                                PathPresent    = $false
                                PathType       = $null
                                LastWriteTime  = $null
                                CreationTime   = $null
                                LastAccessTime = $null
                                Attributes     = $null
                            }
                            $GetSpecifiedItem = Get-Item -Path "$using:item" -ErrorAction SilentlyContinue
                            if ($GetSpecifiedItem.Exists) {
                                $details = $GetSpecifiedItem | Select FullName, *Time, Attributes, Length
                                $obj.PathPresent = $true
                                if ($GetSpecifiedItem.PSIsContainer) {
                                    $obj.PathType = 'Folder'
                                }
                                else {
                                    $obj.PathType = 'File'
                                }
                                $obj.LastWriteTime = $details.LastWriteTime
                                $obj.CreationTime = $details.CreationTime
                                $obj.LastAccessTime = $details.LastAccessTime
                                $obj.Attributes = $details.Attributes
                            }
                            else {
                                $obj.PathPresent = "Filepath not found"
                            }
                            $obj
                        }  | Select PSComputerName, * -ExcludeProperty RunspaceId, PSshowcomputername -ErrorAction SilentlyContinue
                    }
                    ## Application search
                    elseif ($SearchType -eq 'App') {

                        $search_result = Invoke-Command -ComputerName $single_computer -Scriptblock {
                            # $app_matches = [System.Collections.ArrayList]::new()
                            # Define the registry paths for uninstall information
                            $registryPaths = @(
                                "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
                                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
                                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
                            )
                            $obj = $null
                            # Loop through each registry path and retrieve the list of subkeys
                            foreach ($path in $registryPaths) {
                                $uninstallKeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
                                # Skip if the registry path doesn't exist
                                if (-not $uninstallKeys) {
                                    continue
                                }
                                # Loop through each uninstall key and display the properties
                                foreach ($key in $uninstallKeys) {
                                    $keyPath = Join-Path -Path $path -ChildPath $key.PSChildName
                                    $displayName = (Get-ItemProperty -Path $keyPath -Name "DisplayName" -ErrorAction SilentlyContinue).DisplayName
                                    if ($displayName -like "*$using:Item*") {
                                        $uninstallString = (Get-ItemProperty -Path $keyPath -Name "UninstallString" -ErrorAction SilentlyContinue).UninstallString
                                        $version = (Get-ItemProperty -Path $keyPath -Name "DisplayVersion" -ErrorAction SilentlyContinue).DisplayVersion
                                        $publisher = (Get-ItemProperty -Path $keyPath -Name "Publisher" -ErrorAction SilentlyContinue).Publisher
                                        $installLocation = (Get-ItemProperty -Path $keyPath -Name "InstallLocation" -ErrorAction SilentlyContinue).InstallLocation
                                        # $productcode = (Get-ItemProperty -Path $keyPath -Name "productcode" -ErrorAction SilentlyContinue).productcode
                                        $installdate = (Get-ItemProperty -Path $keyPath -Name "installdate" -ErrorAction SilentlyContinue).installdate

                                        $obj = [PSCustomObject]@{
                                            ComputerName    = $env:COMPUTERNAME
                                            AppName         = $displayName
                                            AppVersion      = $version
                                            InstallDate     = $installdate
                                            InstallLocation = $installLocation
                                            Publisher       = $publisher
                                            UninstallString = $uninstallString
                                        }
                                        $obj
                                    }
                                }
                            }
                            if ($null -eq $obj) {
                                $obj = [PSCustomObject]@{
                                    ComputerName    = $single_computer
                                    AppName         = "No matching apps found for $using:Item"
                                    AppVersion      = $null
                                    InstallDate     = $null
                                    InstallLocation = $null
                                    Publisher       = $null
                                    UninstallString = "No matching apps found"
                                }
                                $obj
                            }
                        } | Select PSComputerName, * -ExcludeProperty RunspaceId, PSShowComputerName -ErrorAction SilentlyContinue

                        # $search_result
                        # read-host "enter"
                    }
                    ForEach ($single_result_obj in $Search_result) {
                        $results.add($single_result_obj) | out-null
                    }
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is offline, skipping." -ForegroundColor Yellow
                }
            }
        }
    }
    ## 1. Output findings (if any) to report files or terminal
    END {
        if ($results) {
            $results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation
            ## Try ImportExcel
            try {
                ## xlsx attempt:
                $params = @{
                    AutoSize             = $true
                    TitleBackgroundColor = 'Blue'
                    TableName            = "$REPORT_DIRECTORY"
                    TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                    BoldTopRow           = $true
                    WorksheetName        = "$SearchType-Search"
                    PassThru             = $true
                    Path                 = "$Outputfile.xlsx" # => Define where to save it here!
                }
                $Content = Import-Csv "$Outputfile.csv"
                $xlsx = $Content | Export-Excel @params
                $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
                $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
                Close-ExcelPackage $xlsx
            }
            catch {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: ImportExcel module not found, skipping xlsx creation." -Foregroundcolor Yellow
            }
            ## Try opening directory (that might contain xlsx and csv reports), default to opening csv which should always exist
            try {
                Invoke-item "$($outputfile | split-path -Parent)"
            }
            catch {
                # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Could not open output folder." -Foregroundcolor Yellow
                Invoke-item "$outputfile.csv"
            }
            
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        Read-Host "`nPress [ENTER] to return results."
        return $results
    }
}

Export-ModuleMember -Function Scan-ForAppOrFilePath

function Scan-SoftwareInventory {
    <#
    .SYNOPSIS
        Scans a group of computers for installed applications and exports results to .csv/.xlsx - one per computer.

    .DESCRIPTION
        Scan-SoftwareInventory can handle a single string hostname as a target, a single string filepath to hostname list, or an array/arraylist of hostnames.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: g-labpc- will create a list of all hostnames that start with 
        g-labpc- (g-labpc-01. g-labpc-02, g-labpc-03..).

    .PARAMETER Outputfile
        A string used to create the output .csv and .xlsx files. If not specified, a default filename is created.

    .EXAMPLE
        Scan-SoftwareInventory -TargetComputer "t-client-28" -Title "tclient-28-details"

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [Parameter(
            Mandatory = $true)]
        [string]$OutputFile
    )
    ## 1. Define title, date variables
    ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
    ## 3. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
    ## 4. Create empty results container
    BEGIN {
        ## 1. Define title, date variables
        $REPORT_TITLE = 'SoftwareScan'
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
        
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        ## 3. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        $str_title_var = $REPORT_TITLE

        if ((Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) -and ($null -ne $env:PSMENU_DIR)) {
            if ($Outputfile.toLower() -eq '') {
                $REPORT_DIRECTORY = "$str_title_var"
            }
            else {
                $REPORT_DIRECTORY = $outputfile            
            }
            $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
            if ($outputfile.tolower() -eq '') {
                $iterator_var = 0
                while ($true) {
                    $outputfile = "$str_title_var-$thedate"
                    if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                        $iterator_var++
                        $outputfile += "-$([string]$iterator_var)"
                    }
                    else {
                        break
                    }
                }
            }
            ## Try to get output directory path and make sure it exists.
            try {
                $outputdir = $outputfile | split-path -parent
                if (-not (Test-Path $outputdir -ErrorAction SilentlyContinue)) {
                    New-Item -ItemType Directory -Path $($outputfile | split-path -parent) | Out-Null
                }
            }
            catch {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $Outputfile has no parent directory." -Foregroundcolor Yellow
            }
        }
        
        ## 4. Create empty results container
        $results = [system.collections.arraylist]::new()
    }
    ## Scan the applications listed in three registry locations:
    ## 1. HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall
    ## 2. HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall
    ## 3. HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            if ($single_computer) {
                ## test with ping:
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {
                    $target_software_inventory = invoke-command -computername $single_computer -scriptblock {
                        $registryPaths = @(
                            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
                            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
                            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
                        )
                        foreach ($path in $registryPaths) {
                            $uninstallKeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
                            # Skip if the registry path doesn't exist
                            if (-not $uninstallKeys) {
                                continue
                            }
                            # Loop through each uninstall key and display the properties
                            foreach ($key in $uninstallKeys) {
                                $keyPath = Join-Path -Path $path -ChildPath $key.PSChildName
                                $displayName = (Get-ItemProperty -Path $keyPath -Name "DisplayName" -ErrorAction SilentlyContinue).DisplayName
                                $uninstallString = (Get-ItemProperty -Path $keyPath -Name "UninstallString" -ErrorAction SilentlyContinue).UninstallString
                                $version = (Get-ItemProperty -Path $keyPath -Name "DisplayVersion" -ErrorAction SilentlyContinue).DisplayVersion
                                $publisher = (Get-ItemProperty -Path $keyPath -Name "Publisher" -ErrorAction SilentlyContinue).Publisher
                                $installLocation = (Get-ItemProperty -Path $keyPath -Name "InstallLocation" -ErrorAction SilentlyContinue).InstallLocation
                                $productcode = (Get-ItemProperty -Path $keyPath -Name "productcode" -ErrorAction SilentlyContinue).productcode
                                $installdate = (Get-ItemProperty -Path $keyPath -Name "installdate" -ErrorAction SilentlyContinue).installdate
            
                                if (($displayname -ne '') -and ($null -ne $displayname)) {

                                    $obj = [pscustomobject]@{
                                        DisplayName     = $displayName
                                        UninstallString = $uninstallString
                                        Version         = $version
                                        Publisher       = $publisher
                                        InstallLocation = $installLocation
                                        ProductCode     = $productcode
                                        InstallDate     = $installdate
                                    }
                                    $obj    
                                }        
                            }
                        } 
                    } | Select PSComputerName, * -ExcludeProperty RunspaceId, PSshowcomputername -ErrorAction SilentlyContinue
                    $results.add($target_software_inventory) | out-null
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is not responding to ping." -Foregroundcolor Red
                }
            }
        }
    }

    ## 1. Get list of unique computer names from results - use it to sort through all results to create a list of apps for 
    ##    a specific computer, output apps to report, then move on to next iteration of loop.
    END {
        if ($results) {
            ## 1. get list of UNIQUE pscomputername s from the results - a file needs to be created for EACH computer.
            $unique_hostnames = $($results.pscomputername) | select -Unique

            ForEach ($single_computer_name in $unique_hostnames) {
                # get that computers apps
                $apps = $results | where-object { $_.pscomputername -eq $single_computer_name }
                # create the full filepaths
                $output_filepath = "$outputfile-$single_computer_name"
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Exporting files for $single_computername to $output_filepath."

                $apps | Export-Csv -Path "$outputfile-$single_computer_name.csv" -NoTypeInformation
                ## Try ImportExcel
                try {
                    ## xlsx attempt:
                    $params = @{
                        AutoSize             = $true
                        TitleBackgroundColor = 'Blue'
                        TableName            = "$REPORT_DIRECTORY"
                        TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                        BoldTopRow           = $true
                        WorksheetName        = "$single_computer_name Apps"
                        PassThru             = $true
                        Path                 = "$Outputfile.xlsx" # => Define where to save it here!
                    }
                    $Content = Import-Csv "$outputfile-$single_computer_name.csv"
                    $xlsx = $Content | Export-Excel @params
                    $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
                    $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
                    Close-ExcelPackage $xlsx
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: ImportExcel module not found, skipping xlsx creation." -Foregroundcolor Yellow
                }
                
            }
            ## Try opening directory (that might contain xlsx and csv reports), default to opening csv which should always exist
            try {
                Invoke-item "$($outputfile | split-path -Parent)"
            }
            catch {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Could not open output folder, attempting to open first .csv in list." -Foregroundcolor Yellow
                Invoke-item "$outputfile-$($unique_hostnames | select -first 1).csv"
            }
        }
        Read-Host "`nPress [ENTER] to return results."
        return $results
    }
}

Export-ModuleMember -Function Scan-SoftwareInventory

function Send-Files {
    <#
    .SYNOPSIS
        Sends a target file/folder from local computer to target path on remote computers.

    .DESCRIPTION
        You can enter both paths as if they're on local filesystem, the script should cut out any drive letters and insert the \\hostname\c$ for UNC path. The script only works for C drive on target computers right now.

    .PARAMETER SourcePath
        The path of the file/folder you want to send to target computers. 
        ex: C:\users\public\desktop\test.txt, 
        ex: \\networkshare\folder\test.txt

    .PARAMETER DestinationPath
        The path on the target computer where you want to send the file/folder. 
        The script will cut off any preceding drive letters and insert \\hostname\c$ - so destination paths should be on C drive of target computers.
        ex: C:\users\public\desktop\test.txt

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: g-labpc- will create a list of all hostnames that start with 
        g-labpc- (g-labpc-01. g-labpc-02, g-labpc-03..).

    .EXAMPLE
        copy the test.txt file to all computers in stanton open lab
        Send-Files -sourcepath "C:\Users\Public\Desktop\test.txt" -destinationpath "Users\Public\Desktop" -targetcomputer "t-client-"

    .EXAMPLE
        Get-User -ComputerName "t-client-28"

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param(        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [ValidateScript({
                Test-Path $_ -ErrorAction SilentlyContinue
            })]
        [string]$sourcepath,
        [string]$destinationpath
    )
    ## 1. Handle Targetcomputer input if it's not supplied through pipeline.
    BEGIN {
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
        
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }
    }
    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. Use session to copy file from local computer.
    ##    Report on success/fail
    ## 4. Remove the pssession.
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            ## 1. no empty Targetcomputer values past this point
            if ($single_computer) {
                ## 2. Ping target machine one time
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {
                    $target_session = New-PSSession $single_computer
                    try {
                        Copy-Item -Path "$sourcepath" -Destination "$destinationpath" -ToSession $target_session -Recurse
                        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Transfer of $sourcepath to $destinationpath ($single_computer) complete." -foregroundcolor green
                    }
                    catch {
                        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Failed to copy $sourcepath to $destinationpath on $single_computer." -foregroundcolor red
                    }
                    ## 4. Bye pssession
                    Remove-PSSession $target_session
                }
            }
        }
    }
    ## 1. Write an ending message to terminal.
    END {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: File transfer(s) complete." -foregroundcolor green  
        Write-Host "If you'd like to check for file/folder's existence on computers, use: " -NoNewline
        Write-Host "Filesystem operations -> Scan-ForApporFilepath" -Foregroundcolor Yellow

        Read-Host "`nPress [ENTER] to continue."
    }
}

Export-ModuleMember -Function Send-Files

function Copy-RemoteFiles {
    <#
    .SYNOPSIS
        Recursively grabs target files or folders from remote computer(s) and copies them to specified directory on local computer.

    .DESCRIPTION
        TargetPath specifies the target file(s) or folder(s) to target on remote machines.
        TargetPath can be supplied as a single absolute path, comma-separated list, or array.
        OutputPath specifies the directory to store the retrieved files.
        Creates a subfolder for each target computer to store it's retrieved files.

    .PARAMETER TargetPath
        Path to file(s)/folder(s) to be grabbed from remote machines. Ex: 'C:\users\abuddenb\Desktop\test.txt'

    .PARAMETER OutputPath
        Path to folder to store retrieved files. Ex: 'C:\users\abuddenb\Desktop\grabbed-files'

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .EXAMPLE
        Copy-RemoteFiles -TargetPath "Users\Public\Desktop" -OutputPath "C:\Users\Public\Desktop" -TargetComputer "t-client-"

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    param(        
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [string]$TargetPath,
        [string]$OutputPath
    )

    ## 1. Handle Targetcomputer input if it's not supplied through pipeline.
    ## 2. Make sure output folder path exists for remote files to be copied to.
    BEGIN {
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
        
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        ## 2. Make sure the outputpath folder exists (remote files are copied here):
        if (-not(Test-Path "$Outputpath" -erroraction SilentlyContinue)) {
            New-Item -ItemType Directory -Path "$Outputpath" -ErrorAction SilentlyContinue | out-null
        }

    }

    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. Copy file from pssession on target machine, to local computer.
    ##    Report on success/fail
    ## 4. Remove the pssession.
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {
            ## 1. no empty Targetcomputer values past this point
            if ($single_computer) {
                ## 2. Ping target machine one time
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {
                    $target_session = New-PSSession $single_computer
                    try {
                        Copy-Item -Path "$targetpath" -Destination "$outputpath\" -FromSession $target_session -Recurse
                        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Transfer of $targetpath ($single_computer) to $outputpath  complete." -foregroundcolor green
                    }
                    catch {
                        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Failed to copy $targetpath on $single_computer to $outputpath on local computer." -foregroundcolor red
                    }
                    ## 4. Bye pssession
                    Remove-PSSession $target_session
                }
            }
        }
    }
    ## Open output folder, pause.
    END {
        if (Test-Path "$Outputpath" -erroraction SilentlyContinue) {
            Invoke-item "$Outputpath"
        }
        Read-Host "Press enter to continue."
    }
}

Export-ModuleMember -Function Copy-RemoteFiles

function Send-Reboots {
    <#
    .SYNOPSIS
        Reboots the target computer(s) either with/without a message displayed to logged in users.

    .DESCRIPTION
        If a reboot msg isn't provided, no reboot msg/warning will be shown to logged in users.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .EXAMPLE
        Send-Reboot -TargetComputer "t-client-" -RebootMessage "This computer will reboot in 5 minutes." -RebootTimeInSeconds 300

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [Parameter(Mandatory = $false)]
        [string]$RebootMessage,
        # the time before reboot in seconds, 3600 = 1hr, 300 = 5min
        [Parameter(Mandatory = $false)]
        [string]$RebootTimeInSeconds = 300
    )
    ## 1. Confirm time before reboot w/user
    ## 2. Handling of TargetComputer input
    ## 3. typecast reboot time to double to be sure
    ## 4. container for offline computers
    BEGIN {
        ## 1. Confirmation
        $reply = Read-Host "Sending reboot in $RebootTimeInSeconds seconds, or $([double]$RebootTimeInSeconds / 60) minutes, OK? (y/n)"
        if ($reply.ToLower() -eq 'y') {
    
            ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
            if ($null -eq $TargetComputer) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
            }
            else {
                ## Assigns localhost value
                if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                    $TargetComputer = @('127.0.0.1')
                }
                ## If input is a file, gets content
                elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                    $TargetComputer = Get-Content $TargetComputer
                }
                ## A. Separates any comma-separated strings into an array, otherwise just creates array
                ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
                else {
                    ## A.
                    if ($Targetcomputer -like "*,*") {
                        $TargetComputer = $TargetComputer -split ','
                    }
                    else {
                        $Targetcomputer = @($Targetcomputer)
                    }
        
                    ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                    $NewTargetComputer = [System.Collections.Arraylist]::new()
                    foreach ($computer in $TargetComputer) {
                        ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                        if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                            Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                            Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                        }
                        else {
        
                            # if no domain specified fallback to PowerShell environment variable
                            if ([string]::IsNullOrEmpty($searchRoot)) {
                                $searchRoot = $env:USERDNSDOMAIN
                            }
                            $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                            $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                            $searcher.SearchRoot = "LDAP://$searchRoot"
                            [void]$searcher.PropertiesToLoad.Add("name")
                            $list = [System.Collections.Generic.List[String]]@()
                            $results = $searcher.FindAll()
                            foreach ($result in $results) {
                                $resultItem = $result.Properties
                                [void]$List.add($resultItem.name)
                            }
                            $NewTargetComputer += $list
                        }
                    }
                    $TargetComputer = $NewTargetComputer
                }
                $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
                # Safety catch
                if ($null -eq $TargetComputer) {
                    return
                }
            }
        }
        ## 3. typecast to double
        $RebootTimeInSeconds = [double]$RebootTimeInSeconds

        ## 4. container for offline computers
        $offline_computers = [system.collections.arraylist]::new()

    }
    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session and/or reboot.
    ## 3. Send reboot either with or without message
    ## 4. If machine was offline - add it to list to output at end.
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            ## 1. empty Targetcomputer values will cause errors to display during test-connection / rest of code
            if ($single_computer) {
                ## 2. Ping test
                $ping_result = Test-Connection $single_computer -count 1 -Quiet
                if ($ping_result) {
                    if ($RebootMessage) {
                        Invoke-Command -ComputerName $single_computer -ScriptBlock {
                            shutdown  /r /t $using:reboottime /c "$using:RebootMessage"
                        }
                        $reboot_method = "Reboot w/popup msg"
                    }
                    else {
                        Restart-Computer $single_computer
                        $reboot_method = "Reboot using Restart-Computer (no Force)" # 2-28-2024
                    }
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Reboot sent to $single_computer using $reboot_method." -ForegroundColor Green
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is offline." -Foregroundcolor Yellow
                    $offline_computers.add($single_computer) | Out-Null
                }
            }
        }
    }
    ## Output offline computers to terminal, and to file if requested
    END {
        if ($offline_computers) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Offline computers include:"
            Write-Host ""
            $offline_computers
            Write-Host ""
            $output_file = Read-Host "Output offline computers to txt file in ./output? [y/n]"
            if ($output_file.tolower() -eq 'y') {
                $offline_computers | Out-File -FilePath "./output/$thedate/Offline-NoReboot-$thedate.txt" -Force
            }
        }
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Reboot(s) sent."
        Read-Host "`nPress [ENTER] to continue."
    }
}

Export-ModuleMember -Function Send-Reboots

Function Set-ChromeClearDataOnExit {
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer
    )
    ## 1. Handling TargetComputer input if not supplied through pipeline.
    ## 2. Define scriptblock that sets Chrome data deletion registry settings.
    BEGIN {
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
        
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }
        ## 2. Scriptblock that runs on each target computer, setting registry values to cause Chrome to auto-delete
        ##    specified categories of browsing data on exit of the application.
        ##    This is useful for 'guest accounts' or 'testing center' computers, that are not likely to have to be 
        ##    reused by the same person.
        $chrome_setting_scriptblock = {
            $testforchromekey = Test-Path -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ClearBrowsingDataOnExitList" -erroraction silentlycontinue
            if (-not $testforchromekey) {
                New-Item -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "ClearBrowsingDataOnExitList" -Force
            }
    
            New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "SyncDisabled" -Value 1 -PropertyType DWord -Force
    
            $chromehash = @{
                "1" = "browsing_history"
                "2" = "download_history"
                "3" = "cookies_and_other_site_data"
                "4" = "cached_images_and_files"
                "5" = "password_signin"
                "6" = "autofill"
                "7" = "site_settings"
                "8" = "hosted_app_data"
            }
            ForEach ($key in $chromehash.keys) {
                New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ClearBrowsingDataOnExitList" -Name $key -Value $chromehash[$key] -PropertyType String -Force
            }
            New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "BackgroundModeEnabled" -Value 0 -PropertyType DWORD -Force
            
            New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "ClearBrowsingDataOnExit" -Value 1 -PropertyType DWORD -Force
        }
    }
    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. If machine was responsive, Collect local asset information from computer
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            if ($single_computer) {

                ## test with ping first:
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {
                    Invoke-Command -ComputerName $single_computer -ScriptBlock $chrome_setting_scriptblock
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer didn't respond to one ping, skipping." -ForegroundColor Yellow
                }
            }
        }
    }

    END {
        Read-Host "Press enter to continue."
    }
}

Export-ModuleMember -Function Set-ChromeClearDataOnExit

function Stop-WifiAdapters {
    <#
    .SYNOPSIS
        Attempts to turn off (and disable if 'y' entered for 'DisableWifiAdapter') Wi-Fi adapter of target device(s).
        Having an active Wi-Fi adapter/connection when the Ethernet adapter is also active can cause issues.

    .DESCRIPTION
        Function needs work - 1/13/2024.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER DisableWifiAdapter
        Optional parameter to disable the Wi-Fi adapter. If not specified, the function will only turn off wifi adapter.
        'y' or 'Y' will disable target Wi-Fi adapters.

    .EXAMPLE
        Stop-WifiAdapters -TargetComputer s-tc136-02 -DisableWifiAdapter y
        Turns off and disables Wi-Fi adapter on single computer/hostname s-tc136-02.

    .EXAMPLE
        Stop-WifiAdapters -TargetComputer t-client- -DisableWifiAdapter n
        Turns off Wi-Fi adapters on computers w/hostnames starting with t-client-, without disabling them.

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [string]$DisableWifiAdapter = 'n'
    )
    ## 1. Handling of TargetComputer input
    ## 2. Define Turn off / disable wifi adapter scriptblock that gets run on each target computer
    BEGIN {
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
        
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        $DisableWifiAdapter = $DisableWifiAdapter.ToLower()
        ## 2. Turn off / disable wifi adapter scriptblock
        $turnoff_wifi_adapter_scriptblock = {
            param(
                $DisableWifi
            )
            $EthStatus = (Get-Netadapter | where-object { $_.Name -eq 'Ethernet' }).status
            if ($ethstatus -eq 'Up') {
                Write-Host "[$env:COMPUTERNAME] :: Eth is up, turning off Wi-Fi..." -foregroundcolor green
                Set-NetAdapterAdvancedProperty -Name "Wi-Fi" -AllProperties -RegistryKeyword "SoftwareRadioOff" -RegistryValue "1"
                # should these be uncommented?
                if ($DisableWifi -eq 'y') {
                    Disable-NetAdapterPowerManagement -Name "Wi-Fi"
                    Disable-NetAdapter -Name "Wi-Fi" -Force
                }            
            }
            else {
                Write-Host "[$env:COMPUTERNAME] :: Eth is down, leaving Wi-Fi alone..." -foregroundcolor red
            }
        }
    } 
    
    ## Test connection to target machine(s) and then run scriptblock to disable wifi adapter if ethernet adapter is active
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            ## empty Targetcomputer values will cause errors to display during test-connection / rest of code
            if ($single_computer) {
                ## Ping test
                $ping_result = Test-Connection $single_computer -count 1 -Quiet
                if ($ping_result) {
                    if ($single_computer -eq '127.0.0.1') {
                        $single_computer = $env:COMPUTERNAME
                    }
        
                    Invoke-Command -ComputerName $single_computer -Scriptblock $turnoff_wifi_adapter_scriptblock -ArgumentList $DisableWifiAdapter
                }
                else {
                    Write-Host "[$env:COMPUTERNAME] :: $single_computer is offline, skipping." -Foregroundcolor Yellow
                }
            }
        }
    }

    ## Pause before continuing back to terminal menu
    END {
        Read-Host "`nPress [ENTER] to continue."
    }
}

Export-ModuleMember -Function Stop-WifiAdapters

function Test-ConnectivityQuick {
    <#
    .SYNOPSIS
        Tests connectivity to a single computer or list of computers by using Test-Connection -Quiet.

    .DESCRIPTION
        Works fairly quickly, but doesn't give you any information about the computer's name, IP, or latency - judges online/offline by the 1 ping.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .EXAMPLE
        Check all hostnames starting with t-client- for online/offline status.
        Test-ConnectivityQuick -TargetComputer "t-client-"

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer
    )
    ## 1. Set PingCount - # of pings sent to each target machine.
    ## 2. Handle Targetcomputer if not supplied through the pipeline.
    BEGIN {
        ## 1. Set PingCount - # of pings sent to each target machine.
        $PING_COUNT = 1
        ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
        
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        ## COLLECTIONS LISTS - successful/failed pings.
        $results = [system.collections.arraylist]::new()
        # $list_of_online_computers = [system.collections.arraylist]::new()
        # $list_of_offline_computers = [system.collections.arraylist]::new()
    }

    ## Ping target machines $PingCount times and log result to terminal.
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            if ($single_computer) {
                $connection_result = Test-Connection $single_computer -count $PING_COUNT
                $ping_responses = $([string[]]($connection_result | where-object { $_.statuscode -eq 0 })).count

                ## Create object
                $ping_response_obj = [pscustomobject]@{
                    ComputerName  = $single_computer
                    Status        = ""
                    PingResponses = $ping_responses
                    NumberPings   = $PING_COUNT
                }

                if ($connection_result) {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is online [$ping_responses responses]" -foregroundcolor green
                    # $list_of_online_computers.add($single_computer) | Out-Null
                    $ping_response_obj.Status = 'online'
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
                    Write-Host "$single_computer is not online." -foregroundcolor red
                    # $list_of_offline_computers.add($single_computer) | Out-Null
                    $ping_response_obj.Status = 'offline'
                }

                $results.add($ping_response_obj) | Out-Null
            }
        }
    }
    ## Open results in gridview since this is just supposed to be quick test for connectivity
    END {
        $results | out-gridview -Title "Results: $PING_COUNT Pings"
        Read-Host "`nPress [ENTER] to continue."
    }

}

Export-ModuleMember -Function Test-ConnectivityQuick

function Convert-PNGtoICO {
    <#
    .SYNOPSIS
        Converts image to icons, verified with .png files.

    .DESCRIPTION
        Easier than trying to find/navigate reputable online/executable converters.

    .Example
        Convert-PNGtoICO -File .\Logo.png -OutputFile .\Favicon.ico

    .NOTES
        SOURCE: https://www.powershellgallery.com/packages/RoughDraft/0.1/Content/ConvertTo-Icon.ps1
        # wrapped for Terminal menu: Alex B. (albddnbn)
    #>
    [CmdletBinding()]
    param(
        [string]$File,
        # If set, will output bytes instead of creating a file
        # [switch]$InMemory,
        # If provided, will output the icon to a location
        # [Parameter(Position = 1, ValueFromPipelineByPropertyName = $true)]
        [string]$OutputFile
    )
    
    begin {
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing
        
    }
    
    process {
        #region Load Icon
        $resolvedFile = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($file)
        if (-not $resolvedFile) { return }
        $loadedImage = [Drawing.Image]::FromFile($resolvedFile)
        $intPtr = New-Object IntPtr
        $thumbnail = $loadedImage.GetThumbnailImage(72, 72, $null, $intPtr)
        $bitmap = New-Object Drawing.Bitmap $thumbnail 
        $bitmap.SetResolution(72, 72); 
        $icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon());         
        #endregion Load Icon

        #region Save Icon
        if ($InMemory) {                        
            $memStream = New-Object IO.MemoryStream
            $icon.Save($memStream) 
            $memStream.Seek(0, 0)
            $bytes = New-Object Byte[] $memStream.Length
            $memStream.Read($bytes, 0, $memStream.Length)                        
            $bytes
        }
        elseif ($OutputFile) {
            $resolvedOutputFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputFile)
            $fileStream = [IO.File]::Create("$resolvedOutputFile")                               
            $icon.Save($fileStream) 
            $fileStream.Close()               
        }
        #endregion Save Icon

        #region Cleanup
        $icon.Dispose()
        $bitmap.Dispose()
        #endregion Cleanup

    }
}

Export-ModuleMember -Function Convert-PNGtoICO

function Clear-CorruptProfiles {
    <#
    .SYNOPSIS
        Attempts to clean any temp user folders found on target machines, and reports on results.
        Clear-CorruptProfiles uses the Perform_deletions parameter to determine if it should actually perform deletions, or just generate a report on what it WOULD do..

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER Perform_deletions
        'enable'      - script will delete user folders and files on target computers.
        Anything else - script will not delete user folders and files on target computers.

    .PARAMETER SkipOccupiedComputers
        'y' is default - script will skip computers with users logged in.
        Anything else - script will run on computers with users logged in.

    .EXAMPLE
        Run without making changes to filesystems / deleting profiles or folders
        Clear-CorruptProfiles.ps1 -TargetComputer "t-client-" -Perform_deletions "n"
        Clear-CorruptProfiles.ps1 -TargetComputer "t-client-"

    .EXAMPLE
        Run and make changes to filesystems / delete profiles or folders
        Clear-CorruptProfiles.ps1 -TargetComputer "t-client-" -Perform_deletions "enable"

    .NOTES
        This script is a wrapper for the ./localscripts/Clear-CorruptProfiles.ps1 script.
        Clear-CorruptProfiles can be run locally on a single computer to clear out temporary folders.        
        02-18-2024 - Wrapper will not work outside of Terminal menu without edits, script in localscripts will work.
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [string]$Perform_deletions,
        [string]$SkipOccupiedComputers = 'y'
    )

    ## 1. Set date and report title variables to be used in output filename creation
    ## 2. Check for clear-corruptprofiles.ps1 script in ./localscripts
    ## 3. Assign 'perform_deletions' a boolean value
    ## 4. Handle Targetcomputer if not supplied through pipeline
    ## 5. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
    ## 6. Create empty results container
    BEGIN {
        if ($SkipOCcupiedComputers -eq '') {
            $SkipOccupiedComputers = 'y'
        }
        ## 1. Set date and report title variables to be used in output filename creation
        $REPORT_TITLE = 'TempProfiles' # used to create the output filename, .xlsx worksheet title, and folder name inside the report\yyyy-MM-dd folder for today
        $thedate = Get-Date -Format 'yyyy-MM-dd'

        ## 2. Check for clear-corruptprofiles.ps1 script in ./localscripts
        $get_corrupt_profiles_ps1 = Get-ChildItem -Path "$env:LOCAL_SCRIPTS" -Filter "Clear-CorruptProfiles.ps1" -File -ErrorAction SilentlyContinue
        if (-not $get_corrupt_profiles_ps1) {
            Write-host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
            Write-Host "Clear-CorruptProfiles.ps1 script not found in $env:LOCAL_SCRIPTS." -Foregroundcolor Red
            return
        }

        ## 3. Perform_deletions and get use acknowledgement before proceeding
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
        if ($Perform_deletions.ToLower() -like "enable*") {
            $whatif_setting = $false
            Write-Host "Deletions ENABLED - script will delete files/folders on target computers." -Foregroundcolor Yellow
        }
        else {
            $whatif_setting = $true
            Write-Host "Deletions DISABLED - script won't delete files/folders on target computers." -Foregroundcolor Green
        }
        Read-Host "Press enter to acknowledge perform_deletions value."

        ## 4. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
        
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        ## 5. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        $str_title_var = "TempProfiles"

        if (Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) {
            $REPORT_DIRECTORY = "$str_title_var"
            $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
            $iterator_var = 0
            while ($true) {
                $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$thedate"
                if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                    $iterator_var++
                    $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$([string]$iterator_var)"
                }
                else {
                    break
                }
            }
                
        }
        

        ## 6. Create empty results container
        $results = [system.collections.arraylist]::new()
    }
    ## 1. Check Targetcomputer for null/empty values
    ## 2. Ping test
    ## 3. If responsive, run Clear-CorruptProfiles.ps1 script on target computer
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {
            ## 1.
            if ($single_computer) {

                ## 2. test with ping:
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {

                    if ($SkipOccupiedComputers.ToLower() -eq 'y') {
                        $check_for_user = Invoke-Command -Computername $single_computer -scriptblock {
                            (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username
                        }
                        if ($check_for_user) {
                            $check_for_user = $check_for_user -replace "$env:USERDOMAIN\\", ''
                            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -Nonewline
                            Write-Host "$check_for_user is logged in to $single_computer, skipping this computer." -Foregroundcolor Yellow
                            continue
                        }
                    }
                    ## 3. Run script
                    $temp_profile_results = Invoke-Command -ComputerName $single_computer -FilePath "$($get_corrupt_profiles_ps1.fullname)" -ArgumentList $whatif_setting
                    $results.add($temp_profile_results) | Out-Null
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
                    Write-Host "$single_computer is offline." -Foregroundcolor Red
                }
            }
        }
    }
    ## 1. If there are any results - output them to report .csv/.xlsx files
    END {
        if ($results) {
            $results = $results | sort -property pscomputername
            $results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation
            ## Try ImportExcel
            try {
                ## xlsx attempt:
                $params = @{
                    AutoSize             = $true
                    TitleBackgroundColor = 'Blue'
                    TableName            = "$REPORT_DIRECTORY"
                    TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                    BoldTopRow           = $true
                    WorksheetName        = "$REPORT_DIRECTORY"
                    PassThru             = $true
                    Path                 = "$Outputfile.xlsx" # => Define where to save it here!
                }
                $Content = Import-Csv "$Outputfile.csv"
                $xlsx = $Content | Export-Excel @params
                $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
                $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
                Close-ExcelPackage $xlsx
            }
            catch {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: ImportExcel module not found, skipping xlsx creation." -Foregroundcolor Yellow
            }
            ## Open the report folder
            Invoke-item "$($outputfile | split-path -Parent)"
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }

        ## This is included for menu purposes, so there's a pause before the function ends and terminal window reverts
        ## to opening menu options.
        Read-Host "Press enter to return results."
        return $results
    }
}

Export-ModuleMember -Function Clear-CorruptProfiles

function Clear-ChromeBrowsingData {
    <#
    .SYNOPSIS
        Deletes any 'Cache Data' folders found in the target user's Chrome profile(s) on target computer.
        Browsing data is not necessarily only in the .\Google\Chrome\User Data\Default\Cache directory, organization-managed profiles may be stored elsewhere.

    .DESCRIPTION
        Deletes all of target user's browsing data for all Chrome profiles stored on computer.
        Browsing data, cookies, history - everything in browser cache.

    .PARAMETER Username
        Target user. If username is not supplied, the script looks for currently logged in user on the TargetPC.

    .PARAMETER TargetPC
        Target computer, if not specified the script assigns localhost (127.0.0.1) target.

    .PARAMETER UseCaution
        'y' will display popup on target computer(s) asking for user consent to kill Chrome processes and delete browsing data.
        'n' will kill Chrome processes and delete browsing data without prompting the user.

    .PARAMETER TargetAllProfiles
        'y' targets ALL Chrome user profiles on target computer, for all users.
        'n' targets only the latest Chrome profile on target computer.

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    # deleting profiles.ini in roaming profile fixed issue
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [String]$Username,
        [Parameter(Mandatory = $true)]
        [String]$TargetPC,
        [string]$UseCaution,
        [string]$TargetAllProfiles
    )
    if (-not $Username) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No username specified, " -nonewline
        Write-Host "will target active user on $TargetPC." -ForegroundColor Yellow
    }

    # scriptblock that will clear chrome browsing data when run locally on computer
    $purge_chrome_browsing_data = {
        param(
            $targeted_user,
            $cautious, # will display popup to user - allow them to choose yes / no to kill chrome and delete their browsing data
            $allprofiles # will either delete browsing data for all user's chrome profiles, or go by latest folder (latest last modified timestamp on folder)
        )
        if (-not $targeted_User) {
            $targeted_user = (Get-Process -name 'explorer' -includeusername -ErrorAction SilentlyContinue).Username
            $targeted_user = $targeted_user.split('\')[1]
        }
        if ($allprofiles -eq 'n') {
            $allprofiles = $false
        }
        else {
            $allprofiles = $true
        }

        if ($cautious.ToLower() -eq 'y') {
            ## It should be possible to display a popup to user - asking if it's ok to close Chrome
            ## Similar to PSADT Interactive installation popups.
            if (Get-Process -name "*chrome*" -erroraction silentlycontinue) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Chrome is running, skipping since cautious was specified." -ForegroundColor Yellow
                continue
            } 

        }

        # kill any running chrome process
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] " -NoNewline
        Write-Host "[$env:COMPUTERNAME]" -nonewline -ForegroundColor Yellow
        Write-Host " :: Stopping any running chrome processes."
        Get-Process -name 'chrome' -erroraction SilentlyContinue | Stop-Process -force -ErrorAction SilentlyContinue

        $items_to_remove = @(
            'History',
            'Cookies',
            'Cache',
            'Web Data'
        )

        # get default folder and any profile* folders
        $default_chrome = Get-ChildItem -Path "C:\Users\$targeted_user\AppData\Local\Google\Chrome\User Data\Default\" -Directory -ErrorAction SilentlyContinue
        # any other folders in that start with 'profile'
        $chrome_profiles = Get-ChildItem -Path "C:\Users\$targeted_user\AppData\Local\Google\Chrome\User Data\"  -Filter "Profile*" -Directory -ErrorAction SilentlyContinue
        # get the one with the latest last modified timestamp
        if (-not $allprofiles) {
            $chrome_profiles = $chrome_profiles | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
        } 
    
        ForEach ($profile_folder in @($($default_chrome.fullname), $($chrome_profiles.fullname))) {
            ForEach ($single_item in $items_to_remove) {
                if (Test-Path "$profile_folder\$single_item" -ErrorAction SilentlyContinue) {
                    # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] " -NoNewline
                    # Write-Host "[$env:COMPUTERNAME]" -nonewline -ForegroundColor Yellow
                    # Write-Host " :: Removing $single_item from $env:COMPUTERNAME..."
                    Remove-Item -Path "$profile_folder\$single_item" -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }

        if ($cautious.ToLower() -eq 'y') {
            Add-Type -AssemblyName PresentationCore, PresentationFramework
            $ButtonType = [System.Windows.MessageBoxButton]::Ok
            $MessageIcon = [System.Windows.MessageBoxImage]::Information
            $MessageBody = "Finished deleting Chrome browsing data, you can return to using Chrome normally now. Have a great day!"
            $MessageTitle = "Complete"
            $Result = [System.Windows.MessageBox]::Show($MessageBody, $MessageTitle, $ButtonType, $MessageIcon)
        }

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] " -NoNewline
        Write-Host "[$env:COMPUTERNAME]" -nonewline -ForegroundColor Yellow
        Write-Host " :: Browsing data removed for $targeted_user."

    }

    if ($TargetPC -eq '') {
        Invoke-Command -Scriptblock $purge_chrome_browsing_data -ArgumentList $Username, $UseCaution, $TargetAllProfiles
    }
    else {
        Invoke-Command -ComputerName $TargetPC -Scriptblock $purge_chrome_browsing_data -ArgumentList $Username, $UseCaution, $TargetAllProfiles
    }

    Read-Host "Press enter to continue."
}

Export-ModuleMember -Function Clear-ChromeBrowsingData

function Add-PrinterLogicPrinter {
    <#
    .SYNOPSIS
        Connects local or remote computer to target printerlogic printer by executing C:\Program Files (x86)\Printer Properties Pro\Printer Installer Client\bin\PrinterInstallerConsole.exe.
        Connection fails if PrinterLogic Client software is not installed on target machine(s).
        The user does NOT have to be a PrinterLogic user to be able to access connected PrinterLogic printers.

    .DESCRIPTION
        PrinterLogic Client software has to be installed on target machine(s) and connecting to your organization's 'Printercloud' instance using the registration key.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER PrinterName
        Name of the printer in printerlogic. Ex: 't-prt-lib-01', you can use the name or the full 'path' to the printer, ex: 'STANTON\B WING..\s-prt-b220-01'
        Name must match the exact 'name' of the printer, as listed in PrinterLogic.

    .EXAMPLE
        Connect single remote target computer to t-prt-lib-01 printer:
        Add-PrinterLogicPrinter -TargetComputer "t-client-28" -PrinterName "t-prt-lib-01"
        
    .EXAMPLE
        Connect a group of computers using hostname txt filepath to t-prt-lib-02 printer:
        Add-PrinterLogicPrinter -TargetComputer "D:\computers.txt" -PrinterName "t-prt-lib-02"
        
    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [string]$PrinterName
    )
    ## 1. TargetComputer handling if not supplied through pipeline
    ## 2. Scriptblock to connect to printerlogic printer
    ## 3. Results containers for overall results and skipped computers.
    BEGIN {
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
        
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }
        
        ## 2. Define the scriptblock that connects machine to target printer in printerlogic cloud instance
        $connect_to_printer_block = {
            param(
                $printer_name
            )

            $obj = [pscustomobject]@{
                hostname       = $env:COMPUTERNAME
                printer        = $printer_name
                connectstatus  = 'NO'
                clientsoftware = 'NO'
            }
            # get installerconsole.exe
            $exepath = get-childitem -path "C:\Program Files (x86)\Printer Properties Pro\Printer Installer Client\bin" -Filter "PrinterInstallerConsole.exe" -File -Erroraction SilentlyContinue
            if (-not $exepath) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: PrinterLogic PrinterInstallerConsole.exe was not found in C:\Program Files (x86)\Printer Properties Pro\Printer Installer Client\bin." -Foregroundcolor Red
                return $obj
            }
        
            $obj.clientsoftware = 'YES'
        
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Found $($exepath.fullname), mapping $printer_name now..."
            $map_result = (Start-Process "$($exepath.fullname)" -Argumentlist "InstallPrinter=$printer_name" -Wait -Passthru).ExitCode
        
            # 0 = good, 1 = bad
            if ($map_result -eq 0) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Connected to $printer_name successfully." -Foregroundcolor Green
                # Write-Host "*Remember that this script does not set default printer, user has to do that themselves."
                $obj.connectstatus = 'YES'
                return $obj
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: failed to connect to $printer_name." -Foregroundcolor Red
                return $obj
            }
        }

        ## 4. Create empty results containers
        $results = [system.collections.arraylist]::new()
        $missed_computers = [system.collections.arraylist]::new()
    }
    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. If machine was responsive, run scriptblock to attempt connection to printerlogic printer, save results to object
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {
            ## 1.
            if ($single_computer) {
                ## 2. test with ping:
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {
                    ## 3.
                    $printer_connection_results = Invoke-Command -ComputerName $single_computer -scriptblock $connect_to_printer_block -ArgumentList $PrinterName
            
                    $results.add($printer_connection_results)
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is not responding to ping." -Foregroundcolor Red
                    $missed_computers.Add($single_computer)
                }
            }
        }
    }
    ## 1. If there are any results - output to file
    ## 2. Output missed computers to terminal.
    ## 3. Return results arraylist
    END {
        ## 1.
        if ($results) {

            $results | out-gridview -Title "PrinterLogic Connect Results"

        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        ## 2. Output unresponsive computers
        Write-Host "These computers did not respond to ping:"
        Write-Host ""
        $missed_computers
        Write-Host ""
        Read-Host "Press enter to return results."

        ## 3. return results arraylist
        return $results
    }
}

Export-ModuleMember -Function Add-PrinterLogicPrinter

function Build-PrinterConnectionExe {
    <#
    .SYNOPSIS
        Generates executable using the PS2exe powershell module that will map a printer.
        Either PrinterLogic or on print server, specified by $PrinterType parameter.

    .DESCRIPTION
        PrinterLogic  - Printer Installer Client software must be installed on machines where executable is being used.
        Print servers - Print server must be accessible over the network, on machines where executable will be used.

    .PARAMETER Printername
        Name of the printer to map. Ex: 'printer-c136-01'
        PrinterLogic - needs to match printer's name as listed in PrinterLogic Printercloud instance.
        Print server - needs to match printer's hostname as listed in print server and on DNS server.

    .PARAMETER PrinterType
        Set to 'printerlogic' or the name of a printer server, ex: 's-ps-02', 'org-printserv-001'

    .EXAMPLE
        Generate-PrinterLogicExe -PrinterName "printer-c136-01"

    .NOTES
        Executable will be created in the 'executables' directory.
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrinterName,
        # [ValidateSet('printerlogic', 'ps')]
        $PrinterType
    )
    $EXECUTABLES_DIRECTORY = 'PrinterMapping'
    $thedate = Get-Date -Format 'yyyy-MM-dd'

    ### Make sure the executables and output directories for today exist / create if not.
    foreach ($singledir in @("$env:PSMENU_DIR\executables\$thedate\$EXECUTABLES_DIRECTORY", "$env:PSMENU_DIR\output\$thedate")) {
        if (-not (Test-Path $singledir -ErrorAction SilentlyContinue)) {
            New-Item -Path $singledir -ItemType 'Directory' -Force | Out-Null
        }
    }

    ## creates $exe_script variable depending on what kind of printer needs to be mapped
    if ($PrinterType -like "*ps*") {
        $exe_script = @"
`$printername = '\\$PrinterType\$PrinterName'
try {
    (New-Object -comobject wscript.network).addwindowsprinterconnection(`$printername)
    (New-Object -comobject wscript.network).setdefaultprinter(`$printername)
    Write-Host "Mapped `$printername successfully." -Foregroundcolor Green
} catch {
    Write-Host "Failed to map printer: `$printername, please let Tech Support know." -Foregroundcolor Red
}
Start-Sleep -Seconds 5
"@

        # create output filename for print server mapping:
        $output_filename = "pserver-connect-$PrinterName"
    }
    elseif ($PrinterType -like "*logic*") {
        # generate text for .ps1 file
        $exe_script = @"
# 'get' the .exe
`$printerinstallerconsoleexe = Get-Childitem -Path "C:\Program Files (x86)\Printer Properties Pro\Printer Installer Client\bin\" -Filter "PrinterInstallerconsole.exe" -File -ErrorAction silentlycontinue
# run install command:
`$execution_result = Start-Process "`$(`$printerinstallerconsoleexe.FullName)" -ArgumentList "InstallPrinter=$printername"
# if (`$execution_result -eq 0) {
#     Write-Host "[`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Successfully installed printer: `$printername" -Foregroundcolor Green
# } else {
#     Write-Host "[`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Failed to install printer: `$printername, please let tech support know." -Foregroundcolor Red
# }
Start-Sleep -Seconds 5
"@

        $output_filename = "plogic-connect-$PrinterName"

    }

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Creating executable that will map $PrinterType printer: $printername when double-clicked by user..."

    $exe_script | Out-File -FilePath "$env:PSMENU_DIR\output\$thedate\$output_filename.ps1" -Force

    Invoke-PS2EXE -inputfile "$env:PSMENU_DIR\output\$thedate\$output_filename.ps1" `
        -outputfile "$env:PSMENU_DIR\executables\$thedate\$EXECUTABLES_DIRECTORY\$output_filename.exe"

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Executable created successfully: $env:PSMENU_DIR\executables\$thedate\$EXECUTABLES_DIRECTORY\$output_filename.exe" -ForegroundColor Green

    Invoke-Item "$env:PSMENU_DIR\executables\$thedate\$EXECUTABLES_DIRECTORY"
}

Export-ModuleMember -Function Build-PrinterConnectionExe