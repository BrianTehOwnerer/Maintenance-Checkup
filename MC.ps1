Clear-Host
##Initialize Variables
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$SecureUpdaterurl = "https://secureupdater.s3.us-east-2.amazonaws.com/downloads/SecureUpdater.msi"
$SUoutpath = "$PSScriptRoot/SecureUpdater.msi"
$DriveAdvisorurl = "https://secureupdater.s3.us-east-2.amazonaws.com/downloads/driveadviser.msi"
$DAoutpath = "$PSScriptRoot/driveadvisor.msi"
$MCZipUrl = "https://secureupdater.s3.us-east-2.amazonaws.com/downloads/mc.zip"
$MCzippath = "$PSScriptRoot/mc.zip"

<#
 .SYNOPSIS
 Main fuction
 
 .DESCRIPTION
 This is just this way in order for the script to keep the top down script style language while being able to utilize function calls
 This just calls the menu so we can go from there.
 Also initialize the enviornmental variables here.
 
 .NOTES
 General notes
 #>
function Main {

	Menu
}


<#
.SYNOPSIS
Menu to select what we are doing

.DESCRIPTION
Menu system to select what part of the process we are on. easily extnedable to add new functions as needed
#>
Function Menu {
	Clear-Host        
	Do {
		Clear-Host                                                                       
		Write-Host -Object 'Please choose an option'
		Write-Host -Object '**********************'
		Write-Host -Object 'Maitance Check Options' -ForegroundColor Yellow
		Write-Host -Object '**********************'
		Write-Host -Object '1.  Install DriveAdvisor/SecureUpdater '
		Write-Host -Object ''
		Write-Host -Object '2.  Download and Install MC tools '
		Write-Host -Object ''
		Write-Host -Object '3.  Run Scripts for MC '
		Write-Host -Object ''
		Write-Host -Object '4.  Reports --Work in Progress'
		Write-Host -Object ''
		Write-Host -Object '5.  Cleanup --Work in Progress'
		Write-Host -Object $errout
		$Menu = Read-Host -Prompt '(0-5 or Q to Quit)'
 
		switch ($Menu) {
			1 {
				InstallDAandSU            
				anyKey
			}
			2 {
				DownloadFiles
				anyKey
			}
			3 {
				RunMCScript
				anyKey
			}
			4 {
				Reports
				anyKey
			}
			5 {
				Cleanup
				anyKey
			}
			Q {
				Exit
			}   
			default {
				$errout = 'Invalid option please try again........Try 0-5 or Q only'
			}
 
		}
	}
	until ($Menu -eq 'q')
}   


Function InstallDAandSU {
	#checks for SU and Drive Advisor, if not found installs them from the folders.
	if (Test-Path -Path "C:\Program Files (x86)\Secure Updater\Secure Updater.exe") {
		Write-Host "SU is already installed"
	}
	else {
		Invoke-WebRequest -Uri $SecureUpdaterurl -OutFile $SUoutpath
		Start-Process $SUoutpath "/quiet"
	}

	if (Test-Path -Path "C:\Program Files (x86)\Drive Adviser\Drive Adviser.exe") {
		Write-Host "Drive Adviser already installed"
	}
	else {
		Invoke-WebRequest -Uri $DriveAdvisorurl -OutFile $DAoutpath
		Start-Process $DAoutpath "/quiet" -wait
		Start-Process "C:\Program Files (x86)\Drive Adviser\Drive Adviser.exe"
	}
	Write-Host -NoNewLine 'Press any key to continue...';
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

}

Function DownloadFiles {
	Write-Host "Downloading and running jrt/cpu test/ccleaner"
	#Download and Extract zip file with MC programs
	Invoke-WebRequest -Uri $MCZipUrl -OutFile $MCzippath 
	Expand-Archive -Path $MCzippath -DestinationPath $PSScriptRoot -force

	#Installs a program called chocolatey https://chocolatey.org/ which will allow
	#Us to install the latest MBAM/SAS/ADW
	Write-Host "installing chocolatly for adw/mbam/sas."

	#Gets Chocolatey and installs it from the internet
	Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
	"Installing SAS, ADW, and MBAM..."
	choco install adwcleaner malwarebytes superantispyware -y --ignore-checksums --allow-empty-checksums
	#delete any logs that happen to exist already for SAS or MBAM
	Remove-Item C:\Users\TechPc2\AppData\Roaming\SUPERAntiSpyware.com\SUPERAntiSpyware\Logs\* -Recurse -Force
	Remove-Item C:\ProgramData\Malwarebytes\MBAMService\ScanResults\* -Recurse -Force
	
	Write-Host -NoNewLine 'Press any key to continue...';
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
}


Function RunMCScript {
	#turns on system restore for drive C and takes a snapshot.
	Enable-ComputerRestore -Drive "C:\"
	"System restore enabled"
	Checkpoint-Computer -Description "Schrock Maintance Checkup" -RestorePointType "MODIFY_SETTINGS"


	#Gets the current power configureation scheme
	$powercfgGUID = powercfg /getactivescheme
	#Splits out just the GUID from the active scheme
	$powercfgGUID = $powercfgGUID.split( )[3]
	#Imports our custom power config as that dumb GUID, then sets it as active
	powercfg /import $PSScriptRoot\MCpowercfg.pow 11111111-1111-2222-2222-333333333333
	powercfg /setactive 11111111-1111-2222-2222-333333333333


	#Optimize the C drive
	Get-PhysicalDisk | Where-Object mediatype -match "SSD"
	Write-Output "Optimize c drive"
	Optimize-Volume -DriveLetter C -ReTrim
    

	#Killing web browser processess
	taskkill.exe /IM chrome.exe /F
	taskkill.exe /IM firefox.exe /F
	taskkill.exe /IM edge.exe /F


	#Installs the intel CPU tester, then runs ccleaner and the battery info view
	Start-Process $PSScriptRoot\CPUTester.exe /passive -wait
	start-process "C:\Program Files\Intel Corporation\Intel Processor Diagnostic Tool 64bit\Win-IPDT64.exe" `
		-WorkingDirectory "C:\Program Files\Intel Corporation\Intel Processor Diagnostic Tool 64bit\" -Wait
	Start-Process $PSScriptRoot\CCleaner64.exe -Wait
	Start-Process $PSScriptRoot\BatteryInfoView.exe /stab test.txt 


	#Running sfc scan and placing file onto desktop
	start-process sfc /scannow  -RedirectStandardOutput $PSScriptRoot\sfc.txt
	
	
	#Runs ADW and JRT, waits till jrt is closed 
	#gets adw executablename and runs adw, logs to the root folder of the script
	#$$adwversion =  get-childitem -path C:\ProgramData\chocolatey\lib\adwcleaner\tools\ -filter adw* -Name
	C:\ProgramData\chocolatey\lib\adwcleaner\tools\adwcleaner_8.3.2.exe /eula /scan /noreboot /path $PSScriptRoot 
	Start-Process $PSScriptRoot\get.bat -wait -passthru

	#Runs HDtune, SAS and MBAM and pauses untill mbam is closed.
	start-process $PSScriptRoot\HDTune.exe
	Start-Process "C:\Program Files\SuperAntiSpyware\SuperAntiSpyware.exe" 
	Start-Process "C:\Program Files\Malwarebytes\Anti-Malware\mbam.exe" -Wait


	#wait for imput at the end of the script
	Write-Host -NoNewLine 'Press any key to continue...';
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');


	#reset powercfg settings to pre-MC settings and delete our custom powercfg
	powercfg /setactive $powercfgGUID
	powercfg /delete 11111111-1111-2222-2222-333333333333

}

Function Reports {
	$sfclog = get-content $PSScriptRoot\sfc.txt -Encoding unicode | Select-String -Pattern Resource

	$SASlogLocation = $env:APPDATA + "\SUPERAntiSpyware.com\SUPERAntiSpyware\Logs\"
	$SASlogFileName = Get-ChildItem $SASlogLocation | Sort-Object LastAccessTime  | Select-Object -First 1
	$SASlognameandloc = $SASlogLocation + $SASlogFileName.name
	$SASResults = get-content $SASlognameandloc | Select-String -Pattern detected -CaseSensitive
	$SASResults

	$MbamLogLocation = "C:\ProgramData\Malwarebytes\MBAMService\ScanResults\"
	$MBAMLogName = Get-ChildItem $MbamLogLocation | Sort-Object LastAccessTime -Descending | Select-Object -First 1
	$MBAMLogAndName = $MbamLogLocation + $MBAMLogName.name
	$MBAMResults = get-content $MBAMLogAndName | Select-String -Pattern threatName -CaseSensitive
	$MBAMResults.Count


	$JRTLogAndName = $PSScriptRoot + "\jrt\temp\jrt.txt"
	$JRTResults = get-content $JRTLogAndName | Select-String -Pattern ": [1-9]"
	$JRTResults

	$ADWLogLocation = $PSScriptRoot + "Logs"
	$ADWLogName = Get-ChildItem $ADWLogLocation | Sort-Object LastAccessTime -Descending | Select-Object -First 1
	$MBAMLogAndName = $ADWLogLocation + $ADWLogName.name
	$ADWResults = get-content $MBAMLogAndName | Select-String -Pattern Detected -CaseSensitive
	$ADWResults

	$Batteryinfolog = $PSScriptRoot + "\BatteryInfoView.txt"
	$BatteryResults = get-content $Batteryinfolog | Select-String -Pattern "Battery Health"
	$BatteryResults
	
	#Writes log via another fuction for results to try and keep it cleaner
	"Full Mantiance Checkup Results" | Out-File -FilePath $PSScriptRoot\MCResults.txt
	"==============================" | Out-File -FilePath $PSScriptRoot\MCResults.txt -Append
	"MalwareBytes Scan Results" | Out-File -FilePath $PSScriptRoot\MCResults.txt -Append
	"Total Pups Found: " + $MBAMResults.Count | Out-File -FilePath $PSScriptRoot\MCResults.txt -Append
	"==============================" | Out-File -FilePath $PSScriptRoot\MCResults.txt -Append
	"SAS Scan Results" | Out-File -FilePath $PSScriptRoot\MCResults.txt -Append
	"Tracking Cookies Removed: " + $SASResults | Out-File -FilePath $PSScriptRoot\MCResults.txt -Append
	"==============================" | Out-File -FilePath $PSScriptRoot\MCResults.txt -Append
	"ADW Cleaner Results: " | Out-File -FilePath $PSScriptRoot\MCResults.txt -Append
	$ADWResults | Out-File -FilePath $PSScriptRoot\MCResults.txt -Append
	"==============================" | Out-File -FilePath $PSScriptRoot\MCResults.txt -Append
	"JRT Cleaned up: " | Out-File -FilePath $PSScriptRoot\MCResults.txt -Append
	$JRTResults | Out-File -FilePath $PSScriptRoot\MCResults.txt -Append
	"==============================" | Out-File -FilePath $PSScriptRoot\MCResults.txt -Append
	$BatteryResults | Out-File -FilePath $PSScriptRoot\MCResults.txt -Append
	"==============================" | Out-File -FilePath $PSScriptRoot\MCResults.txt -Append
	$sfclog | Out-File -FilePath $PSScriptRoot\MCResults.txt -Append
	Write-Host -NoNewLine 'Press any key to continue...';
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

}

Function Cleanup {

	Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
	#this removes the install listing for an the migration tool we used during symantec to sophos migration.
	Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SophosMigrationUtility"

	#Uninstalls SAS, MBAM, and ADW
	choco uninstall adwcleaner malwarebytes superantispyware -y 
	#Delete downloaded files needs more testing before i let it delete everything

	#Remove-Item $SUoutpath -Force
	#Remove-Item $DAoutpath -Force
	#Remove-Item $MCzippath -Force
	#Remove-Item $PSScriptRoot/MC -recurse -Force

	#delete Powershell MC Script itself
	#Remove-Item -LiteralPath $MyInvocation.MyCommand.Path -Force
	Write-Host -NoNewLine 'Press any key to continue...';
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
}


# Launch The Program. finnaly after all this code!
Main
