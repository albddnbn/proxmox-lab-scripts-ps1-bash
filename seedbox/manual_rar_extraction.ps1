<#
	.SYNOPSIS
		Extracts .rar files from a given directory and removes the .rar files after extraction.
	
	.DESCRIPTION
		Can be used for manual extraction if your automated extraction for seedbox is having issues or not setup.
#>
param(
	[ValidateScript({
			Test-Path $_ -PathType 'Container'
		})]
	[string]$TargetPath
)

## Check for unrar path
if (Test-Path "C:\Program Files\WinRAR\unRAR.exe" -ErrorAction SilentlyContinue) {
	Write-Host "WinRAR installed." -foregroundcolor green
	$unrar_exe = "C:\Program Files\WinRAR\unRAR.exe"
}
else {
	Write-Host "You have to install WinRAR, please!" -Foregroundcolor Red
	exit
}

## Get .rar files from targetpath
$rar_files = Get-ChildItem -Path "$TargetPath" -Include *.rar -File -Recurse -ErrorAction SilentlyContinue
if (-not $rar_files) {
	Write-Host "No .rar files found in $TargetPath, moving on." -foregroundcolor yellow
	return
}

## Write statement to terminal:
Write-Host "Found $($rar_files.count) .rar files in $TargetPath, extracting and overwriting any existing extracted media." -foregroundcolor green

$rar_files | % {
	&$unrar_exe x -o- "$($_.fullname)" "$($_.directoryname)"
	Write-Host "Finished extracting $($_.directoryname)." -Foregroundcolor Green

	## Remove rar file
	Remove-Item -Path "$($_.fullname)" -Force
	## Remove .r00 - r100 files
	Get-ChildItem -Path "." -File | Where-Object { $_.Extension -match ".r\d{2,3}" } | Remove-Item
}