<#
   Main.ps1 purpose is to deploy virtual machines for a new Citrix envrionment from VMware
   using an existing template.

   The template needs to be pre-existing.

   The script will prompt and ask how many VMs to create, the IP address for reach
   VM and the function of each VM.

   Once the prompts are complete, the script will then deploy the VMs, change the IP address,
   join the VM to the domain, and change the firewall to allow ICMP.

   Lastly, depending on the Citrix function, that specific Citrix role will be deployed.
#>

# ----- ENVIRONMENT VARIABLES TO MODIFY ---#
# ----- vSphere Information ---#
$vCenterInstance = "192.168.2.200"            # vCenter address
$vCenterUser = "administrator@vsphere.local"  # vCenter Username
$vCenterPass = "VMware1!"                     # vCenter Password
$template = "Windows 2016"                    # Template Name
$dsName = "NVMe"                              # Datastore to put VM
$esxName = "192.168.2.206"                    # Host to put VM

# ------ Local VM Template ---#
$GuestUser = "Administrator"  # Local account for the template
$GuestPwd  = "VMware1!"       # Local account password for the template
$vNicName = "Ethernet0"       # Network Adapter name inside the VM

# ------ Active Directory Domain Information ---#
$domainName = "contoso.local"         # Domain Name (Example: contoso.local)
$domainController = "192.168.110.50"  # Domain Controller address
$domainAccount = "Administrator"      # Domain Account
$domainPassword = "VMware1!"          # Domain Account Password

# ------ ISO Info ---#
$XenDesktopIsoName = "XenApp_and_XenDesktop_7_15_3000.iso"  # Citrix ISO file name
#$XenDesktopIsoPath = "Z:\citrix\xenapp\7.15 LTSR\XenApp and XenDesktop"  # Citrix ISO SMB Share path
$XenDesktopIsoPath = "\\192.168.2.99\isos\Citrix\XenApp\7.15 LTSR\XenApp and XenDesktop"
$tempFolder = "C:\Citrix"  # Temporary folder to copy .ISO and scripts

# ----- Citrix Broker Info ---#
$controllers = "ctx-all.$domainName"

# ----- Citrix StoreFront URL ---#
$baseURL = "http://storefront.$domainName"

# ----- Citrix Machine Catalog Info ---#
$catalogMC = "Server 2016"
$descripMC = "Server 2016"
$allocationType = "Random"
$provisionType = "Manual"
$persistUserChanges = "discard"
$sessionSupport = "MultiSession"
$minimumFunctionalLevel = "L7_9"
$DesktopKind = "Shared"  # Choice of Private or Shared


#### DO NOT EDIT BEYOND HERE ####

cd $PSScriptRoot  # Change directory from which script is running

$StartDTM = (Get-date)

[int] $totalVMs = Read-Host -Prompt "How many servers to create?"

# ------Blank Arrays ---#
$nameVMs = @()
$funcVMs = @()
$staticIP= @()
    
for($i=0; $i -lt $totalVMs; $i++) {
    $a = $i + 1;
    $nameVMs += Read-Host -Prompt "Name of server $a"
}

Write-host ""
Write-Host "Function Options: Select Controller-C, StoreFront-S, Director-D, VDA-V, SQL-Q, All-A" -ForegroundColor Yellow
Write-host ""

foreach($nameVM in $nameVMs){ $funcVMs += Read-Host -Prompt "Function of server $nameVM" }
foreach($nameVM in $nameVMs){ $staticIP += Read-Host -Prompt "Static IP addresss of server $nameVM" }
    

# This section logs on to the defined vCenter instance above
find-module -name vmware.powercli
Connect-VIServer $vCenterInstance  -User $vCenterUser -Password $vCenterPass -WarningAction SilentlyContinue

$ds = Get-Datastore -Name $dsName
$esx = Get-VMHost -Name $esxName

# ----- Check if ISO Exists ---#
if(!(Test-Path -Path "$XenDesktopIsoPath\$XenDesktopIsoName")){
    Write-Host "ISO Path does not exist." -ForegroundColor Red
    Break
}
# ----- Check if VM Template exists ---#
<#
if((get-template -Name "$template") -ne "NULL") { 
    Write-host "Template $template does not exist." -ForegroundColor Red
    break
}
#>
# ---- BUILD THE VMS ----#
for($a=0; $a -lt $totalVMs; $a++) {
    $task = New-VM -Template $template -VMHost $esx -Datastore $ds -Name $nameVMs[$a] -DiskStorageFormat Thin -RunAsync
    
    Wait-Task -Task $task    
    Get-VM -Name $nameVMs[$a] | Start-VM  # Power on VM

    # ---- Wait for computer to come back ---#    
    write-host “Waiting for VM to Start” -ForegroundColor Yellow
    do {
        $vmCheck = get-view -ViewType VirtualMachine -property Name,Guest -Filter @{"name"=$nameVMs[$a]}
        write-host $vmCheck.Guest.GuestOperationsReady
        sleep 3
    } until ( $vmCheck.Guest.GuestOperationsReady -eq ‘False’ )

    # ---- Change IP Address ---- #    
    $hostname = $nameVMs[$a]
    $newIP = $staticIP[$a]

    Write-host "Change VM $hostname IP to $newIP"
    $newGateWay = $newIP.Split(".")[0]+"."+$newIP.Split(".")[1]+"."+$newIP.Split(".")[2]+".1"
    $cmdIP = "netsh interface ipv4 set address name=`"$vNicName`" static $newIP 255.255.255.0 $newGateWay"
    $cmdDNS1 = "netsh interface ipv4 set dns name=`"$vNicName`" static $domainController"
    $cmdDNS2 = "netsh interface ip add dns name=`"$vNicName`" 8.8.8.8 index=2"
 
    $vm = Get-VM $hostname
    Invoke-VMScript -VM $vm -ScriptType Bat -ScriptText $cmdIP  -GuestUser $GuestUser -GuestPassword $GuestPwd | Out-Null
    Invoke-VMScript -VM $vm -ScriptType Bat -ScriptText $cmdDNS1 -GuestUser $GuestUser -GuestPassword $GuestPwd | Out-Null
    Invoke-VMScript -VM $vm -ScriptType Bat -ScriptText $cmdDNS2 -GuestUser $GuestUser -GuestPassword $GuestPwd | Out-Null

    sleep 2

    # ----- Allow ICMP Echo ----- #
    Write-Host "Changing Firewall"
    $cmdFW = "netsh advfirewall firewall add rule name=`"ICMP Allow incoming V4 echo request`" protocol=icmpv4:8,any dir=in action=allow"
    Invoke-VMScript -VM $hostname -ScriptType Bat -ScriptText $cmdFW -GuestUser $GuestUser -GuestPassword $GuestPwd | Out-Null

    sleep 2

    # ----- Rename Computer ----- #
    Write-Host "Changing name of computer to $hostname"
    Invoke-VMScript -VM $hostname -ScriptType Powershell -ScriptText "Rename-Computer -NewName $hostname -Restart" -GuestUser $GuestUser -GuestPassword $GuestPwd | Out-Null

    .\RebootFunction.ps1 -hostname $hostname

    # ---- Join Domain ----- #
    Write-host "Join to domain $domainName"

    $vm = Get-VM $hostname 

 
$cmd = @"
`$domain = "$domainName"
`$password = "$domainPassword" | ConvertTo-SecureString -asPlainText -force;
`$username = "$domainName\$domainAccount";
`$credential = New-Object System.Management.Automation.PSCredential(`$username, `$password);
Add-computer -DomainName `$domain -Credential `$credential
"@
 
    Invoke-VMScript -VM $hostname -ScriptText $cmd -GuestUser $GuestUser -GuestPassword $GuestPwd | Out-Null

    .\RebootFunction.ps1 -hostname $hostname
        
    # ----- Enable AutoAdminLogin --- #
    Write-Host "Enable Autoadmin login" -ForegroundColor Yellow
    Copy-VMGuestFile -Source .\AutoAdminLogon.ps1 -Destination "$tempFolder\AutoAdminLogon.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
    Invoke-VMScript -VM $hostname -ScriptType Powershell -ScriptText "$tempFolder\AutoAdminLogon.ps1 -Switch Enable -UserName $domainName\$domainAccount -Password $domainPassword" -GuestUser $GuestUser -GuestPassword $GuestPwd | Out-Null

    .\RebootFunction.ps1 -hostname $hostname

    # ----- Copy ISO File --- #
    Write-host "Copy ISO File" -ForegroundColor Yellow
    Copy-VMGuestFile -Source .\DownloadXenDesktopIso.ps1 -Destination "$tempFolder\DownloadXenDesktopIso.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
    Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "$tempFolder\DownloadXenDesktopIso.ps1 -FileName $XenDesktopIsoName -Path `"$XenDesktopIsoPath`" -ToFolder $tempFolder\" -GuestUser $GuestUser -GuestPassword $GuestPwd | Out-Null


    # ----- Install .NET --- #
    Write-Host "Install .NET" -ForegroundColor Yellow
    Copy-VMGuestFile -Source .\InstallDotNet.ps1 -Destination "$tempFolder\InstallDotNet.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
    Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "$tempFolder\InstallDotNet.ps1 -IsoPath $tempFolder\$XenDesktopIsoName" -GuestUser $GuestUser -GuestPassword $GuestPwd | Out-Null

    
    # ----- INSTALL CITRIX COMPONENTS ----- #
    switch ($funcVMs){
        # ----- Install Controller Only ---#
        'C'  {
                Write-host "Install Controller Only" 
                Copy-VMGuestFile -Source .\XDInstallComponents.ps1 -Destination "$tempFolder\XDInstallComponents.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "$tempFolder\XDInstallComponents.ps1 -IsoPath `"$tempFolder\$XenDesktopIsoName`" -Components `"controller,desktopstudio`" -NoSQL=`"$false`"" -GuestUser $GuestUser -GuestPassword $GuestPwd | Out-Null

                .\RebootFunction.ps1 -hostname $hostname                    

                Write-Host "Configuring Site"
                Copy-VMGuestFile -Source .\MyNewSiteFunc.ps1  -Destination "$tempFolder\MyNewSiteFunc.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "$tempFolder\MyNewSiteFunc.ps1 -DatabasePassword `"$domainPassword`"" -GuestUser $GuestUser -GuestPassword $GuestPwd

             
             }
        # ----- Install StoreFront Only ---#
        'S'  { 
                Write-host "Configure StoreFront"
                Copy-VMGuestFile -Source .\XDInstallComponents.ps1 -Destination "$tempFolder\XDInstallComponents.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "$tempFolder\XDInstallComponents.ps1 -IsoPath `"$tempFolder\$XenDesktopIsoName`" -Components `"storefront`" -NoSQL=`"$false`"" -GuestUser $GuestUser -GuestPassword $GuestPwd

                .\RebootFunction.ps1 -hostname $hostname

                Copy-VMGuestFile -Source .\SFCreateSite.ps1 -Destination "$tempFolder\SFCreateSite.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "$tempFolder\SFCreateSite.ps1 -XenDesktopControllers $hostname.$domainName -BaseURL http://storefront.$domainName " -GuestUser $GuestUser -GuestPassword $GuestPwd
                
             }
        # ----- Install Single SQL Only ---#
        "Q"  { 
                Write-Host "Install SQL"
                Copy-VMGuestFile -Source .\install_sqlexpress.ps1 -Destination "$tempFolder\install_sqlexpress.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -VM $hostname -ScriptType Powershell -ScriptText "$tempFolder\install_sqlexpress.ps1" -GuestUser $GuestUser -GuestPassword $GuestPwd
             }
        # ----- Install VDA Only ---#
        "V"  {  
                $hostname = get-vm ctx-svda  # Used for testing purposes only
                # --- Install Pre-reqs --- #
                Write-Host "Installing VDA Pre-reqs $hostname" -ForegroundColor Yellow
                Copy-VMGuestFile -Source .\InstallVCplusplus.ps1 -Destination "$tempFolder\InstallVCplusplus.ps1" -vm $hostname -LocalToGuest -GuestUser $domainName\$domainAccount -GuestPassword $domainPassword -force
                Invoke-VMScript -VM $hostname -ScriptType Powershell -ScriptText "$tempFolder\InstallVCplusplus.ps1" -GuestUser $domainName\$domainAccount -GuestPassword $domainPassword | Out-Null

                .\RebootFunction.ps1 -hostname $hostname

                # --- Install VDA ---#
                $hostname = "ctx-svda"
                Write-Host "Install the VDA" -ForegroundColor Yellow
                #Copy-VMGuestFile -Source .\InstallServerVDA.ps1 -Destination "$tempFolder\InstallServerVDA.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
				Copy-VMGuestFile -Source .\InstallVDAServer.ps1 -Destination "$tempFolder\InstallServerVDA.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                #Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "$tempFolder\InstallServerVDA.ps1 -IsoPath $tempFolder\$XenDesktopIsoName -controllers $controllers -ServerVdi yes -Domain $domainName" -GuestUser $GuestUser -GuestPassword $GuestPwd
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\InstallServerVDA.ps1 -IsoPath C:\Citrix\XenApp_and_XenDesktop_7_15_3000.iso -controllers `"ctx-all`" -Domain `"contoso.local`"" -GuestUser $GuestUser -GuestPassword $GuestPwd

                .\RebootFunction.ps1 -hostname $hostname

                # --- Install VDA ---#
                $hostname = "ctx-svda"
                Write-Host "Install the VDA" -ForegroundColor Yellow
                #Copy-VMGuestFile -Source .\InstallServerVDA.ps1 -Destination "$tempFolder\InstallServerVDA.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
				#Copy-VMGuestFile -Source .\InstallVDAServer.ps1 -Destination "$tempFolder\InstallServerVDA.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                #Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "$tempFolder\InstallServerVDA.ps1 -IsoPath $tempFolder\$XenDesktopIsoName -controllers $controllers -ServerVdi yes -Domain $domainName" -GuestUser $GuestUser -GuestPassword $GuestPwd
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\InstallServerVDA.ps1 -IsoPath C:\Citrix\XenApp_and_XenDesktop_7_15_3000.iso -controllers `"ctx-all`" -Domain `"contoso.local`"" -GuestUser $GuestUser -GuestPassword $GuestPwd
                Invoke-VMScript -VM $hostname -ScriptType Powershell -ScriptText "C:\VDA\x64\XenDesktop Setup\XenDesktopVDASetup.exe /components VDA /controllers ctx-all.contoso.local /noreboot /enable_remote_assitance /enable_hdx_ports /optimize /enable_realtime_transport /enable_hdx_udp_ports /logpath C:\citrix" -GuestUser $GuestUser -GuestPassword $GuestPwd
                .\RebootFunction.ps1 -hostname $hostname

                # --- Install Services ---#
                Write-host "Add Features"
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "Add-WindowsFeature -Name Remote-Assistance,Remote-Desktop-Services,RDS-RD-Server,RDS-Licensing" -GuestUser $GuestUser -GuestPassword $GuestPwd | Out-Null
                                               
                .\RebootFunction.ps1 -hostname $hostname

                #$hostname = get-vm ctxvda-01
                
                # --- Add VDA to Machine Catalog & Delivery Group ---#
                Write-Host "Add $hostname to Machine Catalog"
                $ddc = Read-Host "Name of delivery controller"
                Copy-VMGuestFile -Source .\AddVDAToCatalog.ps1 -Destination "$tempFolder\AddVDAToCatalog.ps1" -vm (Get-vm $ddc) -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm (Get-vm $ddc) -ScriptType Powershell -ScriptText "$tempFolder\AddVDAToCatalog.ps1 -MachineName $hostname -CatalogName `"$catalogMC`" -domain $domainName -DeliveryGroupName `"Server`"" -GuestUser $domainName\$domainAccount -GuestPassword $domainPassword

                   
         }
        # ----- Install All-in-One ---#
        "A"  {
                Write-Host "Install SQL"
                Copy-VMGuestFile -Source .\XDInstallComponents.ps1 -Destination "$tempFolder\XDInstallComponents.ps1" -vm $hostname -LocalToGuest -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword" -Force
                $output = Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "$tempFolder\XDInstallComponents.ps1 -IsoPath `"$tempFolder\$XenDesktopIsoName`" -Components `"controller,desktopstudio,desktopdirector,licenseserver,storefront`" -NoSQL=`"false`"" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"
                if($output.Scriptoutput -like "*reboot required*") { 
                    Write-Host "Successfully Installed SQL Express" -ForegroundColor Green                    
                    .\RebootFunction.ps1 -hostname $hostname    
                } else {
                    Write-Host "Did not install SQL." -ForegroundColor Red
                    exit
                }

                Write-Host "Install All Citrix"
                Copy-VMGuestFile -Source .\XDInstallComponents.ps1 -Destination "$tempFolder\XDInstallComponents.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                $output = Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "$tempFolder\XDInstallComponents.ps1 -IsoPath `"$tempFolder\$XenDesktopIsoName`" -Components `"controller,desktopstudio,desktopdirector,licenseserver,storefront`" -NoSQL=`"true`"" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"                
                if($output.Scriptoutput -like "*complete*") { 
                    Write-Host "Successfully Installed All Citrix Components" -ForegroundColor Green
                    .\RebootFunction.ps1 -hostname $hostname
                } else { 
                    Write-Host "Did not install Citrix Components." -ForegroundColor Red 
                    exit
                }

                Write-Host "Configuring Site"
                Copy-VMGuestFile -Source .\MyNewSiteFunc.ps1 -Destination "$tempFolder\MyNewSiteFunc.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "$tempFolder\MyNewSiteFunc.ps1 -AdministratorName `"$domainAccount`" -DomainName `"$domainName`" -DatabasePassword `"$domainPassword`"" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"
                
                Write-Host "Creating Machine Catalog"
                Copy-VMGuestFile -Source .\NewMachineCatalog.ps1 -Destination "$tempFolder\NewMachineCatalog.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                #Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "$tempFolder\NewMachineCatalog.ps1" -GuestUser $domainName\$domainAccount -GuestPassword $domainPassword
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "$tempFolder\NewMachineCatalog.ps1 New-BrokerCatalog -Name `"$catalogMC`" -Description `"$descripMC`" -AllocationType `"$allocationType`" -MinimumFunctionalLevel `"$minimumFunctionalLevel`" -PersistUserChanges `"$persistUserChanges`" -ProvisionType `"$provisionType`" -SessionSupport `"$sessionSupport`"" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"
                
                Write-host "Create Delivery Group"
                Copy-VMGuestFile -Source .\NewDeliveryGroup.ps1 -destination "$tempFolder\NewDeliveryGroup.ps1" -vm $hostname -LocaltoGuest -GuestUser $GuestUser -GuestPassword $GuestPwd
                Invoke-VMScript -vm $hostname -ScriptType Powershell -scriptText "$tempFolder\NewDeliveryGroup.ps1 -Name $catalogMC -DesktopKind $DesktopKind" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"
                        
                Write-Host "Configuring StoreFront" -ForegroundColor Yellow
                Copy-VMGuestFile -Source .\SFCreateSite.ps1 -Destination "$tempFolder\SFCreateSite.ps1" -vm $hostname -LocalToGuest -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword" -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "$tempFolder\.\SFCreateSite.ps1 -XenDesktopControllers $hostname.$domainName -BaseURL $baseURL" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"               
                
        }

    }

} # END LARGE FOR LOOP

$EndDTM = (Get-date)
Write-Verbose "Elapse time: $(($EndDTM-$StartDTM).TotalSeconds) Seconds" -Verbose
Write-Verbose "Elapse time: $(($EndDTM-$StartDTM).TotalMinutes) Minutes" -Verbose