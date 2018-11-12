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
    [string]$LicenseServer = "localhost",
    [int]$LicenseServerPort = 27000,
    [string]$SiteName = "CloudSite",
    #[string]$DatabaseServer = ".\SQLEXPRESS",
    [string]$XD7Site = "CloudeSite",
    [string]$DatabaseServer = "localhost\SQLEXPRESS",
    [string]$DatabaseName_Site = "CloudeSiteSite",
    [string]$DatabaseName_Logging = "CloudeSiteLogging",
    [string]$DatabaseName_Monitor = "CloudeSiteMonitoring",
    #[string]$FullAdminGroup = "Domain\FullAdminGroup",
    [string]$DatabaseUser,
    [parameter(Mandatory=$true,ParameterSetName="DatabasePassword")][ValidateNotNullOrEmpty()]$DatabasePassword,
    [string]$LicenseServer_LicensingModel = "UserDevice",
    [string]$LicenseServer_ProductCode = "XDT",
    [string]$LicenseServer_ProductEdition = "PLT"
)


$ErrorActionPreference = "Stop"

try {
    <#
    Check-Services
    if ((Get-PSSnapin -Name Citrix.* -ErrorAction SilentlyContinue) -eq $null) {
        Add-PSSnapin -Name Citrix.*
    }
    #>
    Add-PSSnapin -Name Citrix.*
    Import-Module Citrix.XenDesktop.Admin

    $userPassword = ConvertTo-SecureString -String $DatabasePassword -AsPlainText -Force
    
    $Database_CredObject = New-Object System.Management.Automation.PSCredential("ctxlab\Administrator",$userPassword)
    

    #New-XDDatabase -AllDefaultDatabases -DatabaseServer $DatabaseServer -SiteName $SiteName  

    #New-XDSite -AllDefaultDatabases -DatabaseServer $DatabaseServer -SiteName $SiteName
    
    # Create Databases
    New-XDDatabase -AdminAddress $env:COMPUTERNAME -SiteName $XD7Site -DataStore Site -DatabaseServer $DatabaseServer -DatabaseName $DatabaseName_Site -DatabaseCredentials $Database_CredObject 
    #New-XDDatabase -AdminAddress $env:COMPUTERNAME -SiteName CloudSite -DataStore Site -DatabaseServer "localhost\SQLExpress" -DatabaseName "CloudSiteSite" -DatabaseCredentials $Database_CredObject 
    New-XDDatabase -AdminAddress $env:COMPUTERNAME -SiteName $XD7Site -DataStore Logging -DatabaseServer $DatabaseServer -DatabaseName $DatabaseName_Logging -DatabaseCredentials $Database_CredObject 
    #New-XDDatabase -AdminAddress $env:COMPUTERNAME -SiteName CloudSite -DataStore Logging -DatabaseServer "localhost\SQLExpress" -DatabaseName "CloudSiteLogging" -DatabaseCredentials $Database_CredObject
    New-XDDatabase -AdminAddress $env:COMPUTERNAME -SiteName $XD7Site -DataStore Monitor -DatabaseServer $DatabaseServer -DatabaseName $DatabaseName_Monitor -DatabaseCredentials $Database_CredObject 
    #New-XDDatabase -AdminAddress $env:COMPUTERNAME -SiteName CloudSite -DataStore Monitor -DatabaseServer "localhost\SQLExpress" -DatabaseName "CloudSiteMonitoring" -DatabaseCredentials $Database_CredObject


    # Create Site

    New-XDSite -DatabaseServer $DatabaseServer -LoggingDatabaseName $DatabaseName_Logging -MonitorDatabaseName $DatabaseName_Monitor -SiteDatabaseName $DatabaseName_Site -SiteName $XD7Site -AdminAddress $env:COMPUTERNAME 

    # ConfigureLicensing and confirm the certificate hash

    Set-XDLicensing -AdminAddress $env:COMPUTERNAME -LicenseServerAddress $LicenseServer -LicenseServerPort $LicenseServerPort
    Set-ConfigSite  -AdminAddress $env:COMPUTERNAME -LicensingModel $LicenseServer_LicensingModel -ProductCode $LicenseServer_ProductCode -ProductEdition $LicenseServer_ProductEdition 
    Set-ConfigSiteMetadata -AdminAddress $env:COMPUTERNAME -Name 'CertificateHash' -Value $(Get-LicCertificate -AdminAddress "https://$LicenseServer").CertHash

    # Add admin group to full admins

    # New-AdminAdministrator -AdminAddress $env:COMPUTERNAME -Name $FullAdminGroup
    # Add-AdminRight -AdminAddress $env:COMPUTERNAME -Administrator $FullAdminGroup -Role 'Full Administrator' -All

    
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

    <#

    # Failure to locate license server is not fatal, so do this last and continue if it fails.
    $ErrorActionPreference = "Continue"
    if (-not [string]::IsNullorEmpty($LicenseServer)) {
        Set-LicenseServer $LicenseServer $LicenseServerPort
    }
    #>
} catch {
    $_
    exit 1
}