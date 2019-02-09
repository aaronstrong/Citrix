[xml]$computerlist = Get-Content computers.xml
foreach($computer in $computerlist.computers.target)
{
    Write-Host $computer.name
}
$administrator = $computerlist.domain.username

Write-Host $administrator