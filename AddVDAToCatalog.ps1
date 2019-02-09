<#
   
.SYNOPSIS
    This script will add a machine to a catalog

.DESCRIPTION
    Once you have installed XenDesktop, have a site and a machine catalog, add new VDAs to that catalog.

.Parameter MachineName
    Specify the name of the machine to create (in the form of 'domain\machine').

.Parameter CatalogUid
    The Catalog to which this machine will belong.
#>

Param(
    [string]$MachineName,
    #[string]$CatalogUid,
    [String]$CatalogName,
    [string]$DeliveryGroupName,
    [string]$domain
)

Add-PSSnapin Citrix.*

# Find Catalog Uid
$CatalogUid = Get-BrokerCatalog | Where-Object {$_.Name -eq $CatalogName} | Select Uid

#Add Machine to Catalog
New-BrokerMachine -MachineName $MachineName -CatalogUid $CatalogUid.Uid

# Find Delivery Group Uid
#$DeliveryGroupId = Get-brokerdesktopgroup | Where-Object {$_.Name -eq $DeliveryGroupName}

#Add Machine to Delivery Group
Add-BrokerMachine "$domain\$MachineName" -DesktopGroup "DeliveryGroupName"