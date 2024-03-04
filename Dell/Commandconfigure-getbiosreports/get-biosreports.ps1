$hostname_file = Read-Host "Enter path to hostname text file"

$outputfolder = Read-Host "enter full path to output folder for logs"

$biospwd = read-host "enter bios pw to pass to cctk.exe"

if (-not (Test-Path $hostname_file -erroraction SilentlyContinue)) {
    Write-Host "File not found: $hostname_file"
    return
}
if (-not (Test-Path $outputfolder -erroraction silentlycontinue)) {
    New-Item $outputfolder -itemtype 'directory'
}
$computers = get-content $hostname_file
# get rid of any blank lines (at end of hostname text file)
$computers = $computers | where-object { ($_ -ne $null) -and ($_ -ne '') }

$newcomputers = [System.Collections.ArrayList]::new()
ForEach ($single_computer in $computers) {
    $pingresult = Test-Connection $single_computer -count 1 -Quiet
    if ($pingresult) {
        Write-Host "[$single_computer] :: Online" -foregroundcolor Green

        $newcomputers.add($single_computer) | out-null
    }
    else {
        Write-Host "[$single_computer] :: Offline" -foregroundcolor Red
    }
}

$computers = $newcomputers

$results = Invoke-Command -computername $computers -scriptblock {

    $obj = [pscustomobject]@{
        # CCTKPresent = "NO"
        ReportFile = ""
    }

    $cctk = Get-Childitem -path "C:\Program Files (x86)\Dell\Command Configure\X86_64" -filter "cctk.exe" -File -ErrorAction SilentlyContinue

    if (-not $cctk) {
        Write-Host "[$env:COMPUTERNAME] :: cctk.exe not found in C:\Program Files (x86)\Dell\Command Configure\X86_64" -Foregroundcolor Red
        return $obj
    }
    # $obj.CCTKPresent = "YES"

    $filename = "C:\temp\$env:COMPUTERNAME-biosreport.log"
    if (-not (Test-Path C:\temp -erroraction silentlycontinue)) {
        New-Item C:\temp -itemtype 'directory'
    }

    &"$($cctk.fullname)" --ValSetupPwd=$biospwd --OutFile=$filename

    $filestring = "temp\$env:COMPUTERNAME-biosreport.log"

    $obj.ReportFile = $filestring
    return $obj

    # output report to C:\temp, return filename
}


$need_cctk = $results | where-object { $_.ReportFile -eq "" } | Select -exp pscomputername

$have_cctk = $results | where-object { $_.ReportFile -ne "" }

if ($need_cctk) {
    Write-Host "These computers don't have CCTK."
    Write-Host "$($need_cctk -join ', ')"

    $need_cctk | out-file "needcctk.txt"

    Invoke-Item "needcctk.txt"

}
Write-Host "Collecting logs..."

# cycle through results - report computers that need install, collect logs that are there, remove them from computers to clean up afterwards
ForEach ($single_computer in $have_cctk) {
    $reportfile_path = $single_computer.reportfile
    # if ($reportfile_path -match '[A-Za-z]:\\*') {
    #     $reportfile_path = $reportfile_path.substring(3)
    # }

    $report_filepath = "\\$($single_computer.pscomputername)\c$\$reportfile_path"

    Copy-ITem $report_filepath $outputfolder
    Write-Host "Collected log from $($single_computer.pscomputername)"

    Remove-Item $report_filepath
}


# create a .csv file - using compare-reports.ps1

$outputfile = read-host "enter output .csv filepath"

$logfiles = Get-ChildItem -Path $outputfolder -Filter "*.log" -File

$computer_settings = [system.collections.arraylist]::new()
write-host "Got these files $($logfiles.name)"
# cycle through reports, create an object for each computer
# properties = the settings i care about right now/first
ForEach ($single_log in $logfiles) {
    $logfile_path = $single_log.fullname

    $logfile_name = $single_log.name

    $computer_name = $($logfile_name -split "-biosreport")[0]

    $logfile_content = Get-Content "$logfile_path"

    $obj = [pscustomobject]@{
        ComputerName         = $computer_name
        SysName              = ""
        AcPwrRcvry           = ""
        AutoOn               = ""
        AutoOnHr             = 0
        AutoOnMn             = 0
        BIOSVer              = ""
        BlockSleep           = ""
        CStatesCtrl          = ""
        DeepSleepCtrl        = ""
        Fastboot             = ""
        PrimaryVideoSlot     = ""
        SHA256               = ""
        TpmActivation        = ""
        TpmSecurity          = ""
        TurboMode            = ""
        UefiBootPathSecurity = ""
        UefiNwStack          = ""
        UsbPowerShare        = ""
        UsbWake              = ""
        WakeOnLan            = ""
        WirelessLan          = ""
    }
    
    ForEach ($property_name in $($obj.psobject.properties | select -exp name)) {
        if ($property_name -ne 'ComputerName') {
            $cctk_log_line = $logfile_content | where-object { $_ -like "$property_name=*" }
            if ($cctk_log_line) {

                $cctk_log_line_item_value = $($cctk_log_line -split "=")[1]

                $obj.$property_name = $cctk_log_line_item_value
            }
            else {
                $obj.$property_name = "Not in log file?"
            }
        }

    }
    # get important settings:
    $computer_settings.add($obj) | out-null
}

if ($outputfile -notlike "*.csv") {
    $outputfile = "$outputfile.csv"

}

if (Test-Path $outputfile -erroraction silentlycontinue) {
    $computer_settings | export-csv $outputfile -notypeinformation
}