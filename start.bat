@ECHO OFF
echo Invoke-WebRequest -Uri https://raw.githubusercontent.com/briantehowenerer/Maintenance-Checkup/main/MC.ps1 -OutFile MC.ps1 > start.ps1
echo #iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI" >> start.ps1
echo Start-process $PSScriptRoot\MC.ps1 >> start.ps1
PowerShell.exe -Command "& {Start-Process PowerShell.exe -ArgumentList '-ExecutionPolicy Bypass -File ""%~dpn0.ps1""' -Verb RunAs}"
