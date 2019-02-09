[int] $totalVMs = Read-Host -Prompt "How many servers to create?"
$domainName = Read-Host -Prompt "Domain Name?"
$template = "T-2016"
$dsName = "datastore1"
$esxName = "192.168.2.205"

$StartDTM = (Get-date)

# ------vSphere Targeting Variables tracked below------
$vCenterInstance = "192.168.2.200"
$vCenterUser = "administrator@vsphere.local"
$vCenterPass = "VMware1!"

# ------Local VM Template Password ---#
$GuestUser = "Administrator"
$GuestPwd  = "VMware1!"

# ------Domain Information ---#
$domainController = "192.168.110.10"
$domainAccount = "Administrator"
$domainPassword = "P@ssw0rd"

# ------Citrix Automation ----#
$XenDesktopIsoName = "XenApp_and_XenDesktop_7_15.iso"
$XenDesktopIsoPath = "\\192.168.2.99\isos\Citrix\XenApp\7.15 LTSR\XenApp and XenDesktop\"


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


# --- check if All is selected ---#
if($funcVMs -contains "A") {
    # Get Index
    $position = $funcVMs.IndexOf("A")
    Write-Host $nameVMs[$position]
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

    sleep 10

    # Power on VM
    Get-VM -Name $nameVMs[$a] | Start-VM

    # ---- Wait for computer to come back ---#
    
    write-host “Waiting for VM to Start” -ForegroundColor Yellow
    do {
    $vmCheck = get-view -ViewType VirtualMachine -property Name,Guest -Filter @{"name"=$nameVMs[$a]}
    write-host $vmCheck.Guest.GuestOperationsReady
    sleep 3
    } until ( $vmCheck.Guest.GuestOperationsReady -eq ‘False’ )

    #---- CONFIGURE THE VM ----#    
    $hostname = $nameVMs[$a]
    $newIP = $staticIP[$a]

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
`$domain = "ctxlab.local"
`$password = "P@ssw0rd" | ConvertTo-SecureString -asPlainText -force;
`$username = "$domain\Administrator";
`$credential = New-Object System.Management.Automation.PSCredential(`$username, `$password);
Add-computer -DomainName `$domain -Credential `$credential -restart -force
"@
 
    Invoke-VMScript -VM $vm -ScriptText $cmd -GuestUser $GuestUser -GuestPassword $GuestPwd

    Restart-VMGuest $hostname

    .\RebootFunction.ps1 -hostname $hostname

    

    cd C:\Users\astrong\Documents\powershell\vmware

    
    # ---- Enable AutoAdminLogin ---#
    Copy-VMGuestFile -Source .\AutoAdminLogon.ps1 -Destination "C:\Citrix\AutoAdminLogon.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
    Invoke-VMScript -VM $hostname -ScriptType Powershell -ScriptText "C:\Citrix\AutoAdminLogon.ps1 -Switch Enable -UserName ctxlab.local\administrator -Password P@ssw0rd" -GuestUser $GuestUser -GuestPassword $GuestPwd
    
    Restart-VMGuest $hostname

    .\RebootFunction.ps1 -hostname $hostname

    # ---- Copy ISO File ---#
    Write-host "Copy ISO File" -ForegroundColor Yellow
    Copy-VMGuestFile -Source .\DownloadXenDesktopIso.ps1 -Destination "C:\Citrix\DownloadXenDesktopIso.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
    Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\DownloadXenDesktopIso.ps1 -FileName $XenDesktopIsoName -Path `"$XenDesktopIsoPath`" -ToFolder C:\Citrix\" -GuestUser $GuestUser -GuestPassword $GuestPwd


    # ---- Install .NET ---#
    Write-Host "Install .NET" -ForegroundColor Yellow
    Copy-VMGuestFile -Source .\InstallDotNet.ps1 -Destination "C:\Citrix\InstallDotNet.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
    Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\InstallDotNet.ps1 -IsoPath C:\Citrix\$XenDesktopIsoName" -GuestUser $GuestUser -GuestPassword $GuestPwd


    # ---- Install VC++ ---#
    Write-Host "Install VC++" -ForegroundColor Yellow
    Copy-VMGuestFile -Source .\InstallVCplusplus.ps1 -Destination "C:\Citrix\InstallVCplusplus.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
    Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\InstallVCplusplus.ps1" -GuestUser $GuestUser -GuestPassword $GuestPwd

    Write-Host "Rebooting $hostname..."
    Restart-VMGuest $hostname

    .\RebootFunction.ps1 -hostname $hostname
    
    switch ($funcVMs){

        'C'  {
                Write-host "Install Controller Only" 
                Copy-VMGuestFile -Source .\XDInstallComponents.ps1 -Destination "C:\Citrix\XDInstallComponents.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\XDInstallComponents.ps1 -IsoPath `"C:\Citrix\$XenDesktopIsoName`" -Components `"controller,desktopstudio`" -NoSQL=`"$false`"" -GuestUser $GuestUser -GuestPassword $GuestPwd

                Write-Host "Rebooting $hostname..."
                Restart-VMGuest $hostname

                .\RebootFunction.ps1 -hostname $hostname                    

                Write-Host "Configuring Site"
                Copy-VMGuestFile -Source .\MyNewSiteFunc.ps1  -Destination "C:\Citrix\MyNewSiteFunc.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\MyNewSiteFunc.ps1 -DatabasePassword `"P@ssw0rd`"" -GuestUser $GuestUser -GuestPassword $GuestPwd

             
             }
        'S'  { 
                Write-host "Configure StoreFront"
                Copy-VMGuestFile -Source .\XDInstallComponents.ps1 -Destination "C:\Citrix\XDInstallComponents.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\XDInstallComponents.ps1 -IsoPath `"C:\Citrix\$XenDesktopIsoName`" -Components `"storefront`" -NoSQL=`"$false`"" -GuestUser $GuestUser -GuestPassword $GuestPwd

                Write-Host "Rebooting $hostname..."
                Restart-VMGuest $hostname

                .\RebootFunction.ps1 -hostname $hostname

                Copy-VMGuestFile -Source .\SFCreateSite.ps1 -Destination "C:\Citrix\SFCreateSite.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\.\SFCreateSite.ps1 -XenDesktopControllers $hostname.$domainName -BaseURL http://storefront.$domainName " -GuestUser $GuestUser -GuestPassword $GuestPwd


             }
        "Q"  { 
                Write-Host "Install SQL"
                Copy-VMGuestFile -Source .\install_sqlexpress.ps1 -Destination "C:\Citrix\install_sqlexpress.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -VM $hostname -ScriptType Powershell -ScriptText "C:\Citrix\install_sqlexpress.ps1" -GuestUser $GuestUser -GuestPassword $GuestPwd
         }
        "V"  { "Configure VDA" }
        "A"  {
                Write-Host "Install SQL"
                Copy-VMGuestFile -Source .\install_sqlexpress.ps1 -Destination "C:\Citrix\install_sqlexpress.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                #Invoke-VMScript -VM $hostname -ScriptType Powershell -ScriptText "C:\Citrix\install_sqlexpress.ps1" -GuestUser $GuestUser -GuestPassword $GuestPwd

                #Write-Host "Rebooting $hostname..."
                #Restart-VMGuest $hostname

                #.\RebootFunction.ps1 -hostname $hostname


                Write-Host "Install All Citrix"
                Copy-VMGuestFile -Source .\XDInstallComponents.ps1 -Destination "C:\Citrix\XDInstallComponents.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\XDInstallComponents.ps1 -IsoPath `"C:\Citrix\$XenDesktopIsoName`" -Components `"controller,desktopstudio,storefront,licenseserver`"" -GuestUser $GuestUser -GuestPassword $GuestPwd
                
                Write-Host "Rebooting $hostname..."
                Restart-VMGuest $hostname

                .\RebootFunction.ps1 -hostname $hostname



                Write-Host "Configuring Site"
                Copy-VMGuestFile -Source .\MyNewSiteFunc.ps1 -Destination "C:\Citrix\MyNewSiteFunc.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\MyNewSiteFunc.ps1 -DatabasePassword `"P@ssw0rd`"" -GuestUser "ctxlab\Administrator" -GuestPassword "P@ssw0rd"

                Write-Host "Creating Machine Catalog"
                Copy-VMGuestFile -Source .\NewMachineCatalog.ps1 -Destination "C:\Citrix\NewMachineCatalog.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\NewMachineCatalog.ps1" -GuestUser ctxlab.local\Administrator -GuestPassword P@ssw0rd
                
                        
                Write-Host "Configuring StoreFront"
                Copy-VMGuestFile -Source .\SFCreateSite.ps1 -Destination "C:\Citrix\SFCreateSite.ps1" -vm $hostname -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
                Invoke-VMScript -vm $hostname -ScriptType Powershell -ScriptText "C:\Citrix\SFCreateSite.ps1 -XenDesktopControllers $hostname.$domainName -BaseURL http://storefront.$domainName" -GuestUser $GuestUser -GuestPassword $GuestPwd


                
                
        }

    }

} # END LARGE FOR LOOP

$EndDTM = (Get-date)
Write-Verbose "Elapse time: $(($EndDTM-$StartDTM).TotalSeconds) Seconds" -Verbose
Write-Verbose "Elapse time: $(($EndDTM-$StartDTM).TotalMinutes) Minutes" -Verbose