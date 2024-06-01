## AD Home/Test Lab Setup Scripts - Step 3
## Step 3 Installs and configures DHCP server/settings. Then, creates OU structure and users.
## Author: Alex B.
## https://github.com/albddnbn/powershellnexusone
param(
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [Parameter(Mandatory = $false)]
    [string]$configjson = "domain_config.json",
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [Parameter(Mandatory = $false)]
    [string]$groupsjson = "groups.json",
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [Parameter(Mandatory = $false)]
    [string]$userscsv = "users.csv",
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [Parameter(Mandatory = $false)]
    [string]$sharesjson = "fileshares.json"
)
# Makes sure configuration json exists.
try {
    $config_json = Get-Content $configjson -Raw | ConvertFrom-Json
    $groups_json = Get-Content $groupsjson -Raw | ConvertFrom-Json
    $user_info = Import-CSV -Path $userscsv
    $shares_json = get-content $sharesjson -Raw | ConvertFrom-Json
}
catch {
    Write-Host "$_"
    Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Error reading one of configuration files, exiting script." -ForegroundColor Red
    Read-Host "Press enter to exit.."
    Return 1

}
Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Creating variables from $config_json."

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

$DOMAIN_PATH = (Get-ADDomain).DistinguishedName

$BASE_OU = "homelab"


## Users will be placed into this OU:
$OU_NAME = "users"

$USER_DEST_PATH = "OU=$ou_name,OU=$BASE_OU,$DOMAIN_PATH"

## DHCP
Install-WindowsFeature -Name DHCP -IncludeManagementTools

Restart-service dhcpserver

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

## Create users using users.csv\
Write-Host "[$(Get-Date -Format 'mm-dd-yyyy HH:mm:ss')] :: Creating users from $users_csv."

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
        DisplayName       = "$firstname $lastname"
        Name              = $username
        GivenName         = $firstname
        Surname           = $lastname
        Department        = $deptname
        AccountPassword   = $DC_PASSWORD
        Enabled           = $true
        Path              = "$USER_DEST_PATH" ## explicit listing of the users group
        HomeDrive         = 'Z'
        HomeDirectory     = "\\$DC_HOSTNAME\users\$username"
        ProfilePath       = "\\$DC_HOSTNAME\profiles$\$username"
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
            SamAccountName    = $admin_username
            UserPrincipalName = "$admin_username@$DOMAIN_NAME"
            DisplayName       = "$firstname $lastname (admin)"
            Name              = $admin_username
            # GivenName         = $firstname
            # Surname           = $lastname
            Department        = $deptname
            AccountPassword   = $DC_PASSWORD
            Enabled           = $true
            Path              = "OU=admins,OU=$BASE_OU,$DOMAIN_PATH" ## explicit listing of the users group
        
        }
    
        Write-Host "`nCreating admin account for $firstname $lastname." -ForegroundColor Yellow
        Write-Host "Username: $admin_username"
        Write-Host "Department: $deptname"

        New-ADUser @admin_splat

        ## Add user to their dept group
        Add-ADGroupMember -Identity testlabadmins -Members "$admin_username"

    }
}

## create file shares for folder redirection and roaming profiles, assign correct permissions for the users group created above.


If (-not (Test-Path C:\Shares -ErrorAction SilentlyContinue)) {
    New-Item -Path C:\Shares -ItemType Directory | Out-null
}
ForEach ($share_obj in $shares_json) {

    $ShareParameters = @{
        Name                  = $share_obj.name
        Path                  = $share_obj.path
        Description           = $share_obj.description
        FullAccess            = "$DOMAIN_NETBIOS\Domain Admins", "$DOMAIN_NETBIOS\testlabadmins", "Administrators" # explicit admin listing.
        ReadAccess            = "$DOMAIN_NETBIOS\Domain Users"
        FolderEnumerationMode = "AccessBased"
    }
    Write-Host "`nCreating SMB share: $($share_obj.name)."

    if (-not (Test-Path "$($share_obj.path)" -ErrorAction SilentlyContinue)) {
        New-Item -Path $share_obj.path -ItemType Directory | Out-Null
    }

    New-SmbShare @ShareParameters

    ## disbale inheritance, convert to explicit permissions
    $acl = Get-Acl -Path $share_obj.path
    $acl.SetAccessRuleProtection($true, $true)
    ## Add access rule for testlabusers group:
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("$DOMAIN_NETBIOS\testlabusers", "ReadandExecute,CreateDirectories,AppendData,Traverse,ExecuteFile", "Allow")))
    Set-Acl -Path $share_obj.path -AclObject $acl
}