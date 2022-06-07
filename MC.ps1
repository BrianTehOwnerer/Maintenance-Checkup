Clear-Host
##Initialize Variables
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$SecureUpdaterurl = "https://secureupdater.s3.us-east-2.amazonaws.com/downloads/SecureUpdater.msi"
$SUoutpath = "$PSScriptRoot\SecureUpdater.msi"
$DriveAdvisorurl = "https://secureupdater.s3.us-east-2.amazonaws.com/downloads/driveadviser.msi"
$DAoutpath = "$PSScriptRoot\driveadvisor.msi"
$MCZipUrl = "https://secureupdater.s3.us-east-2.amazonaws.com/downloads/mc.zip"
$MCzippath = "$PSScriptRoot\mc.zip"
$endlog = $PSScriptRoot + "\MCResults.txt"

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
		Start-Process $DAoutpath "/quiet"
		Start-Process "C:\Program Files (x86)\Drive Adviser\Drive Adviser.exe"
	}
	Write-Host 'Press any key to continue...';
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
	$powercfgGUID = $powercfgGUID.split(" ")[3]
	#Imports our custom power config as that dumb GUID, then sets it as active
	powercfg /import $PSScriptRoot + "\MCpowercfg.pow" 11111111-1111-2222-2222-333333333333
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
	
	#Running sfc scan and placing file into the SMC cpuLogsResultsFolderSearch
	start-process sfc /scannow -RedirectStandardOutput $PSScriptRoot\sfc.txt -NoNewWindow
	#Starts an old CCleaner (does Tracking cookies, temp and reg without a lot of hastle)
	Start-Process $PSScriptRoot\CCleaner64.exe -Wait
	#runs a batch file that puts the batteryinfo to a text file to parase later
	Start-Process $PSScriptRoot\BatteryInfoView.bat -WorkingDirectory $PSScriptRoot


	#Running sfc scan and placing file onto desktop
	start-process sfc /scannow -RedirectStandardOutput $PSScriptRoot\sfc.txt -NoNewWindow
	
	#runs ADWCLEANER and cleans what it finds while loging to the MC Folder
	Start-Process adwcleaner "/eula /clean /noreboot /path $PSScriptRoot" -passthru -wait


	#Runs ADW and JRT, waits till jrt is closed 
	Start-Process $PSScriptRoot\get.bat -wait -passthru

	#Runs HDtune, SAS and MBAM and pauses untill mbam is closed.
	start-process $PSScriptRoot\HDTune.exe
	Start-Process "C:\Program Files\SuperAntiSpyware\SuperAntiSpyware.exe" 
	Start-Process "C:\Program Files\Malwarebytes\Anti-Malware\mbam.exe" -Wait

	#reset powercfg settings to pre-MC settings and delete our custom powercfg
	powercfg /setactive $powercfgGUID.split(" ")[3]
	powercfg /delete 11111111-1111-2222-2222-333333333333

	#wait for imput at the end of the script
	Write-Host -NoNewLine 'Press any key to continue...';
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

}

Function Reports {
	if (Test-Path -Path "C:\Program Files\Sophos\Sophos File Scanner\SophosFS.exe") {
		$SohposRegName = Get-ItemPropertyValue -Path `
			'HKLM:\SOFTWARE\WOW6432Node\Sophos\Management Communications System\' `
			-Name ComputerNameOverride
		$SophosInstalled = "Sophos is Installed"
	}
	else {
		$SophosInstalled = "Sophos is Not Installed"
		$SohposRegName = "Sophos is Not Installed"
	}


	$sfclog = get-content $PSScriptRoot\sfc.txt -Encoding unicode | Select-String -Pattern Resource

	#Im only going to comment one of these, as they are all the same.
	#This grabs the location of the SAS Logs, ie the cpuLogsResultsFolderSearch they are in.
	$SASlogLocation = $env:APPDATA + "\SUPERAntiSpyware.com\SUPERAntiSpyware\Logs\"
	#This line grabs all the fimes, and then grabs the newest file from the list (ie the one that was just created by our last scan)
	$SASlogFileName = Get-ChildItem $SASlogLocation | Sort-Object LastAccessTime  | Select-Object -First 1
	#And then puts them together for the full file path and name (C:\blabla\bla\log.txt)
	$SASlognameandloc = $SASlogLocation + $SASlogFileName.name
	#This reads through the file looking for the patterern "detected" and pulling out all lines with that pattern
	$SASResults = get-content $SASlognameandloc | Select-String -Pattern detected -CaseSensitive


	$MbamLogLocation = "C:\ProgramData\Malwarebytes\MBAMService\ScanResults\"
	$MBAMLogName = Get-ChildItem $MbamLogLocation | Sort-Object LastAccessTime -Descending | Select-Object -First 1
	$MBAMLogAndName = $MbamLogLocation + $MBAMLogName.name
	$MBAMResults = get-content $MBAMLogAndName | Select-String -Pattern threatName -CaseSensitive


	$JRTLogAndName = $PSScriptRoot + "\jrt\temp\jrt.txt"
	$JRTResults = get-content $JRTLogAndName | Select-String -Pattern ": [1-9]"

    
	$ADWLogLocation = $PSScriptRoot + "\Logs\"
	$ADWLogName = Get-ChildItem $ADWLogLocation | Sort-Object LastAccessTime -Descending | Select-Object -First 1
	$ADWLogAndName = $ADWLogLocation + $ADWLogName.name
	$ADWResults = get-content -Literalpath $ADWLogAndName | Select-String -Pattern Detected -CaseSensitive


	$Batteryinfolog = $PSScriptRoot + "\BatteryInfoView.txt"
	$BatteryResults = get-content $Batteryinfolog | Select-String -Pattern "Battery Health"
	#check memory diagnostics results, if empty writes "no resutls found"
	$Memdiagresults = (get-eventlog -logname system -Source "Microsoft-Windows-MemoryDiagnostics-Results" -newest 1)
	$MemdiagresultsMessage = $Memdiagresults.Message
	$MemdiagresultsTime = $Memdiagresults.Time
	if (!$Memdiagresults) { 
		$MemdiagresultsMessage = "No results found for Windows Memory Diagnostics" 
		$MemdiagresultsTime = "No results found for Windows Memory Diagnostics"
	}
	#This block is a bit of a mess, so I put it into its own function.
	#It loops through the processor diagnostics folder and snags all the RESULTS files
	#Then searches for the word fail, if it finds it it adds that filename to a list
		
	$CpuLogsResultsFolderSearch = "C:\Program Files\Intel Corporation\Intel Processor Diagnostic Tool 64bit\*"
	$CpuLogsandFilenames = Get-ChildItem -Path $cpuLogsResultsFolderSearch -Include *_Results.txt
	$CpuLogsResultsFolderLiteral = "C:\Program Files\Intel Corporation\Intel Processor Diagnostic Tool 64bit\"
	CpuTestFailures = "CPU Test Results Failed"
	
	foreach ( $filename in $CpuLogsandFilenames.name) {
		$cpulogs = $CpuLogsResultsFolderLiteral + $filename 
		if (get-content -literalpath $cpulogs | Select-String -Pattern Fail) {
			$CpuTestFailures += Write-Output $filename `n
		}
	}
	$CpuTestFailures = $CpuTestFailures -replace "genintel_1_Results.txt", "Not an intel CPU"
	$CpuTestFailures = $CpuTestFailures -replace "brandstring_1_Results.txt", "Branding string"
	$CpuTestFailures = $CpuTestFailures -replace "cache_1_Results.txt", "Cache"
	$CpuTestFailures = $CpuTestFailures -replace "mmxsse_1_Results.txt", "MMXSSE"
	$CpuTestFailures = $CpuTestFailures -replace "imc_1_Results.txt", "IMC"
	$CpuTestFailures = $CpuTestFailures -replace "Math_PrimeNum_Parallel_Math_1_Results.txt", "Prime Number Generation"
	$CpuTestFailures = $CpuTestFailures -replace "Parallel_PrimeNum_1_Results.txt", "Prime Number Generation"
	$CpuTestFailures = $CpuTestFailures -replace "Math_PrimeNum_Parallel_PrimeNum_1_Results.txt", "Prime Number Generation"
	$CpuTestFailures = $CpuTestFailures -replace "Math_FP_Parallel_Math_1_Results.txt", "Floating Point Math"
	$CpuTestFailures = $CpuTestFailures -replace "Math_FP_Parallel_FP_1_Results.txt", "Floating Point Math"
	$CpuTestFailures = $CpuTestFailures -replace "Parallel_FP_1_Results.txt", "Floating Point Math"
	$CpuTestFailures = $CpuTestFailures -replace "AVX_Parallel_Math_1_Results.txt FMA3_Parallel_Math_1_Results.txt", "Math"
	$CpuTestFailures = $CpuTestFailures -replace "Parallel_GPUStressW_1_Results.txt", "Software Rendering Stress Test"
	$CpuTestFailures = $CpuTestFailures -replace "AVX_Parallel_GPUStressW_1_Results.txt" , "Software Rendering Stress Test"
	$CpuTestFailures = $CpuTestFailures -replace "FMA3_Parallel_GPUStressW_1_Results.txt", "Software Rendering Stress Test"
	$CpuTestFailures = $CpuTestFailures -replace "dgemm_1_Results.txt", "CPU Load Stressing"
	$CpuTestFailures = $CpuTestFailures -replace "cpufreq_1_Results.txt", "CPU Frequency Changing (Amd CPUs fail regularly)"
	$CpuTestFailures = $CpuTestFailures -replace "pch_1_Results.txt", "PCH"
	$CpuTestFailures = $CpuTestFailures -replace "spbc_1_Results.txt", "SPBC"
	$CpuTestFailures = $CpuTestFailures -replace "Temperature_Results.txt", "Tempurature"


	#Writes log via another fuction for results to try and keep it cleaner
	"Full Mantiance Checkup Results" | Out-File -FilePath $endlog
	$SophosInstalled | Out-File -FilePath $endlog -Append
	"With the name of " + $SohposRegName | Out-File -FilePath $endlog -Append
	"==============================" | Out-File -FilePath $endlog -Append
	"Memory diagnostics ran at " + $MemdiagresultsTime | Out-File -FilePath $endlog -Append
	$MemdiagresultsMessage | Out-File -FilePath $endlog -Append
	"==============================" | Out-File -FilePath $endlog -Append
	"MalwareBytes Scan Results" | Out-File -FilePath $endlog -Append
	"Total Pups Found: " + $MBAMResults.Count | Out-File -FilePath $endlog -Append
	"==============================" | Out-File -FilePath $endlog -Append
	"SAS Scan Results" | Out-File -FilePath $endlog -Append
	$SASResults[0] | Out-File -FilePath $endlog -Append
	$SASResults[1] | Out-File -FilePath $endlog -Append
	$SASResults[2] | Out-File -FilePath $endlog -Append
	"==============================" | Out-File -FilePath $endlog -Append
	"ADW Cleaner Results: " | Out-File -FilePath $endlog -Append
	$ADWResults | Out-File -FilePath $endlog -Append
	"==============================" | Out-File -FilePath $endlog -Append
	"JRT Cleaned up: " | Out-File -FilePath $endlog -Append
	$JRTResults | Out-File -FilePath $endlog -Append
	"==============================" | Out-File -FilePath $endlog -Append
	"Battery Health state" | Out-File -FilePath $endlog -Append
	$BatteryResults | Out-File -FilePath $endlog -Append
	"==============================" | Out-File -FilePath $endlog -Append
	"SFC Scan Results" | Out-File -FilePath $endlog -Append
	$sfclog | Out-File -FilePath $endlog -Append
	"==============================" | Out-File -FilePath $endlog -Append
	$CpuTestFailures | Out-File -FilePath $endlog -Append 
	"==============================" | Out-File -FilePath $endlog -Append
	"Full List Of MBAM Threats Cleaned up"  | Out-File -FilePath $endlog -Append
	$MBAMResults | Out-File -FilePath $endlog -Append


	#opens notepad with the log file.
	notepad.exe $endlog
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
