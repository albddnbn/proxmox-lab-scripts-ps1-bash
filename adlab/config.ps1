## Domain configuration:
$DOMAIN_CONFIG = [PSCustomObject]@{
    Name = 'test.lab'
    Netbios = 'TEST'
    DC_Hostname = 'lab-dc-01'
    DC_IP = '10.0.0.2'
    DNS_Servers = @('10.0.0.2','8.8.8.8')
    Gateway = '10.0.0.1'
    Subnet_Prefix = '24'
    Password = 'Somepass1'
}

$DHCP_SERVER_CONFIG = [PSCustomObject]@{
    IP_Addr = $DOMAIN_CONFIG.DC_IP
    Scope = [PSCustomObject]@{
        Name = 'Test Lab DHCP Scope'
        Start = '10.0.0.10'
        End = '10.0.0.240'
        Gateway = $DOMAIN_CONFIG.Gateway
        Subnet_Prefix = $DOMAIN_CONFIG.Subnet_Prefix
        DNS_Servers = $DOMAIN_CONFIG.DNS_Servers
    }
}
## Fileshare configuration:
$FILESHARE_CONFIG = @(
    ## SMB Share to hold roaming profile data for regular users
    [PSCustomObject]@{
        Name = 'profiles$'
        Path = 'C:/Shares/profiles$'
        Description = 'Profiles share'
    },
    ## SMB Share to hold user homedrive data for regular users
    [PSCustomObject]@{
        Name = 'users'
        Path = 'C:/Shares/users'
        Description = 'Users share'
    }
)

## User and group configuration - set names for regular user, admin, and computer groups/OUs
$USER_AND_GROUP_CONFIG = {
    ## admins group, AD users in the IT department have _admin admin account created for them.
    ## the _admin accounts are added to this group.
    "admins": [PSCustomObject]@{
        Name = "LabAdmins"
        Description = "Lab Admins"
        MemberOf = @('Domain Admins')
    },
    "computers": [PSCustomObject]@{
        Name = "LabComputers"
        Description = "Lab Computers"
        MemberOf = @('Domain Computers')
    },
    "users": [PSCustomObject]@{
        Name = "LabUsers"
        Description = "Lab Users"
        MemberOf = @('Domain Users')
    },
    ## Base OU (all users, groups, ous, etc. are added to this OU)
    "base_ou": "homelab"
}