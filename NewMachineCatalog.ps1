<#
    
.SYNOPSIS
    This script will create a XenDesktop machine catalog.

.DESCRIPTION
    Once you have installed XenDesktop, have a site, create a machine cataloge this script.

.Parameter Name
    Specifies a name for the catalog. Each catalog within a site must have a unique name.

.Parameter Description
    A description for the catalog.

.Parameter AllocationType
    Specifies how machines in the catalog are assigned to users. Values can be:Static,Permanent,Random
    Static are permanently assigned to a user.
    Permanent eqivalent to Static.
    Random are picked at random and temporarily assigned to a user.

.Parameter ProvisionType    
    Specifies the ProvisioningType for the catalog. Values can be:
    o Manual - No provisioning.
    o PVS - Machine provisioned by PVS (machine may be physical, blade, VM,...).
    o MCS - Machine provisioned by MCS (machine must be VM).

.Parameter SessionSupport
    Specifies whether machines in the catalog are single or multi-session capable. Values can be:
    o SingleSession - Single-session only machine.
    o MultiSession - Multi-session capable machine.

.Parameter PersistentUserChanges
    Specifies how user changes are persisted on machines in the catalog. Possible values are:
    o OnLocal: User changes are stored on the machine's local storage.
    o Discard: User changes are discarded.
    o OnPvd: User changes are stored on the user's personal vDisk.


#>

Param (
    [string]$name,
    [string]$description,
    [ValidateSet("Permanent","Random")]
    [string]$allocationType,
    [ValidateSet("manual","pvs","mcs")]
    [string]$provisionType,
    $machinesArePhysical = "true",
    [ValidateSet("OnLocal","Discard","OnPvD")]
    [string]$persistUserChanges,
    [ValidateSet("SingleSession","MultiSession")]
    [string]$sessionSupport,
    [ValidateSet("random","static")]
    [string]$type,
    $IsRemotePc = 0,
    [ValidateSet("L7_9","L7_6","L7","L5")]
    [string]$minimumFunctionalLevel
)
Add-PSSnapin -Name Citrix.*
#Import-Module Citrix.XenDesktop.Admin-

New-BrokerCatalog  -Name $name -Description $description -AllocationType $allocationType -ProvisioningType $provisionType -PersistUserChanges $persistUserChanges -SessionSupport $sessionSupport -MachinesArePhysical $true #-MinimumFunctionalLevel $minimumFunctionalLevel