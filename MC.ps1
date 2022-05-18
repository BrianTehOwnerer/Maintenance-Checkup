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
	start-process "C:\Program Files\Intel Corporation\Intel Processor Diagnostic Tool 64bit\Win-IPDT64.exe" -WorkingDirectory "C:\Program Files\Intel Corporation\Intel Processor Diagnostic Tool 64bit\" -Wait
	Start-Process $PSScriptRoot\CCleaner64.exe -Wait
	Start-Process $PSScriptRoot\BatteryInfoView.exe -Wait 
	#Start-Process $PSScriptRoot\BatteryInfoView.exe /scomma $PSScriptRoot\Batteryinfo.csv

	#Running sfc scan and placing file onto desktop
	start-process sfc /scannow  -RedirectStandardOutput $PSScriptRoot\sfc.txt 

	#Runs HDtune, SAS and MBAM and pauses untill mbam is closed.
	start-process $PSScriptRoot\HDTune.exe
	Start-Process "C:\Program Files\SuperAntiSpyware\SuperAntiSpyware.exe" 
	Start-Process "C:\Program Files\Malwarebytes\Anti-Malware\mbam.exe" -Wait

	#reset powercfg settings to pre-MC settings and delete our custom powercfg
	powercfg /setactive $powercfgGUID
	powercfg /delete 11111111-1111-2222-2222-333333333333

	#Runs ADW and JRT, waits till jrt is closed 
	#gets adw executablename and runs adw, logs to the root folder of the script
	#$$adwversion =  get-childitem -path C:\ProgramData\chocolatey\lib\adwcleaner\tools\ -filter adw* -Name
	C:\ProgramData\chocolatey\lib\adwcleaner\tools\adwcleaner_8.3.2.exe /eula /scan /noreboot /path $PSScriptRoot 
	Start-Process $PSScriptRoot\jrt.exe -wait

	#wait for imput at the end of the script
	Write-Host -NoNewLine 'Press any key to continue...';
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

}

Function Reports {
	#https://techgenix.com/read-text-file-powershell/
	#Nothing to report yet...
	$sfcreport = Get-Content $PSScriptRoot\sfc.txt
	$sfcreport | Select-Object -last 5

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
