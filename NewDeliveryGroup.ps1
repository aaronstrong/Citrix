<#
   
.SYNOPSIS
    This script will create a XenDesktop Delivery Group.

.DESCRIPTION
    Once you have installed XenDesktop, have a site and a machine cataloge, create a Delivery Group using this script.

.Parameter Name
    The name of the new broker desktop group.

.Parameter DesktopKind
    The kind of desktops this group will hold. Valid values are Private and Shared.

#>

Param(
    [string]$Name,
    [ValidateSet("Private","Shared")]
    [string]$DesktopKind
)

Add-PSSnapin -Name Citrix.*
New-BrokerDesktopGroup -Name $Name -DesktopKind $DesktopKind -TurnOnAddedMachine $true