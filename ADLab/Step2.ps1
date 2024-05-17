$config_json = Get-ChildItem -Path '.' -filter "variables.json" -File -ErrorAction SilentlyContinue

if (-not $config_json) {
    Write-Host "variables.json not found in the current directory"
    exit 1
}

$config = Get-Content $config_json -Raw | ConvertFrom-Json
$dhcp = $config.dhcp

$domainName = $config.domainName
$domainNetBIOSName = $config.domainNetBIOSName
$DCHostName = $config.domainController
$DC_IP_Address = $config.domainControllerIP
$gateway_ip = $config.gatewayIP

## DNS Servers
$dnsservers = $config.domain.dnsServers

$securePassword = ConvertTo-SecureString $config.insecurePassword -AsPlainText -Force

## Set up AD DS
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
Install-ADDSForest -DomainName $domainName -DomainMode WinThreshold -ForestMode WinThreshold -InstallDns -SafeModeAdministratorPassword $securePassword -Force -Confirm:$false



## DHCP
Install-WindowsFeature -Name DHCP -IncludeManagementTools

Add-DHCPServerInDC -DnsName "$DCHostName.$domainName" -IPAddress $dhcp.dhcpServerIp 

# DHCP Scope
Add-DHCPServerv4Scope -Name $dhcp.scope.name -StartRange $dhcp.scope.start `
    -EndRange $dhcp.scope.end -SubnetMask $dhcp.scope.subnetPrefix `
    -State Active

Set-DHCPServerv4OptionValue -ComputerName "$DCHostName.$domainName" `
    -DnsServer $dnsservers -DnsDomain "$($config.domain.name)" `
    -Router "$($config.domain.gatewayIP)"

## Setup Groups and users.
$groups_json = Get-Childitem -path "." -filter "groups.json" -File -erroraction SilentlyContinue

if (-not $groups_json) {
    Write-Host "groups.json not found in the current directory"
    exit 1
}


$dcPath = (Get-ADDomain).DistinguishedName

$groups_json = get-content "$($groups_json.fullname)" -raw | Convertfrom-Json

$main_ou = $groups_json.ous.name

$sub_ous = ($groups_json.ous.children.name) -split ' '

$groups = ($groups_json.groups.Name) -split ' '

New-ADORganizationalUnit -Name $main_ou -Path $dcPath

ForEach ($single_ou in $sub_ous) {
    New-ADORganizationalUnit -Name $single_ou -Path "OU=$main_ou,$dcPath"
}

## create groups:
ForEach ($single_group in $groups) {
    New-ADGroup -Name $single_group -GroupScope Global `
        -GroupCategory Security -Path "OU=$single_group,OU=$main_ou,$dcPath" `
        -Description "Home Lab $($single_group.toupper())"
}

$users_csv = Get-Childitem -path "." -filter "users.csv" -File -erroraction SilentlyContinue
if (-not $users_csv) {
    Write-Host "users.csv not found in the current directory"
    exit 1
}

$users_csv = import-csv -path "$($users_csv.fullname)"
ForEach ($user_account in $users_csv) {

    $firstname = $user_account.firstname
    $lastname = $user_account.lastname
    $deptname = $user_account.department
    
    ## grab first 7 characters from last name
    $username = $lastname.Substring(0, 7)
    $username = "$($firstname[0])$username"

    ## password = $securePassword

    $splat = @{
        SamAccountName    = $username
        UserPrincipalName = "$username@$domainName"
        Name              = "$firstname $lastname"
        GivenName         = $firstname
        Surname           = $lastname
        Department        = $deptname
        AccountPassword   = $securePassword
        Enabled           = $true
        Path              = "OU=users,OU=$main_ou,$dcPath" ## explicit listing of the users group
    
    }

    Write-Host "`nCreating user account for $firstname $lastname." -ForegroundColor Yellow
    Write-Host "Username: $username"
    Write-Host "Department: $deptname"

    New-ADUser @splat

    ## Add user to their dept group
    Add-ADGroupMember -Identity $deptname -Members $username

    ## if they're an IT user - make them an admin
    if ($deptname -eq "IT") {

        $admin_splat = @{
            SamAccountName    = "$($username)_admin"
            UserPrincipalName = "$($username)_admin@$domainName"
            Name              = "$firstname $lastname (Admin)"
            GivenName         = $firstname
            Surname           = $lastname
            Department        = $deptname
            AccountPassword   = $securePassword
            Enabled           = $true
            Path              = "OU=admins,OU=$main_ou,$dcPath" ## explicit listing of the users group
        
        }
    
        Write-Host "`nCreating admin account for $firstname $lastname." -ForegroundColor Yellow
        Write-Host "Username: $($username)_admin"
        Write-Host "Department: $deptname"

        New-ADUser @admin_splat

        ## Add user to their dept group
        Add-ADGroupMember -Identity admins -Members "$($username)_admin"

    }

}


## Create Network shares for Folder Redirection and Roaming profiles.
$shares_json = Get-Childitem -path "." -filter "shares.json" -File -erroraction SilentlyContinue
if (-not $shares_json) {
    Write-Host "shares.json not found in the current directory"
    exit 1
}

$shares_json = get-content "$($shares_json.fullname)" -raw | Convertfrom-Json

ForEach ($single_folder in $shares_json.name) {

    $full_path = "C:\Shares\$single_folder"


    New-Item -Path "$full_path" -ItemType Directory | Out-Null
    New-SmbShare -Name $single_folder -Path "$full_path" -FullAccess ("admins", "Domain Admins", "Administrators") -Name $single_folder

    Write-Host "Created share for $single_folder" -ForegroundColor Yellow

    ## set permissions on share - the profiles share looks like it can be more restrictive, will have to edit when edits are made to config jsons.

    $acl = Get-Acl -Path $full_path

    ## Disable inheritance and convert inherited permissions to explicit
    $acl.SetAccessRuleProtection($true, $true)

    ## set ACLs
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")))
}

