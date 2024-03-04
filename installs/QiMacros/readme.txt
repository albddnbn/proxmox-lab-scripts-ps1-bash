the uninstaller.exe still left QiMacros tab visible in Excel.
QiMacros was never visible through Apps/Features, haven't been able to find any uninstall app key for it in registry yet.

QiMacros are visible through apps/featuers if you use the setup.exe to install

/unwise32.exe /s install.log might've worked.

Going through GUI in Excel, enabling Developer Tab, then adding this file: Files\setup\QIMACROS2010MENU.XLAM
adds in the macro option to toolbar.



12-23-2023

unwise.exe /s install.log removes the QiMacros tab from Excel.

Folders:
C:\QiMacros
C:\XLStart

Files:
C:\unwise.exe if exists

need to be deleted.

Needs to be removed:
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\The QI Macros for Excel]
