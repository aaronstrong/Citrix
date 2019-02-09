<#
   Main.ps1 purpose is to deploy virtual machines for a new Citrix envrionment from VMware
   using an existing template.

   The template needs to be pre-existing and for you to know the local administrator account and password.

   The script will prompt and ask how many VMs to create, the IP address for reach
   VM and the function of each VM.

   Once the prompts are complete, the script will then deploy the VMs, change the IP address,
   join the VM to the domain, and change the firewall to allow ICMP.

   Lastly, depending on the Citrix function, that specific Citrix role will be deployed.
#>
function Show-Menu()
{
    param(
        [string]$Title = 'Menu'
    )
    Write-Host ""
    Write-Host "==== $Title ===="
    Write-Host ""
    Write-Host "Press 'A' for All Citrix Components."
    Write-Host "Press 'Q' for SQL Server Only."    
    Write-Host "Press 'C' for Controller Server Only."
    Write-host "Press 'S' for StoreFront Server Only."
    Write-host "Press 'D' for Director Server Only."
    Write-Host "Press 'V' for VDA Only."
    Write-Host "Press 'L' for License Server Only."
    Write-Host "Press 'N' for No Citrix."
    Write-Host ""
}
$StartDTM = (Get-date)

cd $PSScriptRoot  # Change directory from which script is running

# ------Blank Arrays ---#
$nameVMs = @()
$funcVMs = @()
$staticIP= @()

# ------vSphere Targeting Variables tracked below------#
$vCenterInstance = "vcsa.domain.local"            # vCenter address
$vCenterUser = "administrator@domain.local"   # vCenter Username
$vCenterPass = "VMware1!"                     # vCenter Password

#-------VMware template and where to place VM ----#
$template = "TemplateName"                          # Template Name
$dsName = "datastore1"                        # Datastore to put VM
$esxName = "esxi.domain.local"                    # Host to put VM

# ------Local VM Template Password ---#
$GuestUser = "Administrator"  # Local account for the template
$GuestPwd  = "VMware1!"       # Local account password for the template

# ------Citrix Automation ----#
$XenDesktopIsoName = "XenApp_and_XenDesktop_7_6_3000.iso"			# Citrix ISO file name
$XenDesktopIsoPath = "\\nas\ISOs\Citrix\XenApp"	# Path to the ISO file

# ------Prompt for Domain Information ---#
for ($z=0; $z -lt 1; $z++)
{
    Write-Host "--- Domain Information ---" -ForegroundColor Yellow
    [string]$tdomainName = Read-Host -Prompt "Active Directory Domain Name?"
    [string]$tdomainController = Read-host -prompt "What is your Domain Controller Address"               # Domain Controller address
    [string]$tdomainAccount = read-host -prompt "Waht is the name of the domain administrator account"    # Domain Account
    $tdomainPassword = Read-host -prompt "What is the password of the domain administrator account"       # Domain Account Password    

    cls

    Write-host "--- Confirm Domain Information ---" -ForegroundColor Yellow
    Write-host ""
    Write-host "Domain Name" $tdomainName
    Write-host "Domain Controller IP Address" $tdomainController
    Write-host "Domain Account" $tdomainAccount
    Write-host "Domain Password" $tdomainPassword
    Write-host ""
    $confirm = Read-host -prompt "Select [Y] if these are correct"

    if($confirm -eq "y" -or $confirm -eq "Y"){
        $domainName       = $tdomainName
        $domainController = $tdomainController
        $domainAccount    = $tdomainAccount
        $domainPassword   = $tdomainPassword
    } else { $z-- }
    
    cls
}

# -----Prompt for Virtual Machine Information ---#
[int]$totalVMs = Read-Host -Prompt "How many servers to create?"

for ($i=0; $i -lt $totalVMs; $i++)
{    
    $b = $i + 1

    Write-Host "--- Virtula Machine Information ---" -ForegroundColor Yellow
    Write-Host ""
    $nameVM = Read-host -Prompt "Name of server $b"    
    $ipaddr = Read-Host -Prompt "IP address of server $b"    

    Show-Menu -Title "Citrix Functions"

    $funcVM = Read-Host -Prompt "Function of server $b"

    cls

    Write-host "---- Confirm VM Information ----" -ForegroundColor Yellow
    Write-Host ""
    Write-host "Server Name:" $nameVM
    Write-Host "IP Address:" $ipaddr
    Write-Host "Server function:" $funcVM
    Write-Host ""
    $confirm = Read-Host -Prompt "Select [Y] if these are correct"

    if($confirm -eq "y" -or $confirm -eq "Y"){ 
        $nameVMs += $nameVM
        $staticIP += $ipaddr
        $funcVMs += $funcVM
    } else { $i-- }

    CLS 
    
    switch ($funcVM){
        'S' {
            Write-host "--- StoreFront Configure ---" -ForegroundColor Yellow
            Write-Host ""
            Write-host "Comma separated list of XenDesktop Delivery Controller names which may be simple names"
            $xendesktopController = Read-Host -Prompt "Example: (ddc01.domain.local,ddc02.domain.local)"
            $baseURL = Read-Host -Prompt "Base URL for the Storefront services (e.g. http://storefront.domain.example/)"
        }
        'C' {
            Write-Host "--- Delivery Controller Configure ---" -ForegroundColor Yellow
            Write-Host ""
            $catalogMC = Read-Host -Prompt "Machine Catalog Name"
            $descripMC = $catalogMC
            Write-Host "How should the machines in the catalog be assigned to users?" -ForegroundColor Green
            $allocationType = Read-Host -Prompt "Options:random or permanent"
            Write-host "What is the provisioning type for the catalog?" -ForegroundColor Green
            $provisionType = Read-Host -Prompt "Options:Manual, PVS, MCS"
            Write-Host "Are the machines in the catalog single (desktops) or multi-session capable (hosted)." -ForegroundColor Green
            $sessionSupport = Read-Host -Prompt "Options: SingleSession, MultiSession"
            Write-Host "Specifies how user changes are persisted on machines in the catalog. Possible values are:" -ForegroundColor Green
            $persistUserChanges = Read-Host -Prompt "Options: OnLocal or discard"
            Write-Host "Minimum functional level" -ForegroundColor Green
            $minimumFunctionalLevel = Read-Host -Prompt "L7_9,L7_6,L7,L5"
        }
        'A' {
            Write-Host "--- Delivery Controller Configure ---" -ForegroundColor Yellow
            Write-Host ""
            $catalogMC = Read-Host -Prompt "Machine Catalog Name"
            $descripMC = $catalogMC
            Write-Host "How should the machines in the catalog be assigned to users?" -ForegroundColor Green
            $allocationType = Read-Host -Prompt "Options:random or permanent"
            Write-host "What is the provisioning type for the catalog?" -ForegroundColor Green
            $provisionType = Read-Host -Prompt "Options:Manual, PVS, MCS"
            Write-Host "Are the machines in the catalog single (desktops) or multi-session capable (hosted)." -ForegroundColor Green
            $sessionSupport = Read-Host -Prompt "Options: SingleSession, MultiSession"
            Write-Host "Specifies how user changes are persisted on machines in the catalog. Possible values are:" -ForegroundColor Green
            $persistUserChanges = Read-Host -Prompt "Options: OnLocal or discard"
            Write-Host "Minimum functional level" -ForegroundColor Green
            $minimumFunctionalLevel = Read-Host -Prompt "L7_9,L7_6,L7,L5"
            cls
            Write-host "--- StoreFront Configure ---" -ForegroundColor Yellow
            Write-Host ""            
            $baseURL = Read-Host -Prompt "Base URL for the Storefront services (e.g. http://storefront.domain.example/)"
        }        

    }
       
}
        

# This section logs on to the defined vCenter instance above
find-module -name vmware.powercli
Connect-VIServer $vCenterInstance  -User $vCenterUser -Password $vCenterPass -WarningAction SilentlyContinue

$ds = Get-Datastore -Name $dsName
$esx = Get-VMHost -Name $esxName

#---- Build the VMs ----#
for($a=0; $a -lt $totalVMs; $a++) {
    $task = New-VM -Template $template -VMHost $esx -Datastore $ds -Name $nameVMs[$a] -DiskStorageFormat Thin -RunAsync
    Wait-Task -Task $task  
  
    # Power on VM
    Get-VM -Name $nameVMs[$a] | Start-VM

    # ---- Wait for computer to come back ---#
    
    write-host “Waiting for VM to Start” -ForegroundColor Yellow
    do {
    $vmCheck = get-view -ViewType VirtualMachine -property Name,Guest -Filter @{"name"=$nameVMs[$a]}
    write-host $vmCheck.Guest.GuestOperationsReady
    sleep 3
    } until ( $vmCheck.Guest.GuestOperationsReady -eq ‘False’ )
 

    $hostname = $nameVMs[$a]
    $newIP = $staticIP[$a]
    
    #---- CONFIGURE THE VM ----#

    Write-host "Change VM $hostname IP to $newIP"
    $newGateWay = $newIP.Split(".")[0]+"."+$newIP.Split(".")[1]+"."+$newIP.Split(".")[2]+".1"
    $cmdIP = "netsh interface ipv4 set address name=`"Ethernet0 2`" static $newIP 255.255.255.0 $newGateWay"
    $cmdDNS1 = "netsh interface ipv4 set dns name=`"Ethernet0 2`" static $domainController"
    $cmdDNS2 = "netsh interface ip add dns name=`"Ethernet0 2`" 8.8.8.8 index=2"
 
    $vm = Get-VM $hostname
    #$cred = Get-Credential Administrator
    Invoke-VMScript -VM $vm -ScriptType Bat -ScriptText $cmdIP -Verbose -GuestUser $GuestUser -GuestPassword $GuestPwd
    Invoke-VMScript -VM $vm -ScriptType Bat -ScriptText $cmdDNS1 -Verbose -GuestUser $GuestUser -GuestPassword $GuestPwd
    Invoke-VMScript -VM $vm -ScriptType Bat -ScriptText $cmdDNS2 -Verbose -GuestUser $GuestUser -GuestPassword $GuestPwd

    sleep 5

    # ----- Allow ICMP Echo ----- #
    Write-Host "Changing Firewall"
    $cmdFW = "netsh advfirewall firewall add rule name=`"ICMP Allow incoming V4 echo request`" protocol=icmpv4:8,any dir=in action=allow"
    Invoke-VMScript -VM $hostname -ScriptType Bat -ScriptText $cmdFW -Verbose -GuestUser $GuestUser -GuestPassword $GuestPwd

    sleep 5

    # ----- Rename Computer ----- #
    Write-Host "Changing name of computer to $hostname"
    Invoke-VMScript -VM $hostname -ScriptType Powershell -ScriptText "Rename-Computer -NewName $hostname -Restart" -GuestUser $GuestUser -GuestPassword $GuestPwd

    Write-Host "Waiting until VM is restarted."
    .\RebootFunction.ps1 -hostname $hostname

    # ---- Join Domain ----- #
    $vm = Get-VM $hostname 
    # $userID = whoami
 
    # Domain account passowrd
 
$cmd = @"
`$domain = "$domainName"
`$password = "$domainPassword" | ConvertTo-SecureString -asPlainText -force;
`$username = "$domain\$domainAccount";
`$credential = New-Object System.Management.Automation.PSCredential(`$username, `$password);
Add-computer -DomainName `$domain -Credential `$credential -restart -force
"@
 
    Invoke-VMScript -VM $vm -ScriptText $cmd -GuestUser $GuestUser -GuestPassword $GuestPwd 

    Restart-VMGuest $hostname

    .\RebootFunction.ps1 -hostname $hostname       
    
    # ---- Enable AutoAdminLogin ---#
    Copy-VMGuestFile -Source .\AutoAdminLogon.ps1 -Destination "C:\Citrix\AutoAdminLogon.ps1" -vm $hostname -LocalToGuest -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword" -Force
    Invoke-VMScript -VM $hostname -ScriptType Powershell -ScriptText "C:\Citrix\AutoAdminLogon.ps1 -Switch Enable -UserName $domainName\$domainAccount -Password $domainPassword" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"
    
    Restart-VMGuest $hostname

    .\RebootFunction.ps1 -hostname $hostname

    # ---- Copy ISO File ---#
    Write-host "Copy ISO File" -ForegroundColor Yellow
    Copy-VMGuestFile -Source .\DownloadXenDesktopIso.ps1 -Destination "C:\Citrix\DownloadXenDesktopIso.ps1" -vm $hostname -LocalToGuest -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword" -Force
    Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\DownloadXenDesktopIso.ps1 -FileName $XenDesktopIsoName -Path `"$XenDesktopIsoPath`" -ToFolder C:\Citrix\" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"

    # ---- Install .NET ---#
    Write-Host "Install .NET" -ForegroundColor Yellow
    Copy-VMGuestFile -Source .\InstallDotNet.ps1 -Destination "C:\Citrix\InstallDotNet.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
    Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\InstallDotNet.ps1 -IsoPath C:\Citrix\$XenDesktopIsoName" -GuestUser $GuestUser -GuestPassword $GuestPwd

    switch ($funcVMs){

        'C'  {
                Write-host "Install Controller Only"  -ForegroundColor Yellow
                Copy-VMGuestFile -Source .\XDInstallComponents.ps1 -Destination "C:\Citrix\XDInstallComponents.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\XDInstallComponents.ps1 -IsoPath `"C:\Citrix\$XenDesktopIsoName`" -Components `"controller,desktopstudio`" -NoSQL=`"true`"" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"

                Write-Host "Rebooting $hostname..."
                Restart-VMGuest $hostname

                .\RebootFunction.ps1 -hostname $hostname
                
                Write-Host "Waiting for services to fully come online." -ForegroundColor DarkYellow
                Sleep -Seconds 30

                Write-Host "Configuring Site" -ForegroundColor Yellow
                Copy-VMGuestFile -Source .\MyNewSiteFunc.ps1  -Destination "C:\Citrix\MyNewSiteFunc.ps1" -vm $hostname -LocalToGuest -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"  -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\MyNewSiteFunc.ps1 -DatabasePassword `"P@ssw0rd`"" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"

                
                Write-Host "Creating Machine Catalog" -ForegroundColor Yellow
                Copy-VMGuestFile -Source .\NewMachineCatalog.ps1 -Destination "C:\Citrix\NewMachineCatalog.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\NewMachineCatalog.ps1 New-BrokerCatalog -Name `"$catalogMC`" -Description `"$descripMC`" -AllocationType `"$allocationType`" -MinimumFunctionalLevel `"$minimumFunctionalLevel`" -PersistUserChanges `"$persistUserChanges`" -ProvisionType `"$provisionType`" -SessionSupport `"$sessionSupport`"" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"
                                       
                Write-Host "Creating Delivery Group" -ForegroundColor Yellow
                Copy-VMGuestFile -Source .\NewDeliveryGroup.ps1 -Destination "C:\Citrix\NewDeliveryGroup.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\NewDeliveryGroup.ps1 -Name 2016 -DesktopKind Shared" -GuestUser ctxlab.local\Administrator -GuestPassword P@ssw0rd
                             
             }
        'S'  { 
                Write-host "Install StoreFront Only" -ForegroundColor Yellow
                Copy-VMGuestFile -Source .\XDInstallComponents.ps1 -Destination "C:\Citrix\XDInstallComponents.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\XDInstallComponents.ps1 -IsoPath `"C:\Citrix\$XenDesktopIsoName`" -Components `"storefront`" -NoSQL=`"true`"" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"

                Write-Host "Rebooting $hostname..."
                Restart-VMGuest $hostname

                .\RebootFunction.ps1 -hostname $hostname

                Copy-VMGuestFile -Source .\SFCreateSite.ps1 -Destination "C:\Citrix\SFCreateSite.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\.\SFCreateSite.ps1 -XenDesktopControllers $xendesktopController -BaseURL $baseURL" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"


             }
        "Q"  { 
                Write-Host "Install SQL Only" -ForegroundColor Yellow
                Copy-VMGuestFile -Source .\install_sqlexpress.ps1 -Destination "C:\Citrix\install_sqlexpress.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -VM $hostname -ScriptType Powershell -ScriptText "C:\Citrix\install_sqlexpress.ps1" -GuestUser $GuestUser -GuestPassword $GuestPwd
         }
        "V"  { 
                Write-host "Installing Pre-Reqs for VDA"
                # ---- Install VC++ ---#
                Write-Host "Install VC++" -ForegroundColor Yellow
                Copy-VMGuestFile -Source .\InstallVCplusplus.ps1 -Destination "C:\Citrix\InstallVCplusplus.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\InstallVCplusplus.ps1" -GuestUser $GuestUser -GuestPassword $GuestPwd
                # --- Install Services ---#
                Write-host "Enabled Services" -ForegroundColor Yellow
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "Add-WindowsFeature -Name Remote-Assistance,Remote-Desktop-Services,RDS-RD-Server -Restart" -GuestUser $GuestUser -GuestPassword $GuestPwd
                # --- Install VDA ---#
                Write-Host "Install VDA" -ForegroundColor Yellow
                Copy-VMGuestFile -Source .\InstallVCplusplus.ps1 -Destination "C:\Citrix\InstallServerVDA.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\InstallServerVDA.ps1" -GuestUser $GuestUser -GuestPassword $GuestPwd

                Write-Host "Rebooting $hostname..."
                Restart-VMGuest $hostname

                .\RebootFunction.ps1 -hostname $hostname             
             
             }
        "A"  {
                Write-Host "Install SQL" -ForegroundColor Yellow
                Copy-VMGuestFile -Source .\XDInstallComponents.ps1 -Destination "C:\Citrix\XDInstallComponents.ps1" -vm $hostname -LocalToGuest -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword" -Force
                $output = Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\XDInstallComponents.ps1 -IsoPath `"C:\Citrix\$XenDesktopIsoName`" -Components `"controller,desktopstudio,desktopdirector,licenseserver,storefront`" -NoSQL=`"false`"" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"
                if($output.Scriptoutput -like "*reboot required*") { 
                    Write-Host "Successfully Installed" -ForegroundColor Green                    
                    Write-Host "Rebooting $hostname..."
                    Restart-VMGuest $hostname
                    .\RebootFunction.ps1 -hostname $hostname    
                } else {
                    Write-Host "Did not install SQL" -ForegroundColor Red
                    exit
                }                


                Write-Host "Install All Citrix" -ForegroundColor Yellow
                Copy-VMGuestFile -Source .\XDInstallComponents.ps1 -Destination "C:\Citrix\XDInstallComponents.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\XDInstallComponents.ps1 -IsoPath `"C:\Citrix\$XenDesktopIsoName`" -Components `"controller,desktopstudio,desktopdirector,licenseserver,storefront`" -NoSQL=`"true`"" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"
                if($output.Scriptoutput -like "*complete*") { 
                    Write-Host "Successfully Installed" -ForegroundColor Green
                    Write-Host "Rebooting $hostname..."
                    Restart-VMGuest $hostname
                    .\RebootFunction.ps1 -hostname $hostname
                } else { 
                    Write-Host "Did not install Citrix" -ForegroundColor Red 
                    exit
                }                

                Write-Host "waiting"
                sleep 30

                Write-Host "Configuring Site" -ForegroundColor Yellow
                Copy-VMGuestFile -Source .\MyNewSiteFunc.ps1 -Destination "C:\Citrix\MyNewSiteFunc.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                $output = Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\MyNewSiteFunc.ps1 -DatabasePassword `"$domainPassword`"" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"
                
                
                Restart-VMGuest $hostname

                .\RebootFunction.ps1 -hostname $hostname

                Write-Host "Creating Machine Catalog" -ForegroundColor Yellow
                Copy-VMGuestFile -Source .\NewMachineCatalog.ps1 -Destination "C:\Citrix\NewMachineCatalog.ps1" -vm $hostname -LocalToGuest -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword" -Force
                #Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\NewMachineCatalog.ps1" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\NewMachineCatalog.ps1 New-BrokerCatalog -Name `"$catalogMC`" -Description `"$descripMC`" -AllocationType `"$allocationType`" -MinimumFunctionalLevel `"$minimumFunctionalLevel`" -PersistUserChanges `"$persistUserChanges`" -ProvisionType `"$provisionType`" -SessionSupport `"$sessionSupport`"" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"
                
                        
                Write-Host "Configuring StoreFront" -ForegroundColor Yellow
                Copy-VMGuestFile -Source .\SFCreateSite.ps1 -Destination "C:\Citrix\SFCreateSite.ps1" -vm $hostname -LocalToGuest -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword" -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\.\SFCreateSite.ps1 -BaseURL $baseURL" -GuestUser "$domainName\$domainAccount" -GuestPassword "$domainPassword"
                  
                
        }

    }

} # END LARGE FOR LOOP

$EndDTM = (Get-date)
Write-Verbose "Elapse time: $(($EndDTM-$StartDTM).TotalSeconds) Seconds" -Verbose
Write-Verbose "Elapse time: $(($EndDTM-$StartDTM).TotalMinutes) Minutes" -Verbose