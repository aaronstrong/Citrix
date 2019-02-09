
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco upgrade chocolatey

#choco install donet3.5 /y
#choco install dotnet4.5 /y
#choco install powershell /y
#choco install dotnet4.7.1 /y
choco install kb2919355 /y

choco install vcredist2017 /y
choco install vcredist2015 /y
choco install vcredist2013 /y
choco install vcredist2010 /y
