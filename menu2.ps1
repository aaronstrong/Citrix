function Show-Menu()
{
    param(
        [string]$Title = 'Menu'
    )
    Write-Host ""
    Write-Host "==== $Title ===="
    Write-Host ""
    Write-Host "1:Press '1' for All Components."
    Write-Host "2:Press '2' for Controller Only."
    Write-host "3:Press '3' for StoreFront Only."
    Write-Host "4:Press '4' for SQL Only."
    Write-Host ""
}

# ------Set Arrays ---#
$nameVMs = @()
$funcVMs = @()
$staticIP= @()

[int] $totalVMs = Read-Host -Prompt "How many servers to create?"

for ($i=0; $i -lt $totalVMs; $i++)
{    
    $b = $i + 1
    $nameVM = Read-host -Prompt "Name of server $b"
    $ipaddr = Read-Host -Prompt "IP address of server $b"

    Show-Menu -Title "Citrix Functions"

    $funcVM = Read-Host -Prompt "Function of server $b"

    cls

    Write-host "---- Confirm inputs ----" -ForegroundColor Yellow
    Write-Host ""
    Write-host "Server Name:" $nameVM
    Write-Host "IP Address:" $ipaddr
    Write-Host "Server function:" $funcVM
    Write-Host ""
    $confirm = Read-Host -Prompt "Select [Y] if these are correct"

    if($confirm -eq "y"){ 
        $nameVMs += $nameVM
        $staticIP += $ipaddr
        $funcVMs += $funcVM
    } else { $i-- }

    CLS    
}

Write-Host $nameVMs
Write-Host $funcVMs
Write-Host $staticIP