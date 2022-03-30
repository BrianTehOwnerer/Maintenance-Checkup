@ECHO OFF

set "params=%*"
cd /d "%~dp0" && ( if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs" ) && fsutil dirty query %systemdrive% 1>nul 2>nul || (  echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/k cd ""%~sdp0"" && %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs" && "%temp%\getadmin.vbs" && exit /B )

powershell Set-ExecutionPolicy -ExecutionPolicy Unrestricted

SET ThisScriptsDirectory=%~dp0
SET PowerShellScriptPath=%ThisScriptsDirectory%MyPowerShellScript.ps1
rem %PowerShellScriptPath%

echo $DesktopPath = [Environment]::GetFolderPath("Desktop") >> start.ps1
echo New-Item -Path $DesktopPath\SMC -ItemType "directory"
echo Invoke-WebRequest -Uri https://raw.githubusercontent.com/briantehowenerer/Maintenance-Checkup/main/MC.ps1 -OutFile $DesktopPath\SMC\MC.ps1 >> start.ps1
echo $MCScript = $DesktopPath\SMC\MC.ps1 >> start.ps1
echo ^&$MCScript >> start.ps1



PowerShell Start-Process %PowerShellScriptPath%