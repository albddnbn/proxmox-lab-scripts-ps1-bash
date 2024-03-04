Steps to create deployment script:

1. Install software using existing method (batch file MDT scripts, etc.)
    a. run command to get  app uninstallstring, displayname, publisher for all software that was installed
    b. copy output to a txt file in this folder

2. Run the installed software, observe running processes so you know which ones to shut down before install/uninstall.

3. Figure out the correct silent install/uninstall switches, fill them into the deployment script.