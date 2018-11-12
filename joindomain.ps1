<#
    
Copyright © 2015 Citrix Systems, Inc. All rights reserved.

.SYNOPSIS
Join the specified domain

.DESCRIPTION

#>
Param (
    [Parameter(Mandatory=$true)]
    [string]$DomainName,    
    [Parameter(Mandatory=$true)]
    [string]$UserName,  
    [Parameter(Mandatory=$true)]
    [string]$Password
)

# Occasionally we see a failure to join the domain because the DC can't be contacted even though it appears to be accessible from
# the domain joiner. The retry loop is an attempt to counter this.
function Join-Domain {
    Param (
        $DomainName,
        $DomainCredentials,
        [int]$retries = 3
    )
    $ex = ""
    for ($i=0; $i -lt $retries; $i++) {
        try {
            $result = Add-Computer -DomainName $DomainName -Credential $DomainCredentials -PassThru -WarningAction SilentlyContinue 
            if ($result.HasSucceeded) {
                return $result.ComputerName
            }
        } catch {
            $ex = $_
            Start-Sleep -Seconds 10
        }
    }
    throw "Domain join failed: $ex"
}

$ErrorActionPreference = "Stop"
try {
    if (-not $UserName.Contains('\') -and -not $UserName.Contains('@')) {
        $UserName = "$DomainName\$UserName"
    }
    $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force 
    $DomainCredentials = New-Object System.Management.Automation.PSCredential $UserName, $securePassword   
    $computerName = Join-Domain $DomainName $DomainCredentials 
    return "$computerName.$DomainName"
} catch {
    $error[0]
    exit 1
}
