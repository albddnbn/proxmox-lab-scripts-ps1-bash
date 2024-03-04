The google .msi must be in the Files directory. script will try for 64 bit first

right now - it doesn't take into account exe, but here are some links that may help:
https://silentinstallhq.com/google-chrome-exe-silent-install-how-to-guide/

12-7-23 - alot more can probably be done to tailor user preferences, policies are going to probably be set through Google Admin console or Group policy

silent install:

$result = (Start-Process msiexec -ArgumentList "/i Files\GoogleChromeStandaloneEnterprise.msi /qn" -Wait -Passthru).ExitCode
if ($result -eq 0) {
    Write-Host "Google Chrome installed successfully"
} else {
    Write-Host "Google Chrome installation failed"
}