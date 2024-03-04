Script source: https://silentinstallhq.com/#open

script will try to use cleanzoom.exe if it's in the Files folder, if not it will use toolkit functions.

9-26-2023 - may need to make an html file for logging into zoom, or open zoom for the user if theyre logged in.

CleanZoom: https://support.zoom.us/hc/en-us/articles/201362983-Uninstalling-and-reinstalling-the-Zoom-application

Folder structure:
│   Deploy-Zoom.ps1
│   Deploy-Zoom.ps1.old
│   original.ps1
│   readme.txt
│
├───AppDeployToolkit
│       AppDeployToolkitBanner.png
│       AppDeployToolkitConfig.xml
│       AppDeployToolkitExtensions.ps1
│       AppDeployToolkitHelp.ps1
│       AppDeployToolkitLogo.ico
│       AppDeployToolkitLogo.png
│       AppDeployToolkitMain.cs
│       AppDeployToolkitMain.ps1
│
└───Files
    │   CleanZoom.exe
    │
    ├───x64
    │       ZoomInstallerFull.msi
    │
    └───x86
            ZoomInstallerFull-x86.msi
