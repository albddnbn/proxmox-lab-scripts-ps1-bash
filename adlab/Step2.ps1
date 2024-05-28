## Step 2 of series of script that will install/configure AD DS with other basic components of an AD Domain.
## Setup is meant to be used for a 'home lab' situation, and not for real prodution environment use.
## By Alex B., May 2024
param(
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$groups_json = "step2.json",
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$config = "step1.json",
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$users_csv = "users.csv"
)
Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Creating variables from $config_json."

$config_json = Get-Content "step1.json" -Raw | ConvertFrom-Json

## Variables from json file:
$DOMAIN_NAME = $config_json.domain.name
$DC_PASSWORD = ConvertTo-SecureString $config_json.domain.password -AsPlainText -Force
$DC_HOSTNAME = $config_json.domain.dc_hostname
$DOMAIN_NETBIOS = $config_json.domain.netbios

## DHCP server variables:
$DHCP_IP_ADDR = $config_json.dhcp.ip_addr
$DHCP_SCOPE_NAME = $config_json.dhcp.scope.name
$DHCP_START_RANGE = $config_json.dhcp.scope.start
$DHCP_END_RANGE = $config_json.dhcp.scope.end
$DHCP_SUBNET_PREFIX = $config_json.dhcp.scope.subnet_prefix
$DHCP_GATEWAY = $config_json.dhcp.scope.gateway
$DHCP_DNS_SERVERS = $config_json.dhcp.scope.dns_servers

## List the variables created above with get0-date timestampe
Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Variables created from $($config_json):"
Write-Host "DOMAIN_NAME:        $DOMAIN_NAME"
Write-Host "DC_PASSWORD:        ...."
Write-Host "DOMAIN_NETBIOS:     $DOMAIN_NETBIOS"
Write-Host "DHCP_IP_ADDR:       $DHCP_IP_ADDR"
Write-Host "DHCP_SCOPE_NAME:    $DHCP_SCOPE_NAME"
Write-Host "DHCP_START_RANGE:   $DHCP_START_RANGE"
Write-Host "DHCP_END_RANGE:     $DHCP_END_RANGE"
Write-Host "DHCP_SUBNET_PREFIX: $DHCP_SUBNET_PREFIX"
Write-Host "DHCP_GATEWAY:       $DHCP_GATEWAY"
Write-Host "DHCP_DNS_SERVERS:   $DHCP_DNS_SERVERS`n"

Write-Host "Installing AD DS.."

## Install AD DS
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

Write-Host "Creating new AD DS Forest.."
Install-ADDSForest -DomainName $DOMAIN_NAME -DomainMode WinThreshold -ForestMode WinThreshold -InstallDns -SafeModeAdministratorPassword $DC_PASSWORD -Force -Confirm:$false
## get working directory
$scripts_dir = $PSSCRIPTRoot

$stepthree_path = "$scripts_dir\step3.ps1"

Write-Host "Creating scheduled task for step3.ps1..."

$taskAction = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$stepthree_path`""
$taskTrigger = New-ScheduledTaskTrigger -AtLogon
$taskPrincipal = New-ScheduledTaskPrincipal -UserId "NT Authority\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$scheduled_task = New-ScheduledTask -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal

# Get the name for step two scheduled task from config_json
$scheduled_task_name = "AD Gen Step 3"

## delete step 2 task: 
Get-ScheduledTask -TaskName "AD Gen Step 2" | Unregister-ScheduledTask

Register-ScheduledTask -TaskName "$scheduled_task_name" -InputObject $scheduled_task

Start-Sleep -Seconds 2

shutdown /r /t 0
