<#   
    
Copyright © 2015-2017 Citrix Systems, Inc. All rights reserved.

.SYNOPSIS
Install XenDesktop VDA

.DESCRIPTION
This script will install the specified XenDesktop VDA.

.PARAMETER IsoPath
Path to the XenDesktop ISO file

.PARAMETER Controllers
Comma separated list of XenDesktop Controllers. This may be a list of FQDNs, or you
may supply a list of simple computer names and specify the domain as a separate parameter

.PARAMETER ServerVdi
Specify "yes" for server VDI, "no" for a Server VDA install

.PARAMETER Domain
Optional domain name to be used as a suffix for Controller names

#>

Param (
    [Parameter(Mandatory=$true)]
    [string]$IsoPath,
    [Parameter(Mandatory=$true)]
    $Controllers,
    [ValidateSet("yes","no")]
    $ServerVdi = "no",
    [string]$Domain
)

$ErrorActionPreference = "Stop"

try {
    $drive = (Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop | Get-Volume).DriveLetter + ":" 
    foreach ($Controller in ($Controllers -split ',')) {
        if ($Domain -and (-not $Controller.Contains('.'))) {
           $Controller = "${Controller}.$Domain"
        }
        $ControllerList = "$ControllerList $Controller"
    }
    $ControllerList = $ControllerList.TrimStart()
       
    $options = "/components vda,plugins /enable_hdx_ports /optimize /masterimage /baseimage /enable_remote_assistance"
    if ($ServerVdi -eq "yes") {
        $options = "/servervdi /enable_hdx_ports /enable_real_time_transport"
        
    }

    $installargs = "/controllers ""$ControllerList"" $options /quiet /noreboot /logpath C:\citrix "
    $installer = Join-Path -Path $drive -ChildPath "x64\XenDesktop Setup\XenDesktopVdaSetup.exe"
   
    $proc = Start-Process -FilePath $installer -ArgumentList $installargs -Wait -NoNewWindow -LoadUserProfile -PassThru
    if ($proc.ExitCode -eq 3) {
        return "reboot required"
    } elseif ($proc.ExitCode -ne 0) {
        throw "$installer $installargs failed: error code $($proc.ExitCode)"
    }
}
catch {
    "Error attempting to install VDA"
    $Error[0]
    exit 1
} finally {
    if (Test-Path $IsoPath) {
        Dismount-DiskImage -ImagePath $IsoPath
    }
}