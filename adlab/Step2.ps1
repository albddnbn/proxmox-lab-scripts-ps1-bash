## AD Home/Test Lab Setup Scripts - Step 2
## Step 2 installs AD-Domain-Services feature.
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
Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Creating variables from $config_json."
## Variables from json file:
$DOMAIN_NAME = $config_json.domain.name
$DC_PASSWORD = ConvertTo-SecureString $config_json.domain.password -AsPlainText -Force

## List the variables created above with get0-date timestampe
# Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Variables created from $($config_json):"
Write-Host "DOMAIN_NAME:        $DOMAIN_NAME"
Write-Host "DC_PASSWORD:        ...."

Write-Host "Installing AD DS.."

## Install AD DS
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

Write-Host "Creating new AD DS Forest.."
Install-ADDSForest -DomainName $DOMAIN_NAME -DomainMode WinThreshold -ForestMode WinThreshold `
    -InstallDns -SafeModeAdministratorPassword $DC_PASSWORD -Force -Confirm:$false

## System should reboot automatically here?
read-host "if system hasn't rebooted, press enter to reboot.."
Restart-Computer -Force