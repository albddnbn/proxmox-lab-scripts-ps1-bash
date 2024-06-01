## AD Home/Test Lab Setup Scripts - Step 1
## Step 1 configures basic settings on the computer including: Hostname, static IP address, gateway, DNS servers, and 
## enabling network discovery and file/printer sharing firewall rules.
## Before trying to set network adapter settings - the script does a quick check for a virtio driver installer and attempts
## to install it if found. This enables the computer to 'see' the VirtIO network adapters.
## Author: Alex B.
## https://github.com/albddnbn/powershellnexusone
param(
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [Parameter(Mandatory = $false)]
    [string]$configjson = "domain_config.json"
)
# Makes sure configuration json exists.
try {
    $config_json = Get-Content $configjson -Raw | ConvertFrom-Json
}
catch {

    Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Error reading $configjson, exiting script." -ForegroundColor Red
    Read-Host "Press enter to exit.."
    Return 1

}
Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Creating variables from $configjson JSON file."
## Variables from json file:
## Domain Controller (static IP settings, hostname..)
$STATIC_IP_ADDR = $config_json.domain.dc_ip
$DC_DNS_SETTINGS = $config_json.domain.dns_Servers
$GATEWAY_IP_ADDR = $config_json.domain.gateway
$SUBNET_PREFIX = $config_json.domain.subnet_prefix
$DC_HOSTNAME = $config_json.domain.dc_hostname

Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Variables created from $($config_json):"
Write-Host "DC_HOSTNAME:     $DC_HOSTNAME"
Write-Host "STATIC_IP_ADDR:  $STATIC_IP_ADDR"
Write-Host "DC_DNS_SETTINGS: $DC_DNS_SETTINGS"
Write-Host "GATEWAY_IP_ADDR: $GATEWAY_IP_ADDR"
Write-Host "SUBNET_PREFIX:   $SUBNET_PREFIX`n"

# Renaming the computer
Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Renaming computer to $DC_HOSTNAME.."
Rename-Computer -NewName $DC_HOSTNAME -Force

## Check for virtio 64-bit Windows driver installer MSI file by cycling through base of connected drives.
$drives = Get-PSDrive -PSProvider FileSystem
foreach ($drive in $drives) {
    $file = Get-ChildItem -Path $drive.Root -Filter "virtio-win-gt-x64.msi" -File -ErrorAction SilentlyContinue
    # If/once virtio msi is found - attempt to install silently and discontinue the searching of drives.
    if ($file) {
        Write-Output "Found file: $($file.FullName), running installation."
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $($file.FullName) /qn /norestart" -Wait
        break
    }
}

## If no network adapter is found, even after virtio driver installation - no point in continuing with AD DS setup.
$active_net_adapter = Get-NetAdapter | ? { $_.Status -Eq 'Up' }
if (-not $active_net_adapter) {
    Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: No active network adapter found, exiting script." -ForegroundColor Red
    Read-Host "Press enter to exit.."
    Return 1
}

Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Network adapter found: $($active_net_adapter.Name)."
Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Setting static IP address, gateway, and DNS servers.."
Write-Host "IP Address:    $STATIC_IP_ADDR"
Write-Host "Gateway:       $GATEWAY_IP_ADDR"
Write-Host "DNS Servers:   $DC_DNS_SETTINGS"
Write-Host "Subnet Prefix: $SUBNET_PREFIX`n"
New-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $active_net_adapter.ifIndex `
    -IPAddress $STATIC_IP_ADDR -PrefixLength $SUBNET_PREFIX `
    -DefaultGateway $GATEWAY_IP_ADDR

Set-DNSClientServerAddress -InterfaceIndex $active_net_adapter.ifIndex `
    -ServerAddresses $DC_DNS_SETTINGS

## Enable network discovery and file/printer sharing (firewall rules):
Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Enabling Network Discovery and File/Printer Sharing.."
ForEach ($rulegroup in @("Network Discovery", "File and Printer Sharing")) {
    Enable-NetFirewallRule -DisplayGroup $rulegroup | Out-Null
}

## Until the kinks are worked out of the scheduled task method, or better method found:
Write-Host "After rebooting, run the step2.ps1 script." -Foregroundcolor Yellow
Read-Host "Press enter to reboot and apply changes." 
shutdown /r /t 0