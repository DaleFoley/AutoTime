#
#AutoTime.ps1
#
#Author: Dale Foley
#Date: 2017/02/04
#Description: The purpose of this script is to automate the retrieval of date and time from a NTP server 
#						 apply it to the system date and time.
#-------------------------------------------------------------------------------------------------------

#Function Definitions
function logInformation([string]$sMsg, [string]$sLogFile)
{
	#----------------Log Location Parameters------------------
	$sUserDirectory = $env:USERPROFILE

	$sLogLogsDir = $sUserDirectory  + "\logs"
	$sLogAutoTimeDir = $sLogLogsDir  + "\AutoTime\"

	$sLogDirPath = $sLogAutoTimeDir 
	$sLogPath = 	$sLogDirPath + $sLogFile
	#------------------------------------------------------------

	$sTimeStamp = getDateTime
	
	#If logs directories and file do not exist, create them.
	if(-Not(Test-Path $sLogLogsDir)) {New-Item $sLogLogsDir -ItemType Directory}
	if(-Not(Test-Path $sLogAutoTimeDir)) {New-Item $sLogAutoTimeDir -ItemType Directory}
	if(-Not(Test-Path $sLogPath))  {New-Item $sLogPath -ItemType File}
		
	Write-Output ($sTimeStamp + $sMsg) | Out-File $sLogPath -Append
	Write-Output ([System.Environment]::NewLine) | Out-File $sLogPath -Append
}

function startWinTime()
{
	try
	{
		if((Get-Service -Name W32Time).Status -ne 'Running')
		{
			
		}
	}
	catch
	{

	}
}

function getDateTime()
{
		$sTimeStamp = '['
		$sTimeStamp += Get-Date -Format 'yyyy-mm-dd HH:mm:ss:fffffff'
		$sTimeStamp += ']'

		return $sTimeStamp
}

function getPSVersion()
{
	$sPSVersion = $PSVersionTable.PSVersion.Major.ToString()
	$sPSVersion += '.' + $PSVersionTable.PSVersion.Minor.ToString()
	$sPSVersion += ' (build ' + $PSVersionTable.PSVersion.Build.ToString() + ')'

	return $sPSVersion
}

try
{
	#------------Startup App Params-----------------------
	$sPSVersion = getPSVersion
	#--------------------------------------------------------

	$sStartupMessage = "Starting... PowerShell Version: " + $sPSVersion
	$sLogFile = "AutoTime.log"
	$sErrorLogFile = "Error.log"
	Throw [System.Exception] "test death"
	logInformation $sStartupMessage $sLogFile
}
catch
{
	$sMsg = $_
	logInformation $sMsg $sErrorLogFile
}