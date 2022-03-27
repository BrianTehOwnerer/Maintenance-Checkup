##Initialize Variables
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$SecureUpdaterurl = "https://secureupdater.s3.us-east-2.amazonaws.com/downloads/SecureUpdater.msi"
$SUoutpath = "$PSScriptRoot/SecureUpdater.msi"
$DriveAdvisorurl = "https://secureupdater.s3.us-east-2.amazonaws.com/downloads/driveadviser.msi"
$DAoutpath = "$PSScriptRoot/driveadvisor.msi"
$MCZipUrl = "https://secureupdater.s3.us-east-2.amazonaws.com/downloads/MC.zip"
$MCzippath = "$PSScriptRoot/MC.zip"


#turns on system restore for drive C and takes a snapshot.
Enable-ComputerRestore -Drive "C:\"
"System restore enabled"
Checkpoint-Computer -Description "Schrock Maintance Checkup" -RestorePointType "MODIFY_SETTINGS"

#Checking for an internet connection and waits for you to turn on the net.
while (!(test-connection 8.8.8.8 -Count 1 -Quiet)) {
    "please Connect to the internet to continue"
    Start-Sleep 5
}
write-out "Internet Connection Established"

#checks for SU and Drive Advisor, if not found installs them from the folders.
if (Test-Path -Path "C:\Program Files (x86)\Secure Updater\Secure Updater.exe" -IsValid) {
    Write-Output "SU is already installed"
}
else {
    Invoke-WebRequest -Uri $SecureUpdaterurl -OutFile $SUoutpath
    Start-Process $SUoutpath "/quiet"
}

if (Test-Path -Path "C:\Program Files (x86)\Drive Adviser\Drive Adviser.exe" -IsValid) {
    write-out "Drive Adviser already installed"
}
else {
    Invoke-WebRequest -Uri $DriveAdvisorurl -OutFile $DAoutpath
    Start-Process $DAoutpath "/quiet"
    Start-Process "C:\Program Files (x86)\Drive Adviser\Drive Adviser.exe"
}
Clear-Host
Write-Output "Downloading and running jrt/cpu test/ccleaner"
Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');


Invoke-WebRequest -Uri $MCZipUrl -OutFile $MCzippath 
Expand-Archive -Path $MCzippath -DestinationPath $PSScriptRoot -force
Start-Process $PSScriptRoot\jrt\get.bat -WorkingDirectory $PSScriptRoot\jrt\
Start-Process $PSScriptRoot\CPUTester.exe /passive -wait
start-process "C:\Program Files\Intel Corporation\Intel Processor Diagnostic Tool 64bit\Win-IPDT64.exe" -WorkingDirectory "C:\Program Files\Intel Corporation\Intel Processor Diagnostic Tool 64bit\" -Wait
Start-Process $PSScriptRoot\ccleanerx64.exe -Wait

Write-Output "installing chocolatly for adw/mbam/sas. Press any key to continue"
Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

#Gets Chocolatey and installs it from the internet
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

#Running sfc scan and placing file onto desktop

start-process sfc /scannow  -RedirectStandardOutput $PSScriptRoot\sfc.txt 

"Installing SAS, ADW, and MBAM..."
choco install adwcleaner malwarebytes superantispyware -y --ignore-checksums --allow-empty-checksums

Start-Process "C:\ProgramData\chocolatey\lib\adwcleaner\tools\adwcleaner_8.3.1.exe" -Wait
start-process $PSScriptRoot\HDTune.exe
Start-Process "C:\Program Files\SuperAntiSpyware\SuperAntiSpyware.exe" 
Start-Process "C:\Program Files\Malwarebytes\Anti-Malware\mbam.exe" -Wait



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
#Uninstalls SAS and MBAM
choco uninstall adwcleaner malwarebytes superantispyware -y 
Remove-Item $SUoutpath -Force
Remove-Item $DAoutpath
Remove-Item $MCzippath
Remove-Item $PSScriptRoot/MC -recurse -Force

#delete Powershell MC Script itself
Remove-Item -LiteralPath $MyInvocation.MyCommand.Path -Force

