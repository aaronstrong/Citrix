<#   

Copyright © 2015-2016 Citrix Systems, Inc. All rights reserved.

.SYNOPSIS
Download a file from the specified location and optional verify download using hash

.DESCRIPTION
This script will download a file from the specified location to the
specified destination folder. If there is a file of name $FileName.<Algorithm> in the
same location then we assume this contains a checksum which will also be downloaded
and used to verify the download succeeded. Valud values for <Algorithm> are SHA256, MD5


.PARAMETER FileName
The name of the file to retrieve

.PARAMETER Path
The location to copy the file from. This may be 
    An HTTP(S) URL (e.g. https://example.com/downloads), 
    A CIFS share (e.g. \\computer\downloads) or
    A simple file system path (e.g. D:\downloads)

.PARAMETER ToFolder
Destination folder for the file.

.PARAMETER CifsUser
Optional user name for accessing CIFS share

.PARAMETER CifsPassword
Password for CIFS user

.OUTPUTS
On success the script returns the local path of the downloaded file.

#>
[CmdletBinding()]
Param (
    [string]$FileName,
    [string]$Path,
    [string]$ToFolder = "$Env:Temp",
    [string]$CifsUser,
    [string]$CifsPassword
)

# Download a file from the web with a retry loop using dlup.exe for preference; if dlup is
# not available then the .NET WebClient will be used.
function Download-WebFile {
    Param (
        [string]$url,
        [string]$localFile,
        [int]$retries = 2
    )
    $dlup = "..\..\dlup.exe"
    if (Test-Path -Path $dlup) {
        Write-Verbose "Download using dlup"
        $out = ".\dlup.out"
        $err = ".\dlup.err"
        try { 
            Write-Verbose "Starting download of $url (will retry $retries times on failure)"
            $proc = Start-Process -FilePath $dlup -ArgumentList "-p $url -o $localFile -r $retries" -Wait -NoNewWindow -PassThru `
                -RedirectStandardError $err -RedirectStandardOutput $out
            if ($proc.ExitCode -ne 0) {               
                throw "DLUP download failed with exit code: $($proc.ExitCode) `n$(Get-Content $err) `n$(Get-Content $out)"
            }
        } finally {
            Remove-Item $out
            Remove-Item $err
        }

    } else {
        Write-Verbose "Download using .NET WebClient"
        $ex = ""
        for ($i=0; $i -lt $retries; $i++) {
            try {
                $client = New-Object System.Net.WebClient
                 Write-Verbose "Starting download of $url [attempt $i]"
                $client.DownloadFile($url, $localFile)
                return
            } catch {
                Write-Verbose "Exception during download $_"
                $ex = $_
                Start-Sleep -Seconds 5
            }
        }
        throw $ex
    }
}

function Download-File {
    Param (
        [string]$FileName,
        [string]$Path,
        [string]$ToFolder = "$Env:Temp"
    )
    if (-not (Test-Path $ToFolder)) {
        New-Item -Path $ToFolder -ItemType Directory | Out-Null
    }  
    if ($ToFolder -eq ".") {
        $ToFolder = Get-Location
    }
    $localFile = Join-Path "$ToFolder" "$FileName"
    if (-not $Path) {
        $Path = ".\"
    }
    if ($Path -match "^https?://\w+") {
        # Web URL
        $Url = "$Path/$FileName"
        Download-WebFile $url $localFile
    } elseif (($Path -match "^\\\\\w+") -or ($Path -match "^[C-Z]:\\\w*") -or ($Path -match "^.\\\w*")) {
        # CIFS file share or local path
        if ($Path.EndsWith('\')) {
            $Path = $Path.TrimEnd('\')
        }
        if (-not [string]::IsNullOrEmpty($CifsUser)) {
            net use $Path "$CifsPassword" /user:$CifsUser | Out-Null
            if ($LastExitCode -ne 0) {
                throw "Unable to connect to share $Path using the given credentials: $CifsUser"
            }
        }
        Copy-Item -Path "$Path\$FileName" -Destination $ToFolder
        if (-not [string]::IsNullOrEmpty($CifsUser)) {
            net use $Path /delete | Out-Null
        }
    } else {
        throw "Cannot understand download path: $Path"
    }
    return $localFile
}

$ErrorActionPreference = "Stop"

try {
    # In order of preference
    $HashAlgorithms = @("SHA256", "MD5")

    # Download the principal file
    $downloadedFile = Download-File -FileName $FileName -Path $Path -ToFolder $ToFolder

    # Look for files containing hash
    foreach ($HashAlgorithm in $HashAlgorithms) {
        $hashFile = ""
        try { 
            $hashFile = Download-File -FileName "$FileName.$HashAlgorithm" -Path $Path -ToFolder $ToFolder
        } catch {
             Write-Verbose "$FileName.$HashAlgorithm not found"
             continue
        }
        $Hash = Get-Content -Path $hashFile
        Write-Verbose "Calculating $HashAlgorithm hash of $FileName"
        $fileHash = Get-FileHash -Path $downloadedFile -Algorithm $HashAlgorithm
        if ($fileHash.Hash.ToUpper() -eq $Hash.ToUpper()) {
            break
        }
        throw "Download checksum failed. File hash is $fileHash, expected $Hash"       
    }
    $downloadedFile

} catch {
    $_
    exit 1
}
