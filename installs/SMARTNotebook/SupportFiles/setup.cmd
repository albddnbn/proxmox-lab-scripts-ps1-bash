@echo off
@rem
@rem Smartboard software Install 
@rem
@rem
@rem Joe Shear - 7/31/2008
@rem ctribo - minor edits and fixes 6/2/2011
@rem lmarlin - SMARTTech installation - 7/26/2013
@rem lmarlin - SmartTech update to v 14.2 w/ drivers - 9/14/2014
@rem lmarlin - SmartTech update to v 15.0.545.0 w/o drivers and ink - 6/17/2015
@rem lmarlin - SmartTech update to v 15.1.352.0 w/o drivers and ink - 2015.09.14
@rem lmarlin - SmartTech update to v. 16.0.648.0 w/o drivers and ink - 2016.07.28
@rem lmarlin - SMART Learning Suite v. 16.1.527.0 w/o driver and ink - 2016.08.30
@rem lmarlin - SMART Learning Suite v. 16.2. w/o driver and ink - 2017.05.02
@rem lmarlin - SMART Learning Suite v. 17.0. w/o driver and ink - 2017.05.03

@date /T >> "%SYSTEMDRIVE%\maint\smarttechsoftware-rc.txt"
@time /T >> "%SYSTEMDRIVE%\maint\smarttechsoftware-rc.txt"


@rem Install SMART Notebook software
start /wait msiexec /i "source\SMARTLearningSuite.msi" TRANSFORMS=source\Offices.mst /qn REBOOT=REALLYSUPPRESS


@time /T >> "%SYSTEMDRIVE%\maint\smarttechsoftware-rc.txt"

