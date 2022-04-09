@ECHO OFF

set "params=%*"
cd /d "%~dp0" && ( if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs" ) && fsutil dirty query %systemdrive% 1>nul 2>nul || (  echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/k cd ""%~sdp0"" && %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs" && "%temp%\getadmin.vbs" && exit /B )



SET ThisScriptsDirectory=%~dp0
SET PowerShellScriptPath=%ThisScriptsDirectory%start.ps1
rem %PowerShellScriptPath%

echo while (!(test-connection 8.8.8.8 -Count 1 -Quiet)) { >> start.ps1
echo     "please Connect to the internet to continue" >> start.ps1
echo     Start-Sleep 5 >> start.ps1
echo } >> start.ps1
echo write-out "Internet Connection Established" >> start.ps1

echo $DesktopPath = [Environment]::GetFolderPath("Desktop") >> start.ps1
echo Remove-Item -Path $DesktopPath\SMC -Force -Recurse >> start.ps1
echo New-Item -Path $DesktopPath\SMC -ItemType "directory" >> start.ps1
echo Invoke-WebRequest -Uri https://raw.githubusercontent.com/briantehowenerer/Maintenance-Checkup/main/MC.ps1 -OutFile $DesktopPath\SMC\MC.ps1 >> start.ps1
echo ^&$DesktopPath\SMC\MC.ps1  >> start.ps1

powershell Set-ExecutionPolicy -ExecutionPolicy Unrestricted
PowerShell.exe -Command "& {Start-Process PowerShell.exe -ArgumentList '-ExecutionPolicy Bypass -File ""%~dpn0.ps1""' -Verb RunAs}"