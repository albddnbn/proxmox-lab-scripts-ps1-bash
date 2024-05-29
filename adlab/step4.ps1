Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Creating variables from $config_json."

$config_json = Get-Content "domain_config.json" -Raw | ConvertFrom-Json

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


## DHCP
Install-WindowsFeature -Name DHCP -IncludeManagementTools

## Reboot here or try retarting service
Restart-service dhcpserver
#shutdown /r /t 0

Add-DHCPServerInDC -DnsName "$DC_HOSTNAME.$DOMAIN_NAME" -IPAddress $DHCP_IP_ADDR

# DHCP Scope
Add-DHCPServerv4Scope -Name "$DHCP_SCOPE_NAME" -StartRange "$DHCP_START_RANGE" `
    -EndRange "$DHCP_END_RANGE" -SubnetMask $DHCP_SUBNET_PREFIX `
    -State Active

# Force specifies that the DNS server validation is skipped - since the current bash script has SNAT turned off for vnet.
Set-DHCPServerv4OptionValue -ComputerName "$DC_HOSTNAME.$DOMAIN_NAME" `
    -DnsServer $DHCP_DNS_SERVERS -DnsDomain "$DOMAIN_NAME" `
    -Router $DHCP_GATEWAY -Force
    

##
## Create OUs, users, and groups.
##
$groups_json = Get-Content "groups.json" -Raw | ConvertFrom-Json
$DOMAIN_PATH = (Get-ADDomain).DistinguishedName

$BASE_OU = "homelab"
# Create a base 'homelab' OU, then OUs/groups from json inside.
New-ADOrganizationalUnit -Name "$BASE_OU" -Path "$DOMAIN_PATH" -ProtectedFromAccidentalDeletion $false

# Foreach OU in json - create ou, then create child groups
ForEach ($single_ou in $groups_json) {
    write-host $single_ou.name
    $ou_name = $single_ou.name
    write-host $ou_name
    write-host "creating ou"
    New-ADOrganizationalUnit -Name $ou_name -Path "OU=$BASE_OU,$DOMAIN_PATH" -ProtectedFromAccidentalDeletion $false

    ForEach ($single_group in $single_ou.children) {
        $group_name = $single_group.name
        $group_desc = $single_group.description
        New-ADGroup -Name $group_name -GroupCategory Security -GroupScope Global -Path "OU=$ou_name,OU=$BASE_OU,$DOMAIN_PATH" -Description $group_desc

        ForEach ($member in $single_group.memberof) {
            Add-ADGroupMember -Identity $member -Members $group_name
        }
    }
}

## Create users using users.csv
$user_info = Import-CSV -Path "users.csv"

Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Creating users from $users_csv."

## Users will be placed into this OU:
$OU_NAME = "users"

$USER_DEST_PATH = "OU=$ou_name,OU=$BASE_OU,$DOMAIN_PATH"

## First, need to create a group for each department listed in csv
ForEach ($unique_dept in $($user_info | select -exp department | select -unique)) {

    Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Creating group for $unique_dept."

    New-ADGroup -Name $unique_dept -GroupCategory Security -GroupScope Global -Path "$USER_DEST_PATH" -Description "Departmental group for $unique_dept"
}

ForEach ($user_account in $user_info) {
    $firstname = $user_account.firstname
    $lastname = $user_account.lastname
    $deptname = $user_account.department
    
    ## grab first 7 characters from last name
    if ($lastname.length -ge 8) {
        $username = $lastname.Substring(0, 8)
    }
    else {
        $username = $lastname
    }
    $username = "$($firstname[0])$username"

    ## password = $DC_PASSWORD

    $splat = @{
        SamAccountName    = $username
        UserPrincipalName = "$username@$DOMAIN_NAME"
        Name              = "$firstname $lastname"
        GivenName         = $firstname
        Surname           = $lastname
        Department        = $deptname
        AccountPassword   = $DC_PASSWORD
        Enabled           = $true
        Path              = "$USER_DEST_PATH" ## explicit listing of the users group
    
    }

    Write-Host "`nCreating user account for $firstname $lastname." -ForegroundColor Yellow
    Write-Host "Username: $username"
    Write-Host "Department: $deptname"

    New-ADUser @splat

    ## Add user to their dept group
    Add-ADGroupMember -Identity $deptname -Members $username

    Add-ADGroupMember -Identity testlabusers -Members $username ## need to make this identity variable/dynamic

    
    ## if they're an IT user - make them an admin
    if ($deptname -eq "IT") {

        $admin_username = "$($username)_admin"

        $admin_splat = @{
            SamAccountName    = "$admin_username"
            UserPrincipalName = "$admin_username@$DOMAIN_NAME"
            Name              = "$firstname $lastname admin"
            GivenName         = $firstname
            Surname           = $lastname
            Department        = $deptname
            AccountPassword   = $DC_PASSWORD
            Enabled           = $true
            Path              = "OU=admins,OU=$main_ou,$dcPath" ## explicit listing of the users group
        
        }
    
        Write-Host "`nCreating admin account for $firstname $lastname." -ForegroundColor Yellow
        Write-Host "Username: $($username)_admin"
        Write-Host "Department: $deptname"

        New-ADUser @admin_splat

        ## Add user to their dept group
        Add-ADGroupMember -Identity testlabadmins -Members "$($username)_admin"

    }
}

## remove the scheduled tasks:
Get-ScheduledTask | Where-Object { $_.Name -like "AD Gen Step*" } | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue