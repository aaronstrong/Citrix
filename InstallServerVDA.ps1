<#
   
.SYNOPSIS
    This script will install the Citrix XenDesktop Server VDA.

.DESCRIPTION
    This script will install Citrix VDA.

.Parameter Components
    To install the VDA but not Citrix Receiver, specify /components vda

.Parameter Controllers
    Fully Qualified Domain Names (FQDNs) of Controllers with which the VDA can communicate, enclosed in quotation marks.

.Parameter IsoPath
    The path to the ISO

#>
Param (
	[string]$IsoPath,
    [ValidateSet("VDA","Plugins")]
	[string]$components = "VDA",
	[string]$controllers

)

#Add-PSSnapin -Name Citrix.*

try {
	
	$drive = (Mount-diskimage -ImagePath $IsoPath -PassThru -ErrorAction Stop | Get-Volume).DriveLetter + ":" 
    if ($components) {
	
		$installargs = "/controllers $controllers /noreboot /quiet /components VDA,plugins /masterimage /baseimage /enable_remote_assistance /enable_hdx_ports /enable_remote_assistance /enable_hdx_udp_ports /enable_real_time_transport /optimize /controllers $controllers"
        #$installargs = "/Components $components /controllers $controllers /NOREBOOT /QUIET /ENABLE_HDX_PORTS /ENABLE_REAL_TIME_TRANSPORT /ENABLE_HDX_UDP_PORTS /ENABLE_REMOTE_ASSISTANCE"
		
		$installer = Join-Path -Path $drive -childpath	"\x64\XenDesktop Setup\XenDesktopVDASetup.exe"

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