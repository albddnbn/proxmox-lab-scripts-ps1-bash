Write-Host "Script WILL TARGET ALL .LOG files in specified directory."
$reportfolder = read-host "enter report folder path"

$outputfile = read-host "enter output .csv filepath"

$logfiles = Get-ChildItem -Path $reportfolder -Filter "*.log" -File

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
            Write-Host "Trying $property_name" -foregroundcolor cyan
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

$computer_settings | export-csv $outputfile -notypeinformation