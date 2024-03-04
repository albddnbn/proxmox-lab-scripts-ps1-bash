@rem aconant - SMART Learning Suite license renewal - 2021.01.20

@date /T >> "%SYSTEMDRIVE%\maint\smarttechsoftware-rc.txt"
@time /T >> "%SYSTEMDRIVE%\maint\smarttechsoftware-rc.txt"


@rem Set Variables

@rem set SMART_Check="%ProgramFiles(x86)%\SMART Technologies"
@rem set RENEW="%SMART_Check\SMART Activation Wizard"

@rem Check for installed SMART Software and renew product key



@start /wait SMART_Renewal\source\activationwizard.exe --m=15 --v=5 --renewal-mode=product --puid=notebook_14

@time /T >> "%SYSTEMDRIVE%\maint\smarttechsoftware-rc.txt"

