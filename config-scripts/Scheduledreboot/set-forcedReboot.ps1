## Creates scheduled task that will force a reboot on the machine - every Sunday at midnight for maintenance purposes.
## Author: alex B.
$taskTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 12am
$taskAction = New-ScheduledTaskAction -Execute "shutdown.exe" -Argument "/r /t 0"
$taskprincipal = New-ScheduledTaskPRincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$tasksettings = New-ScheduledTaskSettingsSet
$task_object = new-scheduledtask -action $taskaction -principal $taskprincipal -trigger $taskTrigger -settings $tasksettings
Register-ScheduledTask "Weekly Reboot [Sun,12am]" -InputObject $task_object