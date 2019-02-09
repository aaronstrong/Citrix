<#
    Copyright © 2013-2015 Citrix Systems, Inc. All rights reserved.

.SYNOPSIS
    This script will create a XenDesktop database and site.

.DESCRIPTION
    Once you have installed XenDesktop, create a database and site using this script.

#>
Param (
	[string]$AdministratorName,
    [string]$DomainName,
    [string]$LicenseServer,
    [int]$LicenseServerPort = 27000,
    [string]$SiteName = "CloudSite",
    [string]$DatabaseServer = ".\SQLEXPRESS"
)

#
# Seeing cases of Citrix Services failing to start - this attempts to work around the problem (see CAM-7807 /DNA-22255)
#
function Check-Services {
    $serviceNames = @("CitrixAppLibrary", "CitrixADIdentityService")

    foreach ($serviceName in $serviceNames) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            if ($service.Status -ne "Running") {
                "[Info] $serviceName is $($service.Status) - attempting to start it"
	            Set-Service -Name $serviceName -Status Running
            }
        } else {
            "[Warning] $serviceName not found (ignoring)"
        }
    }
}

function Set-LicenseServer {
    Param (
        [string]$LSAddress,
        [int]$LSPort 
    )
    Set-XDLicensing -LicenseServerAddress $LSAddress -LicenseServerPort $LSPort

    $location = Get-LicLocation  -AddressType 'WSL' -LicenseServerAddress $LSAddress -LicenseServerPort $LSPort
    $certificate = Get-LicCertificate  -AdminAddress $location
    Set-ConfigSiteMetadata -Name 'CertificateHash' -Value $certificate.CertHash
}

$ErrorActionPreference = "Stop"
try {
    Check-Services
    if ((Get-PSSnapin -Name Citrix.* -ErrorAction SilentlyContinue) -eq $null) {
        Add-PSSnapin -Name Citrix.*
    }
    Import-Module Citrix.XenDesktop.Admin

    New-XDDatabase -AllDefaultDatabases -DatabaseServer $DatabaseServer -SiteName $SiteName  

    New-XDSite -AllDefaultDatabases -DatabaseServer $DatabaseServer -SiteName $SiteName

    if (-not [string]::IsNullOrEmpty($AdministratorName)) {
        
        if ((-not $AdministratorName.Contains('@')) -and (-not [string]::IsNullOrEmpty($DomainName))) {
            $AdministratorName = "${AdministratorName}@$DomainName"
        }
    
        $admin = Get-AdminAdministrator -Name $AdministratorName  -ErrorAction SilentlyContinue
        if ($admin -eq $null) {
            $admin = New-AdminAdministrator -Name $AdministratorName
            Add-AdminRight -Administrator $AdministratorName -All -Role 'Full Administrator'   
        } 
    }

    # Failure to locate license server is not fatal, so do this last and continue if it fails.
    $ErrorActionPreference = "Continue"
    if (-not [string]::IsNullorEmpty($LicenseServer)) {
        Set-LicenseServer $LicenseServer $LicenseServerPort
    }
} catch {
    $_
    exit 1
}