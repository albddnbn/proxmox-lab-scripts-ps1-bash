# NOTE: As of ~June, 2024, I've moved the 'User Installation Framework' to it's own repository. I've also made a number of changes that I hope are improvements!

[PSADT-Install-Framework Repository](https://github.com/albddnbn/psadt-install-framework)

# User Installation Steps

**Date:** March 3, 2024

**Author:** Alex B.

## Definitions

### Public Installation

- Copies source files to specified directory on local filesystem (somewhere in `C:\Program Files` or `C:\Program Files (x86)` is suggested)
- Copies source files from source directory to `C:\Users\Public\<application name>` directory
- Copies the public installation shortcut from source directory to `C:\Users\Public\Desktop`
- Creates scheduled task that re-performs this copying action each time a user logs into the machine

### Private Installation

- Copies source files to specified directory on local filesystem (somewhere in `C:\Program Files` or `C:\Program Files (x86)` is suggested)
- Copies source files to `C:\Users\<username>\<application name>` directory for each existing user in `C:\Users`
- Copies the private installation shortcut to `C:\Users\<username>\AppData\Local\Microsoft\Windows\Start Menu`
- Creates scheduled task to perform the same copying actions for any new user that logs in to the computer.

### ApplicationName Folder

Throughout these directions, `ApplicationName Folder` is the term used to refer to this folder, in the ‘User Installation Framework’. This is the folder that contains the PSADT Toolkit files. The folder that will be renamed to conform to the application you are working on. Ex: for Dev-C++, this folder is renamed: ‘Dev-C++’.

If the installation requires more than what’s listed above in the public/private installation definitions, the PSADT installation scripts will have to be adapted.

For example, you can easily create an installation script/folder for the Orwell fork of Dev-C++ using the source files folder (after creating shortcuts). But, running a system installation using the .exe helps to do things including setting file associates in the registry.

In the `Deploy-ApplicationName.ps1` script, there are already code sections to do things like uninstall target MSI, EXE applications. These code sections are currently commented out, and need to be reviewed/edited before uncommenting for use in your script (if they are needed).

## Steps to Create a User Installation PSADT Folder

1. Decide on an application name. This name will be used for all directories containing source files on a machine’s local filesystem. This name should be synchronous with the source file directory name, contained in the `./Files` directory of the PSADT folder.
2. Change the `ApplicationName` directory, and `Deploy-ApplicationName.ps1` files to fit the application you are working on.

Below is an example of the directory structure for a ‘Dev-C++’ PSADT installation.

![Directory structure for Dev-C++ PSADT Installation](image.jpg)

### Edit `Deploy-ApplicationName.ps1`

Use CTRL+F to replace necessary values in the script:

- `(($appname$))`: Replace with the same application name used for your folders and `deploy-application.ps1` script.
- `(($exe$))`: Replace with a comma-separated list of processes that should be closed down before installation. Ex: ‘chrome,edge’ would close the chrome and edge processes.
- `(($sourcefolder$))`: Folder where source files will be copied to, on local filesystem. Files will be copied from here to users or public directories.
- `(($installation-type$))`: Replace with ‘public’ or ‘private’ to set the `$INSTALL_TYPE` variable.

### Edit the `USERINSTALL.PS1` File

This file is contained in the `./Files` directory of the framework PSADT folder. Use CTRL+F to replace necessary values in the script:

- `(($appname$))`: Replace with the same application name used for your folders and `deploy-application.ps1` script.
- `(($sourcefolder$))`: Folder where source files will be copied to, on local filesystem. Files will be copied from here to users or public directories.
- `(($startmenushortcut$))`: Absolute path to where the start menu shortcut will be located on local computer, ex: `C:\Program Files (x86)\Dev-C++\Dev-C++.lnk`. Should follow the format: `(($sourcefolder$))\(($appname$))\(($appname$)).lnk`. Start menu shortcut should target: `C:\Users\%username%\(($appname$))\application-exe.exe`. Shortcuts are copied to: `C:\Users\%username%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\(($appname$)).lnk`
- `(($desktopshortcut$))`: Absolute path to where the desktop shortcut will be located on local computer, ex: `C:\Users\Public\Desktop\Dev-C++.lnk`. Should follow the format: `C:\Users\Public\Desktop\(($appname$)).lnk`. The public shortcut should be located in the 'PUBLICINSTALL' directory at the base of the source file directory, in the script folder. Public shortcut should target: `C:\Users\Public\(($appname$))\(($appname$)).lnk`.

### Create a ‘PublicInstall’ Directory

This directory should be inside the `ApplicationName/Files/ApplicationName` directory. This is the directory that will contain the public desktop shortcut.

### Make Sure Source Files Contain .ico File for Application Shortcuts

Make sure that your source file directory contains an .ico file that can be referenced by the shortcuts. If you need to create an .ico file, you can find a .png/.jpg picture that you’d like to use and run it through this function:

[ConvertTo-Icon.ps1](https://www.powershellgallery.com/packages/RoughDraft/0.1/Content/ConvertTo-Icon.ps1)

### Use the PSADT Powershell Module to Generate Public and Private Shortcuts

To install the PSADT Powershell module on an internet-connected Windows machine, follow the instructions provided.

### Walkthrough of Create Public/Private Shortcuts for Dev-C++ Installation

Change directory to your `ApplicationName` (Dev-C++ in this case) directory that contains the `Deploy-ApplicationName.ps1` / `Deploy-Dev-C++.ps1` script.

Command for public shortcut creation (targets application .exe stored in application folder on in public user’s folder):

```powershell
New-ShortCut -Path "./Files/Dev-C++/PublicInstall/Dev-C++.lnk" -TargetPath "C:\Program Files (x86)\Dev-C++\Dev-C++.exe" -IconLocation "C:\Program Files (x86)\Dev-C++\Dev-C++.lnk" -Description "Dev-C++"
```

Command for private shortcut creation (uses the `%USERNAME%` batch variable to target correct/current user’s application files/etc.):

```powershell
New-ShortCut -Path "C:\Users\%USERNAME%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Dev-C++.lnk" -TargetPath "C:\Users\%USERNAME%\Dev-C++\Dev-C++.exe" -IconLocation "C:\Program Files (x86)\Dev-C++\Dev-C++.lnk" -Description "Dev-C++"
```

Parameter explanations for `New-Shortcut`:

- `Path`: Output path for the shortcut created by the command
- `TargetPath`: Executable/application that the shortcut will target, after the installation script has been run on machine.
- `IconLocation`: Absolute/relative path to icon location. This should be the icon’s location in the source file directory, ex: `C:\Program Files (x86)\Dev-C++\Dev-C++.lnk`.
- `Description`: Description property of the shortcut

[PSADT Function Reference](https://allnewandimproved.psappdeploytoolkit.com/functions/)

After the installation script/folder is completed, run installations or uninstallations using these commands:

```powershell
Powershell.exe -ExecutionPolicy Bypass ./Deploy-ApplicationName.ps1 -Deploymenttype ‘Install’ -Deploymode ‘silent’
```
