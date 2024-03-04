**************************************************************************
* DELL PROPRIETARY INFORMATION
*
* This software contains the intellectual property of Dell Inc. Use of this software and the intellectual property
* contained therein is expressly limited to the terms and conditions of the License Agreement under which it is
* provided by or on behalf of Dell Inc. or its subsidiaries.
*
* Copyright 2020-2023 Dell Inc. or its subsidiaries. All Rights Reserved.
*
* DELL INC. MAKES NO REPRESENTATIONS OR WARRANTIES ABOUT THE SUITABILITY OF THE SOFTWARE,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.
* DELL SHALL NOT BE LIABLE FOR ANY DAMAGES SUFFERED BY LICENSEE AS A RESULT OF USING,
* MODIFYING OR DISTRIBUTING THIS SOFTWARE OR ITS DERIVATIVES.
*
*
*
**************************************************************************
********************************************************************************

DELL COMMAND | UPDATE
VERSION 5.1 README

********************************************************************************

Dell Command | Update is installed as a standalone application on a
business client supported platform to provide a Windows update
experience for systems software released by Dell. This application is
installed locally on the target systems and simplifies BIOS, firmware,
driver, and application update experience on Dell Client Hardware. This
application can also be used to install drivers after the Operating
System and network drivers are installed based on the system identity.

Dell Command | Update is primarily targeted at customers who want to
manage systems on their own. The tool is designed to allow users to
specify their update preferences and apply updates based on the
criticality. Alternatively, end users can use the scheduling option to
keep their system up-to-date with the systems software released by Dell.

********************************************************************************
What's New
********************************************************************************

The features in this release:
   - Added capability to fallback to direct connection in case of proxy connection failures
   - Enhanced algorithm for qualifying updates
   - Enhanced scheduler workflow
   - Enhanced service shutdown process to reduce system shutdown time
   - Enhanced security measures in line with Microsoft's Smart App Control compliance
   - Improved warning messaging in case of proxy authentication failure

********************************************************************************
Constraints/Known Issues
********************************************************************************

The System Password under Settings -> BIOS does not support the double quote (")
character.

The Custom Proxy settings (Settings -> General -> Internet Proxy) is required
when participating in the Dell Command | Update Improvement Program and the
system is using a web proxy which requires authentication.

Custom catalogs are not supported when Dell Command | Update runs on systems
that are enabled with Federal Information Processing Standards (FIPS).

CLI commands will not execute if any DCU app notification is running and the 
user will be notified, “An instance of the application is already running on this system”.
Note: Close any DCU app notification’s popup to continue CLI execution.

********************************************************************************
Hardware and Software Requirements
********************************************************************************

Supported operating systems:
	- Microsoft Windows 11 
	- Microsoft Windows 10  

Operating system requirements:
	- Dell Command | Update requires Microsoft .NET Framework 4.8 (or later) to
	  be installed on the system.

Languages:
	- Arabic
	- Chinese (Simplified, Traditional, Taiwan)
	- Croatian
	- Czech
	- Danish
	- Dutch (Netherlands)
	- English
	- Finnish
	- French
	- German
	- Greek
	- Hebrew
	- Hungarian
	- Italian
	- Japanese
	- Korean
	- Norwegian
	- Polish
	- Portuguese (Portugal, Brazil)
	- Romanian
	- Russian
	- Slovak
	- Slovenian
	- Spanish
	- Swedish
	- Turkish
	- Ukrainian

Supported Systems:
	- Dell Latitude
	- Dell Latitude Rugged
	- Dell Optiplex
	- Dell Precision
	- Dell Venue Pro
	- Dell XPS

For more information on the models and systems that Dell Command | Update
supports, see https://www.dell.com/support

********************************************************************************
Global Support
********************************************************************************

For information on technical support, visit https://www.dell.com/contactus

For information on documentation support, visit https://www.dell.com/support

Information in this document is subject to change without notice.
Copyright (C) 2020-23 Dell Inc. All rights reserved.