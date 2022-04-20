Clear-Host
##Initialize Variables
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$SecureUpdaterurl = "https://secureupdater.s3.us-east-2.amazonaws.com/downloads/SecureUpdater.msi"
$SUoutpath = "$PSScriptRoot/SecureUpdater.msi"
$DriveAdvisorurl = "https://secureupdater.s3.us-east-2.amazonaws.com/downloads/driveadviser.msi"
$DAoutpath = "$PSScriptRoot/driveadvisor.msi"
$MCZipUrl = "https://secureupdater.s3.us-east-2.amazonaws.com/downloads/mc.zip"
$MCzippath = "$PSScriptRoot/mc.zip"


#turns on system restore for drive C and takes a snapshot.
Enable-ComputerRestore -Drive "C:\"
"System restore enabled"
Checkpoint-Computer -Description "Schrock Maintance Checkup" -RestorePointType "MODIFY_SETTINGS"


#checks for SU and Drive Advisor, if not found installs them from the folders.
if (Test-Path -Path "C:\Program Files (x86)\Secure Updater\Secure Updater.exe") {
    Write-Output "SU is already installed"
}
else {
    Invoke-WebRequest -Uri $SecureUpdaterurl -OutFile $SUoutpath
    Start-Process $SUoutpath "/quiet"
}

if (Test-Path -Path "C:\Program Files (x86)\Drive Adviser\Drive Adviser.exe") {
    write-out "Drive Adviser already installed"
}
else {
    Invoke-WebRequest -Uri $DriveAdvisorurl -OutFile $DAoutpath
    Start-Process $DAoutpath "/quiet" -wait
    Start-Process "C:\Program Files (x86)\Drive Adviser\Drive Adviser.exe"
}
Write-Output "Downloading and running jrt/cpu test/ccleaner"
Write-Host "Press any key to continue...";
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

#Killing web browser processess
taskkill.exe /IM chrome.exe /F
taskkill.exe /IM firefox.exe /F
taskkill.exe /IM edge.exe /F

#Download and Extract zip file with MC programs
Invoke-WebRequest -Uri $MCZipUrl -OutFile $MCzippath 
Expand-Archive -Path $MCzippath -DestinationPath $PSScriptRoot -force
Start-Process $PSScriptRoot\jrt.exe -wait
#Start-Process $PSScriptRoot\jrt\get.bat -WorkingDirectory $PSScriptRoot\jrt\
Start-Process $PSScriptRoot\CPUTester.exe /passive -wait
start-process "C:\Program Files\Intel Corporation\Intel Processor Diagnostic Tool 64bit\Win-IPDT64.exe" -WorkingDirectory "C:\Program Files\Intel Corporation\Intel Processor Diagnostic Tool 64bit\" -Wait
Start-Process $PSScriptRoot\CCleaner64.exe -Wait
Start-Process $PSScriptRoot\BatteryInfoView.exe -Wait 

#Installs a program called chocolatey https://chocolatey.org/ which will allow
#Us to install the latest MBAM/SAS/ADW
Write-Output "installing chocolatly for adw/mbam/sas. Press any key to continue"
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

#Gets Chocolatey and installs it from the internet
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

#Running sfc scan and placing file onto desktop
start-process sfc /scannow  -RedirectStandardOutput $PSScriptRoot\sfc.txt 

"Installing SAS, ADW, and MBAM..."
choco install adwcleaner malwarebytes superantispyware -y --ignore-checksums --allow-empty-checksums


start-process $PSScriptRoot\HDTune.exe
Start-Process "C:\Program Files\SuperAntiSpyware\SuperAntiSpyware.exe" 
Start-Process "C:\Program Files\Malwarebytes\Anti-Malware\mbam.exe" -Wait
Start-Process "C:\ProgramData\chocolatey\lib\adwcleaner\tools\adwcleaner_8.3.1.exe" -Wait


#wait for imput at the end of the script
Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

Clear-Host
Get-PhysicalDisk | Where-Object mediatype -match "SSD"
Write-Output "Optimize c drive"
Optimize-Volume -DriveLetter C -ReTrim


#Ending script cleanup step

Write-Host "This will remove all traces that we were ever even here..."
Write-Host -NoNewLine 'Press any key to continue...Otherwise just close the powershell window';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

#Uninstalls SAS, MBAM, and ADW
choco uninstall adwcleaner malwarebytes superantispyware -y 

#Delete downloaded files needs more testing before i let it delete everything
#Remove-Item $SUoutpath -Force
#Remove-Item $DAoutpath -Force
#Remove-Item $MCzippath -Force
#Remove-Item $PSScriptRoot/MC -recurse -Force

#delete Powershell MC Script itself
#Remove-Item -LiteralPath $MyInvocation.MyCommand.Path -Force
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
