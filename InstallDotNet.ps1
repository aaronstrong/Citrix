<#
    
Copyright © 2017 Citrix Systems, Inc. All rights reserved.

.SYNOPSIS
Install required version of .NET Framework from XenDesktop ISO

.DESCRIPTION
The script will mount the specified ISO using native PowerShell cmdlet and take a look to see if
one of the designated .NET installers is there; if so it wil be installed.

If none of the designated installers can be found the script will check that the appropriate .NET
Windows feature is installed.

.PARAMETER IsoPath
The path to the ISO

#>
#Requires -Version 3
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true)]
    [string]$IsoPath
)

function Mount-ISO {
    Param (
        [Parameter(Mandatory=$true)]
        [string]$IsoPath,
        [int]$Retries = 3
    )
    for ($i = 1; $i -le $Retries; $i++) {
        $image = Mount-DiskImage -ImagePath $IsoPath -StorageType ISO -PassThru -ErrorAction Stop
        if ($image) {
            $volume = $image | Get-Volume
            if ($volume) {
                return $volume.DriveLetter + ":"
            } else {
                Write-Warning "Failed to get volume from image (attempt $i of $Retries)"
            }
        } else {
            Write-Warning "Failed to mount disk image $IsoPath (attempt $i of $Retries)"
        }
        Start-Sleep -Seconds 5
    }
    throw "Unable to mount image at $IsoPath"
}

function Add-DotNetFeature {
    [CmdletBinding()]
    Param()
   
    Import-Module ServerManager
    foreach ($name in @("NET-Framework-45-Features", "AS-NET-Framework")) {
        $feature = Get-WindowsFeature -Name $name -ErrorAction SilentlyContinue
        if ($feature -and ($feature.InstallState -eq "Available")) {
            Write-Host "Adding feature $name"
            Add-WindowsFeature -Name $name -IncludeAllSubFeature
        }
    }
}

$ErrorActionPreference = 'Stop'
try {
    $drive = Mount-ISO -IsoPath $IsoPath    
    Write-Host "Looking for .NET insallers on drive $drive"
    # Possible .NET installers in order of preference
    $dotNetInstallers = @(
        (New-Object PSObject -Property @{ Name = ".NET 4.5.2"; Path = "Support\DotNet452\NDP452-KB2901907-x86-x64-AllOS-ENU.exe"}),
        (New-Object PSObject -Property @{ Name = ".NET 4.5.1"; Path = "Support\DotNet451\NDP451-KB2858728-x86-x64-AllOS-ENU.exe"})
    )

    foreach ($entry in $dotNetInstallers) {

        $installer = Join-Path -Path $drive -ChildPath $entry.Path
        $name = $entry.Name
        if (Test-Path $installer) {
            Write-Host "Found installer $installer"
            $argList = "/q /norestart"
            $proc = Start-Process -FilePath $installer -ArgumentList $argList -Wait -NoNewWindow -PassThru
            if (($proc.ExitCode -eq 3) -or ($proc.ExitCode -eq 3010)) {
                return "$name installed. Reboot required"
            } elseif ($proc.ExitCode -ne 0) {
                throw "$installer $argList failed: error code $($proc.ExitCode)"
            }
            return "$name installed"
        } else {
            Write-Warning "$installer not found on $drive drive ($IsoPath)"
        }
    }
    Write-Warning "No .NET installer found on path $IsoPath"
    Add-DotNetFeature
    
} catch {
    $_
    exit 1
} finally {
    if (Test-Path $IsoPath) {
        Dismount-DiskImage -ImagePath $IsoPath
    }
}