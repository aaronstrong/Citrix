<#

.SYNOPSIS
    This script will install Citrix VDA.

.DESCRIPTION
    This script will install Citrix VDA.
	
.PARAMETER Components
	Comma-separated list of components to install or remove. Valid values are
	- VDA
	- PLUGINS
	
.PARAMETER Controllers
	Space-separated FQDNs of Controllers with which the VDA can communicate, enclosed in quotation marks.



#>

Param (
    [Parameter(Mandatory=$true)]
    [string]$IsoPath,
    [string]$Components,
	[string]$Controllers
)


$ErrorActionPreference = "Stop"
try {  
    
    $drive = (Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop | Get-Volume).DriveLetter + ":" 
    if ($Components) {
   
        $installargs = "/components $Components /controllers $Controllers /enable_hdx_ports /enable_real_time_transport /enable_remote_assistance"
        if ($NoSql -eq "true") {
            $installargs += " /nosql"
        }
        $installer = Join-Path -Path $drive -ChildPath "\x64\XenDesktop Setup\XenDesktopVDASetup.exe"
		
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
