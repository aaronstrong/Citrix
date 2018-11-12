<#
    
Copyright © 2015 Citrix Systems, Inc. All rights reserved.

.SYNOPSIS
Control Windows AutoAdminLogon registry entry

.DESCRIPTION
The script will control Windows AutoAdminLogon registry entry - either enable or disable 
automatic logon of a specified user. 

.PARAMETER Switch
Reserved word "enable" or "disable" to enable or disable auto-logon

.PARAMETER UserName
Domain qualified name (e.g. DOMAIN\User) or UPN (e.g. user@domain.com) accepted. Required if eabling auto-logon. 

.PARAMETER Password
Password for the auto-logon account. Required if eabling auto-logon. 

#>
Param(
    [Parameter(Mandatory=$true)]
    [string]$Switch,
    [string]$UserName,   
    [string]$Password
)

function Remove-ItemPropertyIfPresent {
    Param(
        $Path,
        $Name
    )
    try {
        Remove-ItemProperty -Path $Path -Name $Name
    } catch {
        Write-Output "${Path}\$Name does not exist"
    }
}

$ErrorActionPreference = "Stop"
$regroot = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon"

try {
    if ($Switch -eq "enable") {
        Write-Output "Enabling auto-logon for $UserName"    
        $data = @{
            "DefaultUserName"=$UserName;
            "AltDefaultUserName"=$UserName;
            "DefaultPassword"=$Password;
            "AutoAdminLogon"="1"
        } 
        foreach($key in $data.keys) {
            Set-ItemProperty -Path $regroot -Name $key -Value $data[$key]
        }
    } elseif ($Switch -eq "disable") {
        Write-Output "Disabling auto-logon"    
        Set-ItemProperty -Path $regroot -Name "AutoAdminLogon" -Value "0"
        Remove-ItemPropertyIfPresent -Path $regroot -Name "DefaultUserName"
        Remove-ItemPropertyIfPresent -Path $regroot -Name "AltDefaultUserName"    
        Remove-ItemPropertyIfPresent -Path $regroot -Name "DefaultPassword"
    }
} catch {
    $error[0]
    exit 1
}