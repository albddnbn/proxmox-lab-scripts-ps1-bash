## Step 1 of series of script that will install/configure AD DS with other basic components of an AD Domain.
## Setup is meant to be used for a 'home lab' situation, and not for real prodution environment use.
## By Alex B., May 2024
param(
    # [ValidateScript({ Test-Path $_ -PathType Leaf })]
    # [string]$config_json = "step1.json",
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$step_two_script = "step2.ps1"
)


$config_json = Get-Content "step1.json" -Raw | ConvertFrom-Json
Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Creating variables from $config_json."
## Variables from json file:
$DOMAIN_NAME = $config_json.domain.name
$DC_PASSWORD = ConvertTo-SecureString $($config_json.domain.password) -AsPlainText -Force

## Domain Controller (static IP settings, hostname..)
$DC_HOSTNAME = $config_json.domain.dc_hostname
$STATIC_IP_ADDR = $config_json.domain.dc_ip
$DC_DNS_SETTINGS = $config_json.domain.dns_Servers
$GATEWAY_IP_ADDR = $config_json.domain.gateway
$SUBNET_PREFIX = $config_json.domain.subnet_prefix

## List the 7 variables created above in write-host with get-date timestemp
Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Variables created from $($config_json):"
Write-Host "DOMAIN_NAME:     $DOMAIN_NAME"
Write-Host "DC_PASSWORD:     ...."
Write-Host "DC_HOSTNAME:     $DC_HOSTNAME"
Write-Host "STATIC_IP_ADDR:  $STATIC_IP_ADDR"
Write-Host "DC_DNS_SETTINGS: $DC_DNS_SETTINGS"
Write-Host "GATEWAY_IP_ADDR: $GATEWAY_IP_ADDR"
Write-Host "SUBNET_PREFIX:   $SUBNET_PREFIX`n"

##----------------------------------------------------------------------------------------------------------------------

## Set hostname
Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Renaming computer to $DC_HOSTNAME.."
Rename-Computer -NewName $DC_HOSTNAME -Force

## cycle through attached drives and look for a drive with folder name like virtio
# Get all PSDrives
$drives = Get-PSDrive -PSProvider FileSystem

# Cycle through each drive
foreach ($drive in $drives) {
    # Search for the file in the root of the drive
    $file = Get-ChildItem -Path $drive.Root -Filter "virtio-win-gt-x64.msi" -File -ErrorAction SilentlyContinue

    # If the file is found, print its full name
    if ($file) {
        Write-Output "Found file: $($file.FullName), running installation."
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $($file.FullName) /qn /norestart" -Wait
        break
    }
}

## Set static IP address, DNS servers, gateway
$active_net_adapter = Get-NetAdapter | ? { $_.Status -Eq 'Up' }
if (-not $active_net_adapter) {
    Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: No active network adapter found, exiting script." -ForegroundColor Red
    Read-Host "Press enter to continue.."
}

Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Setting static IP address, DNS servers, and gateway.."
New-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $active_net_adapter.ifIndex `
    -IPAddress $STATIC_IP_ADDR -PrefixLength $SUBNET_PREFIX `
    -DefaultGateway $GATEWAY_IP_ADDR

Set-DNSClientServerAddress -InterfaceIndex $active_net_adapter.ifIndex `
    -ServerAddresses $DC_DNS_SETTINGS

## Enable network discovery and file/printer sharing (firewall rules):
Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Enabling Network Discovery and File/Printer Sharing.."
ForEach ($rulegroup in @("Network Discovery", "File and Printer Sharing")) {
    Enable-NetFirewallRule -DisplayGroup $rulegroup
}

## get working directory
$scripts_dir = $PSScriptRoot

$steptwo_path = "$scripts_dir\step2.ps1"

Write-Host "Creating scheduled task for step2.ps1..."

$taskAction = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$steptwo_path`""
$taskTrigger = New-ScheduledTaskTrigger -AtLogon
$taskPrincipal = New-ScheduledTaskPrincipal -UserId "NT Authority\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$scheduled_task = New-ScheduledTask -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal

# Get the name for step two scheduled task from config_json
$scheduled_task_name = "AD Gen Step 2"

Register-ScheduledTask -TaskName "$scheduled_task_name" -InputObject $scheduled_task

Start-Sleep -Seconds 2

shutdown /r /t 0

