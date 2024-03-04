# detects any fritzing scheduled task - either user or public
$SCHED_TASK_TITLE = 'Fritzing'
# comment out or set to '' for private install
$Installtype = 'public'

# check for scheduled task
$test_for_task = Get-ScheduledTask | Where-object { $_.taskname -like "$SCHED_TASK_TITLE*" }

# check for fritzing.exe
if ($installtype -eq 'public') {
    $check_for_public_exe = Get-Childitem -Path "C:\Users\Public\Documents\Fritzing" -filter "fritzing.exe" -file -recurse -erroraction silentlycontinue
}
$check_for_exe = Get-Childitem -Path "C:\Program Files (x86)\Fritzing" -filter "fritzing.exe" -file -recurse -erroraction silentlycontinue

if (($test_for_task) -and ($check_for_exe)) {
    # if its a public installation - task has already been found with prog files exe
    # if public exe is found - report success
    if (($installtype -eq 'public') -and ($check_for_public_exe)) {
        Write-Host "Scheduled task, public exe, and prog files x86 exe found. Installed."
        Exit 0
    }
    # if its not - report failure
    elseif (($installtype -eq 'public') -and (-not ($check_for_public_exe)) ) {
        # Write-Host "Scheduled task, prog files x86 exe found. Installed"
        Exit 1
    }
    # has to be private installation at this point - and conditions have already been filled - report success
    else {
        Write-Host "Scheduled task and prog files x86 exe found. Installed."
        Exit 0
    }
}
else {
    Exit 1
}