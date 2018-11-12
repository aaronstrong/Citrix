<#   
    
Copyright © 2014-2016 Citrix Systems, Inc. All rights reserved.

.SYNOPSIS
Install one or more XenDesktop components

.DESCRIPTION
This script will install the specified XenDesktop components

.PARAMETER IsoPath
Path to the XenDesktop ISO

.PARAMETER Components
Comma separated list of XenDesktop Components to install. 
Valid values: controller,desktopstudio,desktopdirector,licenseserver,storefront

.PARAMETER NoSql
Enter "true" if SQLEXPRESS is NOT to be installed (default is that SQLEXPRESS will be installed on this server). Prevents installation of SQL Server Express on the
server where you are installing the controller. This has no effect on the install of SQL Server Express LocalDB used for Local Host Cache.

#>

Param (
    [Parameter(Mandatory=$true)]
    [string]$IsoPath,
    [string]$Components,
    [string]$NoSql = "false"
)


$ErrorActionPreference = "Stop"
try {  
    
    $drive = (Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop | Get-Volume).DriveLetter + ":" 
    if ($Components) {
   
        $installargs = "/components $Components /quiet /configure_firewall /noreboot"
        if ($NoSql -eq "true") {
            $installargs += " /nosql"
        }
        $installer = Join-Path -Path $drive -ChildPath "\x64\XenDesktop Setup\XenDesktopServerSetup.exe"

	    $proc = Start-Process -FilePath $installer -ArgumentList $installargs -Wait -NoNewWindow -LoadUserProfile -PassThru
        if ($proc.ExitCode -eq 3) {
            return "reboot required"
        } elseif ($proc.ExitCode -ne 0) {
            throw "$installer $installargs failed: error code $($proc.ExitCode)"
        }
    }

} catch {
    $Error[0]
    exit 1
} finally {
    if (Test-Path $IsoPath) {
        Dismount-DiskImage -ImagePath $IsoPath
    }
}