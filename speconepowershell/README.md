# speconepowershell

## Some useful PowerShell functions from: <a href="https://github.com/albddnbn/PSTerminalMenu">https://github.com/albddnbn/PSTerminalMenu</a>, in .psm1 form

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Usage](#usage)
4. [Contributing](#contributing)
5. [License](#license)

## Introduction <a name="introduction"></a>

speconepowershell is mostly a collection of functions that can gather information about remote computers, send/retrieve files, perform routine maintenance/cleanup of filesystems, and a few other tasks. I use some of these functions on a daily basis as an IT Support Specialist I. I hope they come in handy for others as well, please let me know if you have any ideas for improvements.

## Installation <a name="installation"></a>

```powershell
Install-Module speconepowershell
```

## Usage <a name="usage"></a>

Examples of how to run some of the functions:

### Get-ComputerDetails

Target all computers with hostnames starting with t-client-, and gather basic computer details from them including: Manufacturer, Model, Current User, Windows Build, BIOS Version, BIOS Release Date, and Total RAM from target machine(s). Attempts to create a .csv and .xlsx report file if anything other than 'n' is supplied for the $OutputFile parameter.

```powershell
Get-ComputerDetails -TargetComputer 't-client-' -Outputfile 'n'

## Target single hostname:
Get-ComputerDetails -TargetComputer 't-client-12' -Outputfile 't-client-12-details'

## Path to .txt file containing one hostname per line:
'C:\users\public\computers.txt' | Get-ComputerDetails -Outputfile 'n'
't-client-' | Get-ComputerDetails -Outputfile 'DetailsThruPipeline'
```

### Scan-ForApporFilepath

### Clear-CorruptProfiles

### Ping-TestReport

## Contributing <a name="contributing"></a>

Information about how others can contribute to your project.

## License <a name="license"></a>

Information about the license.
