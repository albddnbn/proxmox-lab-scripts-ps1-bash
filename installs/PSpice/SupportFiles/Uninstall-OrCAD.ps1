$APPLICATION_GUIDS = @(
    "{2D444666-5875-4B28-9ED8-15F750802BF5}"
)
Write-Host "These are the application GUIDs that will be used for uninstall:"
$APPLICATION_GUIDS

$REG_KEYS_TO_REMOVE = [system.collections.arraylist]::new()
# add both hkcu and hklm keys:
$REG_KEYS_TO_REMOVE.add($(Get-Content ./SupportFiles/hklm.txt))
$REG_KEYS_TO_REMOVE.add($(Get-Content ./SupportFiles/hkcu.txt))

Write-Host "These registry keys will be removed during the uninstallation process for OrCAD:"
$REG_KEYS_TO_REMOVE

$FOLDER_TO_REMOVE = @(
    "C:\Program Files (x86)\Cadence\SPB*" # SPB 17.4
)


## STAGE 1 - Delete registry keys
ForEach ($reg_key in $REG_KEYS_TO_REMOVE) {
    $check_for_reg_key = Test-Path $reg_key -erroraction SilentlyContinue
    if ($check_for_reg_key) {
        Write-Host "[$env:COMPUTERNAME] :: Deleting registry key: $reg_key"
        Remove-Item -Path $reg_key -Recurse -Force -erroraction SilentlyContinue
    }
    else {
        Write-Host "[$env:COMPUTERNAME] :: Registry key does not exist: $reg_key"
    }
}

## STAGE 2 - Delete InstallShield foldeR(s) for app guids
ForEach ($app_guid in $APPLICATION_GUIDS) {
    $installshield_folder = "C:\Program Files (x86)\InstallShield Installation Information\$app_guid"
    $check_for_installshield_folder = Test-Path $installshield_folder -erroraction SilentlyContinue
    if ($check_for_installshield_folder) {
        Write-Host "[$env:COMPUTERNAME] :: Deleting InstallShield folder: $installshield_folder"
        Remove-Item -Path $installshield_folder -Recurse -Force -erroraction SilentlyContinue
    }
    else {
        Write-Host "[$env:COMPUTERNAME] :: InstallShield folder does not exist: $installshield_folder"
    }
}

## STAGE 3 - Delete folders
ForEach ($folder in $FOLDER_TO_REMOVE) {
    $check_for_folder = Test-Path $folder -erroraction SilentlyContinue
    if ($check_for_folder) {
        Write-Host "[$env:COMPUTERNAME] :: Deleting folder: $folder"
        Remove-Item -Path $folder -Recurse -Force -erroraction SilentlyContinue
    }
    else {
        Write-Host "[$env:COMPUTERNAME] :: Folder does not exist: $folder"
    }
}
