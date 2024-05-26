This project involves a series of scripts to allow me to quickly recreate the components necessary for an Active Directory Lab including items listed below (divided by scripting language).

Bash script is run initially to create:
1. Virtual network/gateway through the use of Proxmox's SDN feature with ability to switch Internet access on/off instantaneously.
2. VM in Proxmox using combination of configuration variables and known-good settings. At this point, the script will target the specified storage drive and list a menu of iso's. This allows the user to select their Windows Server iso, and then the VirtIO iso containing drivers necessary to use certain storage types.
3. Using a template and Proxmox's built-in API, basic firewall rules necessary for an Active Directory domain controller are applied to the VM created and enabled.

Powershell script(s):

1. Install/configure Active Directory Domain Services with DNS, DHCP
2. Create file shares for roaming profiles/folder redirection and apply necessary permissions.
3. Generate basic structure of OUs/Groups/Users.