#
#AutoTime.ps1
#
#Author: Dale Foley
#Date: 2017/02/04
#Description: The purpose of this script is to automate the retrieval of date and time from a NTP server 
#             apply it to the system date and time.
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
}

function startWinTime()
{
	try
	{
		logInformation "Checking if W32Time is running" $global:sLogFile
		if((Get-Service -Name W32Time).Status -ne 'Running')
		{
			logInformation "W32Time not running, attempting to start it...." $global:sLogFile
			Start-Service -Name W32Time
            
            if((Get-Service -Name W32Time).Status -ne 'Running')
            {
                logInformation "Failed to start W32Time." $global:sLogFile
            }
            else
            {
                logInformation "W32Time is now running" $global:sLogFile
            }
		}
        else
        {
            logInformation "W32Time is already running" $global:sLogFile
        }
	}
	catch
	{
		$sMsg = $_
		logInformation $sMsg $sErrorLogFile
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

function testNTPServer([string[]]$arr_sNTPServers)
{
    logInformation "Testing NTP server availability..." $global:sLogFile

    foreach($value in $arr_sNTPServers)
    {
        if(Test-Connection -Cn $value -BufferSize 16 -Count 1 -ea 0 -Quiet)
        {
            $sMsg = $value + " is up!"
            logInformation $sMsg $global:sLogFile
            $global:arr_sNTPServersAvailable += $value
        }
        else
        {
            $sMsg = $value + " is down!"
            logInformation $sMsg $global:sLogFile
        }
    }    
}

function getTime($server)
{
    $NTPData = New-Object byte[] 48 
    $NTPData[0] = 27 # Request header: 00 = No Leap Warning; 011 = Version 3; 011 = Client Mode; 00011011 = 27

    $Socket = New-Object System.Net.Sockets.Socket ('InterNetwork', 'Dgram', 'Udp')
    $Socket.SendTimeout = 10000 #ms
    $Socket.ReceiveTimeout = 10000 #ms
    $Socket.Connect($server, 123)

    $Null = $Socket.Send($NTPData)
    $Null = $Socket.Receive($NTPData)

    $Socket.Shutdown('Both')
    $Socket.Close()

    $Seconds = [BitConverter]::ToUInt32( $NTPData[43..40], 0 )

    return ([datetime]'1/1/1900').AddSeconds( $Seconds ).ToLocalTime()
}

try
{
	#------------Startup App Params-----------------------
	$sPSVersion = getPSVersion
	
	$sStartupMessage = "Starting... PowerShell Version: " + $sPSVersion + "------------New Instance------------"
	$global:sLogFile = "AutoTime.log"
	$global:sErrorLogFile = "Error.log"
    [string[]]$arr_sNTPServers = "0.au.pool.ntp.org",
                                 "1.au.pool.ntp.org",
                                 "2.au.pool.ntp.org",
                                 "3.au.pool.ntp.org",
                                 "ntp.internode.on.net"
    [string[]]$global:arr_sNTPServersAvailable = @()
	#--------------------------------------------------------
	
	logInformation $sStartupMessage $global:sLogFile

	startWinTime #Start the W32Time Servive, required to perform a time sync
    testNTPServer $arr_sNTPServers #Test an array of hostnames that belong to known NTP servers
    $DateTime = getTime $global:arr_sNTPServersAvailable[0]
    logInformation $DateTime $global:sLogFile
    Set-Date $DateTime
}
catch
{
	$sMsg = $_
	logInformation $sMsg $sErrorLogFile    
}