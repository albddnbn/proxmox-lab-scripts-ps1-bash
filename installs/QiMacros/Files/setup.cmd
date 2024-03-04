@echo off
@rem
@rem Installer for qimacros for office 2010
@rem Updated script - lmarlin - 2019.1.11
@rem
@rem
@rem



@date /T >> "%SYSTEMDRIVE%\maint\qimacros-rc.txt"
@time /T >> "%SYSTEMDRIVE%\maint\qimacros-rc.txt"

@rem Old installer
@rem start /wait setup.exe /S


@rem Student 2017 - unlicensed version...
start /wait QIMacros-Student.exe /S



@time /T >> "%SYSTEMDRIVE%\maint\qimacros-rc.txt"
