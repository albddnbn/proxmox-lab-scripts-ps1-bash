# read csv.
$bios_csv = read-host "enter path to bios setting .csv file output by script #2"
## Group rows by SysName (Computer Model)
try {
    $bios_csv = import-csv $bios_csv
}
catch {
    write-host "Error importing csv. Check path and try again."
    return
}

$unique_models = $bios_csv | select-object -expandproperty sysname -unique | sort

## 1. Choose a model.

## 2. Choose a BIOS setting

## 3. Pie graph generated through powershell for that statistic?
# People don't really need more than the spreadsheet to hold on to - pie graphs for quick examinations of specific bios setting



ForEach ($computer_model in $unique_models) {
    $computers_bios_rows = $bios_csv | where-object { $_.sysname -eq $computer_model }

    # now that you have a list of all of the targeted computers, of a certain model/type - can generate helpful pictures of range bios settings

    
}