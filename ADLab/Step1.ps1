$config_json = Get-ChildItem -Path '.' -filter "variables.json" -File -ErrorAction SilentlyContinue

if (-not $config_json) {
    Write-Host "variables.json not found in the current directory"
    exit 1
}

$config = Get-Content $config_json -Raw | ConvertFrom-Json
$ip_address = $config.domainControllerIP
$gateway_ip = $config.gatewayIP
$dns_ips = $config.dnsServer
$prefix_length = $config.subnetPrefix


## Set Static IP, and DNS info
$active_net_adapter = Get-NetAdapter | ? { $_.Status -Eq 'Up' }
New-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $active_net_adapter.ifIndex `
    -IPAddress $ip_address -PrefixLength $prefix_length `
    -DefaultGateway $gateway_ip

Set-DNSClientServerAddress -InterfaceIndex $active_net_adapter.ifIndex `
    -ServerAddresses $dns_ips

## Set computer hostname
Rename-Computer -NewName $config.domainController -Force

## Enable network discovery and file/printer sharing firewall rules:
ForEach ($rulegroup in @("Network Discovery", "File and Printer Sharing")) {
    Enable-NetFirewallRule -DisplayGroup $rulegroup
}

## Set Step 2 to run as scheduled task on reboot:
$Step2Script = Get-ChildItem -Path "." -Filter "Step2.ps1" -File -ErrorAction SilentlyContinue
if (-not $Step2Script) {
    Write-Host "Step2.ps1 not found in the current directory"
    exit 1
}

Copy-Item -Path "$($Step2Script.fullname)" `
    -Destination "$(New-Item -Path "C:\Temp" -Itemtype 'directory' `
    -ErrorAction Silentlycontinue | Select -exp fullname)/"

$taskAction = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Temp\Step2.ps1"
$taskTrigger = New-ScheduledTaskTrigger -Once -AtLogon
$taskPrincipal = New-ScheduledTaskPrincipal -UserId "NT Authority\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

$scheduled_task = New-ScheduledTask -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal

Register-ScheduledTask -TaskName "ADLabSetupStep2" -InputObject $scheduled_task

Write-Host "Rebooting in 5 seconds..."
Start-Sleep -Seconds 5
Restart-Computer -Force