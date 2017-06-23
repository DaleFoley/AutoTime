#
#AutoTime.ps1
#
#Author: Dale Foley
#Date: 2017/02/04
#Description: The purpose of this script is to automate the retrieval of date and time from a NTP server and
#             apply it to the system date and time.
#-------------------------------------------------------------------------------------------------------
#Updated: 2017/06/23 11:47:00

Set-StrictMode -Version 2.0

#Function Definitions
function logInformation([string]$msg, [string]$logFile)
{
	[string]$userDirectory = $env:USERPROFILE
	[string]$logsDirectory = $userDirectory  + "\logs\AutoTime\"

	$timeStamp = getDateTime
	
	if(-Not(Test-Path $logsDirectory)) {New-Item $logsDirectory -ItemType Directory}
		
	Write-Output ($timeStamp + $msg) | Out-File $logFile -Append
}

function startWinTime()
{
	try
	{
		logInformation "Checking if W32Time is running" $global:logFile
		if((Get-Service -Name W32Time).Status -ne 'Running')
		{
			logInformation "W32Time not running, attempting to start it...." $global:logFile
			Start-Service -Name W32Time
            
            if((Get-Service -Name W32Time).Status -ne 'Running')
            {
                logInformation "Failed to start W32Time." $global:logFile
            }
            else
            {
                logInformation "W32Time is now running" $global:logFile
            }
		}
        else
        {
            logInformation "W32Time is already running" $global:logFile
        }
	}
	catch
	{
		logInformation $msg $sErrorLogFile
	}
}

function getDateTime()
{
		$timeStamp = '['
		$timeStamp += Get-Date -Format 'yyyy-mm-dd HH:mm:ss:fffffff'
		$timeStamp += ']'

		return $timeStamp
}

function getPSVersion()
{
	$sPSVersion = $PSVersionTable.PSVersion.Major.ToString()
	$sPSVersion += '.' + $PSVersionTable.PSVersion.Minor.ToString()
	$sPSVersion += ' (build ' + $PSVersionTable.PSVersion.Build.ToString() + ')'

	return $sPSVersion
}

function testNTPServers([string[]]$arr_sNTPServers)
{
    [string[]]$return = $null

    logInformation "Testing NTP server availability..." $global:logFile

    $ping = New-Object System.Net.NetworkInformation.Ping

    foreach($value in $arr_sNTPServers)
    {
        $reply = $ping.Send($value, 2000)
        
        if($reply.Status -eq "Success")
        {
            $msg = $value + " is up!"
            logInformation $msg $global:logFile
            $return += $value   
        }
        else
        {
            $msg = $value + " is down!"
            logInformation $msg $global:logFile
        }
    }

    $return
}

function getTime()
{
    [UInt32]$Seconds = $Null

    foreach($ntpServer in $global:arr_sNTPServersAvailable)
    {
        $NTPData = New-Object byte[] 48 
        $NTPData[0] = 27 # Request header: 00 = No Leap Warning; 011 = Version 3; 011 = Client Mode; 00011011 = 27

        $Socket = New-Object System.Net.Sockets.Socket ('InterNetwork', 'Dgram', 'Udp')
        $Socket.SendTimeout = 10000 #ms
        $Socket.ReceiveTimeout = 10000 #ms
        $Socket.Connect($ntpServer, 123)

        $Null = $Socket.Send($NTPData)
        $Null = $Socket.Receive($NTPData)

        $Socket.Shutdown('Both')
        $Socket.Close()

        $Seconds = [BitConverter]::ToUInt32( $NTPData[43..40], 0 )

        if ($Seconds -gt 0)
        {
            break
        }
    }

    if($Seconds -eq $Null)
    {
        $Seconds
    }
    else
    {
        ([datetime]'1/1/1900').AddSeconds( $Seconds ).ToLocalTime()
    }
}

function waitForInternet([int]$Timeout, [string]$server)
{
    [bool]$Return = $False

    $ping = New-Object System.Net.NetworkInformation.Ping
    $reply = $Null
    $replyStatus = $Null

    $stopwatch = New-Object System.Diagnostics.Stopwatch
    $stopwatch.Start()

    do
    {
        if($stopwatch.ElapsedMilliseconds -gt $Timeout)
        {
            break
        }

        $reply = $ping.Send($server, $Timeout)
        $replyStatus = $reply.Status

    } until ($replyStatus -eq "Success")

    if($replyStatus -eq "Success")
    {
        $Return = $True
    }

    $Return
}

try
{
	#------------Startup App Params-----------------------
	$sPSVersion = getPSVersion
	
	$sStartupMessage = "Starting... PowerShell Version: " + $sPSVersion + "------------New Instance------------"
	$global:logFile = "AutoTime.log"
	$global:sErrorLogFile = "Error.log"
    [string[]]$arr_sNTPServers = "0.au.pool.ntp.org",
                                 "1.au.pool.ntp.org",
                                 "2.au.pool.ntp.org",
                                 "3.au.pool.ntp.org",
                                 "ntp.internode.on.net"
    [string[]]$global:arr_sNTPServersAvailable = @()

    [int]$pingWaitForInternetTimeout = 10000
    [string]$pingWaitForInternetHost = "8.8.8.8"
	#--------------------------------------------------------
	
	logInformation $sStartupMessage $global:logFile

    if(!(waitForInternet $pingWaitForInternetTimeout $pingWaitForInternetHost))
    {
        $msg = "Failed to get internet in the alloted time of: " + $pingWaitForInternetTimeout.ToString() + "ms"
        logInformation $msg $global:logFile
    }

    $global:arr_sNTPServersAvailable = testNTPServers $arr_sNTPServers 
    $DateTime = getTime

    if($DateTime -eq $Null)
    {
        logInformation "Failed to get a time from the available NTP Servers. Exiting process..." $global:logFile
        exit
    }
    
    logInformation $DateTime $global:logFile
    Set-Date $DateTime
}
catch
{
	$msg = $_
	logInformation $msg $sErrorLogFile    
}