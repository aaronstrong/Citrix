 <#
    
Copyright © 2015-2016 Citrix Systems, Inc. All rights reserved.

.SYNOPSIS
Create a Storefront site. For simplicity the script assumes there are no existing sites.

.DESCRIPTION
This script will create and configure a Storefront site. It should be run on the Storefront server.

.PARAMETER XenDesktopControllers
Comma separated list of XenDesktop Delivery Controller names which may be simple names (e.g. XDC1, XDC2) or fully 
qualified domain names. If any simple names are provided the optional domain name will be used to build an FQDN

.PARAMETER DomainName
Fully qualified named of the DNS domain for the XenDesktop Delivery Controllers

.PARAMETER BaseUrl
Base URL for the Storefront services (e.g. http://storefront.domain.example/)

.PARAMETER SiteId
IIS Site Id

.PARAMETER Farmtype
Type of Farm. Valid values are "XenDesktop","XenApp","AppController","VDIinaBox".

.PARAMETER StoreVirtualPath
Virtual path to the store

.PARAMETER LoadbalanceServers
Whether to load balance servers (default false)

.PARAMETER Port
Port to listen on. Default 80

.PARAMETER SSLRelayPort
Default 443

.PARAMETER TransportType
Type of transport to use. Default HTTP


#>
 
[CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)]
    [string]$XenDesktopControllers,
    [string]$DomainName,
    [Parameter(Mandatory=$true)]
    [string]$BaseUrl,
    [long]$SiteId = 1,
    [ValidateSet("XenDesktop","XenApp","AppController","VDIinaBox")]
    [string]$Farmtype = "XenDesktop",
    [string]$StoreVirtualPath = "/Citrix/Store",
    [bool]$LoadbalanceServers = $false,
    [int]$Port = 80,
    [int]$SSLRelayPort = 443,
    [ValidateSet("HTTP","HTTPS","SSL")]
    [string]$TransportType = "HTTP"   
  )

 # Create a list of servers from a comma separated string
function Create-ServerList {
    Param (       
        $Servers,
        $Domain
    )
    $serverList = @()
    foreach ($server in ($Servers -split ',')) {
        if ($Domain -and (-not $Server.Contains('.'))) {
           $server = "${server}.$Domain"
        }
        $serverList += $server
    }
    return ,$serverList 
}

$ErrorActionPreference = 'Stop'
try {  
    # Determine the Authentication and Receiver virtual path to use based on the Store
    $authenticationVirtualPath = "$($StoreVirtualPath.TrimEnd('/'))Auth"
    $receiverVirtualPath = "$($StoreVirtualPath.TrimEnd('/'))Web"

    # Create list of delivery controllers
    $serverList = Create-ServerList $XenDesktopControllers $DomainName

    #
    # From Storefront 3.5 (shipped with XenDesktop 7.7) there is a new SDK for Storefront so use that for preference.
    # Note that the old scripts will fail on Windows Server 2016
    #
    if (Get-Module -ListAvailable -Name Citrix.Storefront) {
        "Using Storefront module"

        $ReportErrorShowStackTrace = $true
        $ReportErrorShowInnerException = $true
        # Import StoreFront modules. Required for versions of PowerShell earlier than 3.0 that do not support autoloading
        Import-Module Citrix.StoreFront
        Import-Module Citrix.StoreFront.Stores
        Import-Module Citrix.StoreFront.Authentication
        Import-Module Citrix.StoreFront.WebReceiver
        
        # Create Storefront deployment
        Add-STFDeployment -HostBaseUrl $BaseUrl -SiteId $SiteId -Confirm:$false

        $authentication = Add-STFAuthenticationService $authenticationVirtualPath

        $store = Add-STFStoreService -VirtualPath $StoreVirtualPath `
                                     -AuthenticationService $authentication `
                                     -FarmName $Farmtype `
                                     -FarmType $Farmtype `
                                     -Servers $serverList `
                                     -LoadBalance $LoadbalanceServers `
                                     -Port $Port `
                                     -SSLRelayPort $SSLRelayPort `
                                     -TransportType $TransportType

        $receiver = Add-STFWebReceiverService -VirtualPath $receiverVirtualPath -StoreService $store
        
        # Determine if PNA is configured for the Store service
        $storePnaSettings = Get-STFStorePna -StoreService $store

        if (-not $storePnaSettings.PnaEnabled) {
            # Enable XenApp services on the Store and make it the default for this server
            Enable-STFStorePna -StoreService $store -AllowUserPasswordChange -DefaultPnaService
        }

    } else {
        "No Storefront module: using legacy Storefront PS scripts"
        $RegProp = Get-ItemProperty -Path HKLM:\SOFTWARE\Citrix\DeliveryServices -Name InstallDir
        $DSScriptDir = $RegProp.InstallDir+"\Scripts"

        try {
            Push-Location $DSScriptDir
            & .\ImportModules.ps1
        }
        finally {
            Pop-Location
        }
       
        Set-DSInitialConfiguration -hostBaseUrl $BaseUrl `
					       -farmName $Farmtype `
					       -farmType $Farmtype `
					       -servers $serverList `
					       -port $Port `
					       -transportType $TransportType `
					       -sslRelayPort $SSLRelayPort `
					       -loadBalance $LoadbalanceServers `
					       -AuthenticationVirtualPath $authenticationVirtualPath `
					       -StoreVirtualPath $StoreVirtualPath `
					       -WebReceiverVirtualPath $receiverVirtualPath


        ClusterConfigurationModule\Start-DSClusterJoinService
    
        $serviceName = "CitrixClusterService"

        $service = Get-Service -Name $serviceName

        if ($service.Status -ne "Running") {
	        Set-Service -Name $serviceName -StartupType Manual
	        Set-Service -Name $serviceName -Status Running
        }
    }

} catch {
    $error[0]
    $error[0].ScriptStackTrace
    exit 1
}