DisplayName: SceneBuilder
UninstallString: MsiExec.exe /X{78D24BD8-91D7-3276-99D2-A17B0FC858D9}
Version: 20.0.0
Publisher: Gluon
InstallLocation: C:\Users\abuddenb_admin\AppData\Local\SceneBuilder\
—————————————————
DisplayName: SceneBuilder
UninstallString: "C:\Users\abuddenb_admin\AppData\Local\SceneBuilder\unins000.exe"
Version: 8.5.0
Publisher: Gluon
InstallLocation: C:\Users\abuddenb_admin\AppData\Local\SceneBuilder\
—————————————————

cleanup of registry may be required before install and after uninstall


The script installs scenebuilder for the admin user running the installation, then copies the scenebuilder files from the user's appdata to public folder.

*Changes made to the config of setup.cmd from mdt:
1. Instead of putting the whole scenebuilder folder on public\desktop, i put that into public\documents, and put a shortcut to the scenebuilder.exe on the public desktop.