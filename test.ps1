find-module -name vmware.powercli

#Install-Module -Name VMware.Powercli
#Install-Module -Name VMware.VimAutomation.Cis.Core

#Set-PowerCLIConfiguration -InvalidCertificateAction Ignore

# ------vSphere Targeting Variables tracked below------
$vCenterInstance = "192.168.2.200"
$vCenterUser = "administrator@vsphere.local"
$vCenterPass = "VMware1!"
 
# This section logs on to the defined vCenter instance above
Connect-VIServer $vCenterInstance  -User $vCenterUser -Password $vCenterPass -WarningAction SilentlyContinue

$cluster = (get-cluster).Name
$resources = (Get-ResourcePool).Name
$template = "T-2016"
$dsName = "datastore1"
$esxName = "192.168.2.205"
$ds = Get-Datastore -Name $dsName
$esx = Get-VMHost -Name $esxName
$vmName = "SVDA-01"

$task = New-VM -Template $template -VMHost $esx -Datastore $ds -Name $vmName -DiskStorageFormat Thin
Wait-Task -Task $task

Get-VM -Name $vmName | Start-VM


# ---- Wait for computer to come back ---#
write-host “Waiting for VM to Start” -ForegroundColor Yellow
do {
$vmCheck = get-view -ViewType VirtualMachine -property Name,Guest -Filter @{"name"="$vmName"}
write-host $vm.Guest.GuestOperationsReady
sleep 3
} until ( $vmCheck.Guest.GuestOperationsReady -eq ‘False’ )



# ----- Change IP Address ----- #
$hostname = $vmName
$newIP = "192.168.110.29"
$GuestUser = "Administrator"
$GuestPwd = "VMware1!"
 
$newGateWay = $newIP.Split(".")[0]+"."+$newIP.Split(".")[1]+"."+$newIP.Split(".")[2]+".1"
$cmdIP = "netsh interface ipv4 set address name=`"Ethernet0 2`" static $newIP 255.255.255.0 $newGateWay"
$cmdDNS1 = "netsh interface ipv4 set dns name=`"Ethernet0 2`" static 192.168.110.10"
$cmdDNS2 = "netsh interface ip add dns name=`"Ethernet0 2`" 8.8.8.8 index=2"
 
$vm = Get-VM $hostname
#$cred = Get-Credential Administrator
Invoke-VMScript -VM $vm -ScriptType Bat -ScriptText $cmdIP -Verbose -GuestUser $GuestUser -GuestPassword $GuestPwd
Invoke-VMScript -VM $vm -ScriptType Bat -ScriptText $cmdDNS1 -Verbose -GuestUser $GuestUser -GuestPassword $GuestPwd
Invoke-VMScript -VM $vm -ScriptType Bat -ScriptText $cmdDNS2 -Verbose -GuestUser $GuestUser -GuestPassword $GuestPwd

# ----- Allow ICMP Echo ----- #
$cmdFW = "netsh advfirewall firewall add rule name=`"ICMP Allow incoming V4 echo request`" protocol=icmpv4:8,any dir=in action=allow"
Invoke-VMScript -VM $hostname -ScriptType Bat -ScriptText $cmdFW -Verbose -GuestUser $GuestUser -GuestPassword $GuestPwd


# ----- Rename Computer ----- #
Invoke-VMScript -VM $hostname -ScriptType Powershell -ScriptText "Rename-Computer -NewName $hostname -Restart" -Verbose -GuestUser $GuestUser -GuestPassword $GuestPwd

sleep 30

# ---- Wait for computer to come back ---#
write-host “Waiting for VM to Start” -ForegroundColor Yellow
do {
$vmCheck = get-view -ViewType VirtualMachine -property Name,Guest -Filter @{"name"="$vmName"}
write-host $vmCheck.Guest.GuestOperationsReady
sleep 3
} until ( $vmCheck.Guest.GuestOperationsReady -eq ‘False’ )


# ----- Join Domain ----- #

$vm = Get-VM $hostname
#$cred = Get-Credential Administrator
 
# Run the script as a domain account
$userID = whoami
 
# Domain account passowrd
$DomainAccountPWD = (Get-Credential $userID -Message "Please Enter your Domain account password.").GetNetworkCredential().Password
 
$cmd = @"
`$domain = "ctxlab.local"
`$password = "P@ssw0rd" | ConvertTo-SecureString -asPlainText -force;
`$username = "$domain\Administrator";
`$credential = New-Object System.Management.Automation.PSCredential(`$username, `$password);
Add-computer -DomainName `$domain -Credential `$credential -restart -force
"@
 
Invoke-VMScript -VM $vm -ScriptText $cmd -Verbose -GuestUser $GuestUser -GuestPassword $GuestPwd

Restart-VMGuest $hostname

# ---- Wait for computer to shutdown ---#
write-host “Waiting for VM Tools to Start”
do {
$toolsStatus = (Get-VM $hostname | Get-View).Guest.ToolsStatus
write-host $toolsStatus
sleep 10
} until ( $toolsStatus -ne ‘toolsOk’ )


# ---- Wait for computer to come back ---#
write-host “Waiting for VM to Start” -ForegroundColor Yellow
do {
$vmCheck = get-view -ViewType VirtualMachine -property Name,Guest -Filter @{"name"="$hostname"}
write-host $vmCheck.Guest.GuestOperationsReady
sleep 10
} until ( $vmCheck.Guest.GuestOperationsReady -eq ‘False’ )



cd C:\Users\astrong\Documents\powershell\vmware

# ---- Enable AutoAdminLogin ---#
Copy-VMGuestFile -Source .\AutoAdminLogon.ps1 -Destination "C:\Citrix\AutoAdminLogon.ps1" -vm $vmName -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
Invoke-VMScript -VM $vmName -ScriptType Powershell -ScriptText "C:\Citrix\AutoAdminLogon.ps1 -Switch Enable -UserName ctxlab.local\administrator -Password P@ssw0rd" -GuestUser $GuestUser -GuestPassword $GuestPwd


# ---- Copy ISO File ---#
Copy-VMGuestFile -Source .\DownloadXenDesktopIso.ps1 -Destination "C:\Citrix\DownloadXenDesktopIso.ps1" -vm $vmName -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
Invoke-VMScript -vm $vmName -ScriptType Powershell -ScriptText "C:\Citrix\DownloadXenDesktopIso.ps1 -FileName XenApp_and_XenDesktop_7_15.iso -Path `"\\192.168.2.99\isos\citrix\xenapp\7.15 LTSR\XenApp and XenDesktop`" -ToFolder C:\Citrix\" -GuestUser $GuestUser -GuestPassword $GuestPwd


# ---- INstall .NET ---#
Copy-VMGuestFile -Source .\InstallDotNet.ps1 -Destination "C:\Citrix\InstallDotNet.ps1" -vm $vmName -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
Invoke-VMScript -vm $vmName -ScriptType Powershell -ScriptText "C:\Citrix\InstallDotNet.ps1 -IsoPath C:\Citrix\XenApp_and_XenDesktop_7_15.iso" -GuestUser $GuestUser -GuestPassword $GuestPwd


# ---- Install Server VDA ---#
Copy-VMGuestFile -Source .\InstallServerVDA.ps1 -Destination "C:\Citrix\InstallServerVDA.ps1" -vm $vmName -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
Invoke-VMScript -vm $vmName -ScriptType Powershell -ScriptText "C:\Citrix\InstallServerVDA.ps1 -IsoPath C:\Citrix\XenApp_and_XenDesktop_7_15.iso -controllers NYDC-01 -Domain ctxlab.local -ServerVdi No" -GuestUser $GuestUser -GuestPassword $GuestPwd

Restart-VMGuest -VM $hostname




write-host “Waiting for VM to Start” -ForegroundColor Yellow
do {
$vmCheck = get-view -ViewType VirtualMachine -property Name,Guest -Filter @{"name"="Tiny VM"}
write-host $vmCheck.Guest.GuestOperationsReady
sleep 3
} until ( $vmCheck.Guest.GuestOperationsReady -eq ‘False’ )


<#
# ---- Install SQL Express ---#
Copy-VMGuestFile -Source .\install_sqlexpress.ps1 -Destination "C:\Citrix\install_sqlexpress.ps1" -vm $vmName -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
#Invoke-VMScript -VM $vmName -ScriptType Powershell -ScriptText "C:\Citrix\install_sqlexpress.ps1" -GuestUser $GuestUser -GuestPassword $GuestPwd


Get-vm $vmName | Restart-VM -Confirm:$false

# ---- Wait for computer to shutdown ---#
write-host “Waiting for VM Tools to Start”
do {
$toolsStatus = (Get-VM $vmName | Get-View).Guest.ToolsStatus
write-host $toolsStatus
sleep 3
} until ( $toolsStatus -ne ‘toolsOk’ )


# ---- Wait for computer to come back ---#
write-host “Waiting for VM to Start” -ForegroundColor Yellow
do {
$vmCheck = get-view -ViewType VirtualMachine -property Name,Guest -Filter @{"name"="NYDC-01"}
write-host $vmCheck.Guest.GuestOperationsReady
sleep 3
} until ( $vmCheck.Guest.GuestOperationsReady -eq ‘False’ )



# ---- Install XD Components ---#
Copy-VMGuestFile -Source .\XDInstallComponents.ps1 -Destination "C:\Citrix\XDInstallComponents.ps1" -vm $vmName -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
Invoke-VMScript -vm $vmName -ScriptType Powershell -ScriptText "C:\Citrix\XDInstallComponents.ps1 -IsoPath `"C:\Citrix\XenApp_and_XenDesktop_7_15.iso`" -Components `"controller,desktopstudio,storefront,licenseserver`" -NoSQL=`"$false`"" -GuestUser $GuestUser -GuestPassword $GuestPwd


Restart-VMGuest -VM $vmName -Confirm:$false

# ---- Wait for computer to shutdown ---#
write-host “Waiting for VM Tools to Start”
do {
$toolsStatus = (Get-VM $vmName | Get-View).Guest.ToolsStatus
write-host $toolsStatus
sleep 3
} until ( $toolsStatus -ne ‘toolsOk’ )


# ---- Wait for computer to come back ---#
write-host “Waiting for VM to Start” -ForegroundColor Yellow
do {
$vmCheck = get-view -ViewType VirtualMachine -property Name,Guest -Filter @{"name"="NYDC-01"}
write-host $vmCheck.Guest.GuestOperationsReady
sleep 3
} until ( $vmCheck.Guest.GuestOperationsReady -eq ‘False’ )


# ---- XD Create the Site ---#
Copy-VMGuestFile -Source .\XDCreateSite.ps1 -Destination "C:\Citrix\XDCreateSite.ps1" -vm $vmName -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
Invoke-VMScript -vm $vmName -ScriptType Powershell -ScriptText "C:\Citrix\XDCreateSite.ps1 -AdministratorName `"Administrator`" -DomainName `"ctxlab.local`" -LicenseServer `"NYDC-01`"" -GuestUser "ctxlab\administrator" -GuestPassword "P@ssw0rd"


Copy-VMGuestFile -Source .\SFCreateSite.ps1 -Destination "C:\Citrix\SFCreateSite.ps1" -vm $vmName -LocalToGuest -GuestUser $GuestUser -GuestPassword $GuestPwd -Force
Invoke-VMScript -vm $vmName -ScriptType Powershell -ScriptText "C:\Citrix\SFCreateSite.ps1 -XenDesktopControllers NYDC-01.ctxlab.local -DomainName `"ctxlab.local`" -BaseURL http://storefront.ctxlab.local -Farmtype XenDesktop" -GuestUser "ctxlab\administrator" -GuestPassword "P@ssw0rd"



#>