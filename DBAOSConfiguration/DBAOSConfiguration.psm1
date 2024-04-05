#
# AAWHOSConfiguration.psm1
# TODO: Add function to get FQDN of an object.
Function Write-Log {
<# 
  .SYNOPSIS 
  Redirects output to both a log file and the powershell host screen 
  .DESCRIPTION 
  Redirects output to both a log file and the powershell host screen, attaches a log message type (info, warn, error, etc) and time stamp
  .EXAMPLE 
  Write-Log -Level INFO -Message "The Test was a success" -Logfile "C:\Temp\InstallationLogFile.txt"
  .EXAMPLE 
  Write-Log -Message "The Test was a success" 
  .PARAMETER Level 
  Describes the level of the message.  INFO, WARN, ERROR, FATAL, DEBUG.  Default value is INFO
  .PARAMETER Message
  The actual message to log
  .PARAMETER LogFile
  The path to the log file
#> 
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
        [String]$Level = "INFO",
        [Parameter(Mandatory=$True,Position=1,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$Message,
        [Parameter(Mandatory=$False,Position=2,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string] $LogFile
    )

    If(!$LogFile -and !$Global:LogFile)
    {
		IF(!(Test-path ".\Logs"))
		{
			New-Item ".\Logs" -ItemType Directory
		}
        $Stamp = Get-Date -Format yyyymmdd_hhMMss
		$LogFile = ".\Logs\LogFile_$Stamp.txt"
		$Global:LogFile = $LogFile
    }
	ElseIf(!$Logfile)
	{
		$LogFile = $Global:LogFile
	}

	if(!(Test-Path -Path $LogFile))
	{
		New-Item $LogFile -Type File | Out-Null
	}

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    Add-Content $logfile -Value $Line
    
    If($Level -in ("ERROR","FATAL"))
    {
        Throw $Line 
		stop
    }
    elseif($Level -in ("WARN"))
    {
        Write-Host $Line -ForegroundColor Yellow
    }
	elseif($Level -in ("DEBUG"))
    {
        Write-Host $Line -ForegroundColor Cyan
    }
    else
    {
        Write-Host $Line -ForegroundColor Gray
    }
}

# TODO, BLOCKED BY MCAFFE Antirvirus protection for worms and mass mailings.  Awesome.
Function Send-EmailStatus
{
<# 
.SYNOPSIS 
	Send and email
.DESCRIPTION 
	Send a status update email.
.EXAMPLE 
  Send-EmailStatus -From "S.T84@somegmail.com" -To "DBAs@dbas.com" -Subject "This is the subject" -Body "Body of email"
.PARAMETER From 
  Who the email is coming from, can be a donotreply address.
.PARAMETER TO
	Who the email is sent to.
.PARAMETER Subject
	Subject of the email.
.PARAMETER Body
	Body of the email.
.OUTPUT
	Sends an email.
#> 
    [cmdletbinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What Drive Letter do you want for the drive')]
        [string] $From,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What Drive Letter do you want for the drive')]
        [string] $To,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What Drive Letter do you want for the drive')]
        [string] $Subject,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What Drive Letter do you want for the drive')]
        [string] $Body
    )
	$anonUser = "anonymous"
	$anonPass = ConvertTo-SecureString "anonymous" -AsPlainText -Force
	$anonCred = New-Object System.Management.Automation.PSCredential($anonUser, $anonPass)
	Send-MailMessage -From $From -To $to -Subject $Subject -Body $body -SmtpServer "exchange.yourExchangeServerHere.com" -Port 25 -Credential $anonCred
}
Function Get-DomainAccountSID
{
<# 
  .SYNOPSIS 
  Retrives the Active Directory SID for the supplied account. 
  .DESCRIPTION 
  Retrives the Active Directory SID for the supplied account. The Sid is returned as a String object.
  .EXAMPLE 
  Get-DomainAccountSID -DomainAccountName AAWH\SMokszycki
  .EXAMPLE 
  Get-DomainAccountSID -DomainAccountName "AAWH\SMokszycki"
  .PARAMETER DomainAccountName 
  The fully qualified domain account name to retrive.
#> 
    [cmdletbinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What Drive Letter do you want for the drive')]
        [string] $DomainAccountName
    )

    try{
        $objUser = New-Object System.Security.Principal.NTAccount($DomainAccountName)
        $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
        $sidstr = $strSID.Value.ToString()
        return $sidstr
    }
    catch
    {
        $sidstr = $null
        return $sidstr
    }
}

function Get-RequiredWindowsFeature
{
<# 
  .SYNOPSIS 
  Checks if a windows feature is already installed/enabled on a target host.
  .DESCRIPTION 
  This function returns $true or $false for the selected windows feature on the target host
  .EXAMPLE 
  Get-RequiredWindowsFeature -Hostname SXDCSQLAO04 -WindowsFeatureName Net-Framework-Core
  returns $true
  .PARAMETER HostName
  The name of the target host.
  .PARAMETER WindowsFeatureName
  The name of the windows feature to check for.
#> 
    param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
        [string] $HostName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
        [string] $WindowsFeatureName
    )

    If( (Get-WindowsFeature -ComputerName $HostName -Name $WindowsFeatureName).InstallState -eq 'Installed')
    {
        return $false
    }
    else
    {
        return $true
    }
}

function Install-RequiredWindowsFeature
{
<# 
.SYNOPSIS 
	Installs a windows feature on a target server.
.DESCRIPTION 
	This is mostly a wrapper around the Microsoft commandlet Install-WindowsFeature.  Adds additional error handling and logging for company.
.PARAMETER WindowsFeatureName
	Name of the windows feature to be installed
.PARAMETER WindowsOSMediaPath
	Path to the windows OS media, used if OS source is not set in AD for the host's OU and GPO settings.
.PARAMETER HostName
	The name of the host that will be affected.
.OUTPUTS 
	None
.EXAMPLE 
	Install-RequiredWindowsFeature -HostName MyFavoriteComputer -WindowsFeatureName NET-Framework-Core -WindowsOSMediaPath "D:\Windows\sxs"
#>

    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
        [string] $HostName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
        [string] $WindowsFeatureName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
        [string] $WindowsOSMediaPath
    )
   #Verify Feature is not already installed.
   [Bool] $installFeature = Get-RequiredWindowsFeature -HostName $HostName -WindowsFeatureName $WindowsFeatureName
    if($installFeature)
    {
        Write-Log -Level INFO "Attempting to Install Windows Feature: $WindowsFeatureName on $HostName..."
        try
        {
			$InstallResult = Install-WindowsFeature -Name $WindowsFeatureName -ComputerName $HostName -Source $WindowsOSMediaPath -IncludeManagementTools -ErrorAction STOP
        }
        catch
        {
            Write-Log -Level Error -Message "Error Installing Windows Feature: $WindowsFeatureName on Host: $HostName.  Stopping install."
        }
        #Verify Install.  Installs can fail without throwing an error.  Validate by checking the install result success status.
         If($InstallResult.Success)
        {
            Write-Log -Level INFO -Message "Successfully installed Windows Feature: $WindowsFeatureName on Host: $HostName..."
         }
        else
        {
            Write-Log -Level ERROR -Message "Failed component Windows Feature: $WindowsFeatureName on Host:$HostName. Stopping install."
        }
    }
    else
    {
        Write-Log -Level INFO -Message "Windows Feature: $WindowsFeatureName is already installed on Host: $HostName. Skipping Install..."
    }
	Write-Log -Level INFO -Message "Install Successful for Windows Feature: $WindowsFeatureName on Host: $HostName"
   
}



function Format-SQLDisk
{
<# 
  .SYNOPSIS 
  Formats RAW disks for SQL server specific installs.
  .DESCRIPTION 
  Works remotely, Formats target drive for SQL server installs with Alignment of 1MB and a block size of 64 KB to optimize read/writes of sql server extents.
  .EXAMPLE 
  Format-SQLDisk -DriveLetter 'J' -DriveLabel "Data" -DiskNumber 3 -HostName "SXDCTestSQLServer"
  .PARAMETER DriveLetter
  Drive Letter to assign to the target disk on the target host.
  .PARAMETER DriveLabel
  The text Label to assign to the target drive
  .PARAMETER DiskNumber
  The OS drive number assigned to the target disk.
  .PARAMETER HostName
  Target host the disk lives on.
#>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What Drive Letter do you want for the drive')]
        [string] $DriveLetter,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Please provide a label for the drive.')]
        [string] $DriveLabel,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What what is the disk number on the drive?')]
        [int] $DiskNumber,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
        [string] $HostName

    )
    try
    {
        Write-Log -LeveL INFO -Message "attempting to initialize and format disk $DiskNumber $DriveLetter...."
        Initialize-Disk -Number $DiskNumber -PartitionStyle GPT -CimSession $HostName
        Write-Log -Level INFO -Message "Disk $DiskNumber initialized successfully...sleeping 3 seconds"
        sleep 3
        Write-Log -Level INFO -Message "Formating Disk $DiskNumber as $DriveLetter, $DriveLabel"
        New-Partition -DiskNumber $DiskNumber -UseMaximumSize -DriveLetter $DriveLetter -CimSession $HostName | Format-Volume -CimSession $HostName -FileSystem NTFS -NewFileSystemLabel $DriveLabel -AllocationUnitSize 65536 -Confirm:$false -Force | Out-Null
        Write-Log -Level INFO -Message "Disk $DiskNumber Available."
    }
    catch
    {
        Throw "failed to initalize disk $DiskNumber"
    }
}
Function Import-InstallConfiguration
{
<# 
.SYNOPSIS 
	Pulls in all install configuration data from a csv file. 
.DESCRIPTION 
	reads the the sqlconfig.csv file to pull a new sql server.
.EXAMPLE 
	Import-InstallConfiguration -ConfigurationFilePath "C:\Temp\Config.csv"
	returns an imported csv file.
.PARAMETER ConfigurationFilePath 
	Path to the install config file
.OUTPUT
	imported csv file.
#> 
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Please provide the file path to the SQLServerConfiguration.csv file:')]
        [string] $ConfigurationFilePath
    ) 
    $fileData = Import-Csv -Path $ConfigurationFilePath
	if($fileData -ne $null)
	{
		return $fileData
	}
	else
	{
		Throw "Unable to import csv file from $ConfigurationFilePath!"
	}
}
function Get-OSMedia
{
<# 
.SYNOPSIS 
	Find the OS Media path on the local host.
.DESCRIPTION 
	Finds the location of the os media on the local host. If not found this will copy the media to the local server and return the location.
.EXAMPLE 
	Get-OSMedia -Hostname MyComputerName -WindowsOSMediaPath "\\Network\Path\To\OS\Iso" -DestinationPath "C:\Temp\PlaceToPutTheIsoFile" 
.PARAMETER HostName
	The Name of host to create folders on.
.PARAMETER WindowsOsMediaPath 
	Network location of Windows Media, not the local host
.PARAMETER DestinationPath
	Path the local host to store the os media.
.OUTPUT
	String
 .
#>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the target server?')]
        [string] $HostName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the target server?')]
        [string] $WindowsOSMediaPath,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the target server?')]
        [string] $DestinationPath   
    )

    $OsFileReturn = "D:\Sources\sxs"

    #check if os disk in default D:\ drive
    If(!(test-path "\\$HostName\D$\sources\sxs"))
    {
        #Drive not found, copy iso
        $OsFileReturn = Copy-IsoFile -Hostname $HostName -MediaPath $WindowsOSMediaPath -DestinationPath $DestinationPath -DestinationISOName "Windows"
    }

    return $OsFileReturn
}

function Copy-IsoFile
{
<# 
  .SYNOPSIS 
	Copies and iso file to a target location.
  .DESCRIPTION 
	Copies an is
  .EXAMPLE 
	Get-OSMedia -Hostname MyComputerName -WindowsOSMediaPath "\\Network\Path\To\OS\Iso" -DestinationPath "C:\Temp\PlaceToPutTheIsoFile" 
  .PARAMETER HostName
	The Name of host to create folders on.
  .PARAMETER MediaPath 
	Network location of the Media, not the local host
  .PARAMETER DestinationPath
	Path the local host to store the media.
  .PARAMETER DestinationISOName
	Name to give the ISO file.  .ISO will be automatically appended to the name supplied.
#>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the target server?')]
        [string] $HostName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the target server?')]
        [string] $MediaPath,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the target server?')]
        [string] $DestinationPath,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the target server?')]
        [string] $DestinationISOName 
    )
    try
    {
        
        [string]$DestinationPathShare = (Join-path -path "\\$HostName\" -childpath $DestinationPath.Replace(":\","$\"))
        If(!(test-path -Path $DestinationPathShare))
        {
            New-Item -Path $DestinationPathShare -ItemType Directory |Out-Null
        }
        If(!($DestinationPathShare.EndsWith('\')))
        {
            $DestinationPathShare = $DestinationPathShare +'\'
        }
        if(!($DestinationPath.EndsWith('\')))
        {
            $DestinationPath = $DestinationPath +'\'
        }
        $OSFile = $DestinationPathShare +$DestinationISOName+".iso"
        Write-Log -Level INFO -Message "Copying Media: $MediaPath to Destination $DestinationPathShare as iso: $DestinationISOName.iso"
        Start-BitsTransfer -Source $MediaPath -Destination $OSFile -Description $DestinationISOName -DisplayName $DestinationISOName
        Write-Log -Level INFO -Message "Copying Media to $DestinationPathShare Successful..."
        $OSFile = $DestinationPath + $DestinationISOName + ".iso"
        Return $OSFile
    }
    catch
    {
        $ExecptionMessage = $_.Exception.Message
        $ExceptionItem = $_.Excepetion.ItemName
        Write-Log -Level ERROR -Message "Copying media to $DestinationPathShare FAILED. $ExecptionMessage $ExceptionItem"
    }
}

function Grant-CarbonSecurityPolicy
{
	[cmdletbinding()]
	param
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What Account needs Security Policy updates?')]
		[string] $identity,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What Account needs Security Policy updates?')]
		[ValidateSet("SeAssignPrimaryTokenPrivilege", "SeAuditPrivilege","SeBackupPrivilege","SeBatchLogonRight",
			"SeChangeNotifyPrivilege","SeCreateGlobalPrivilege","SeCreatePagefilePrivilege","SeCreatePermanentPrivilege","SeCreateSymbolicLinkPrivilege","SeCreateTokenPrivilege",
			"SeDebugPrivilege",
			"SeDenyBatchLogonRight","SeDenyInteractiveLogonRight","SeDenyNetworkLogonRight","SeDenyRemoteInteractiveLogonRight","SeDenyServiceLogonRight","SeEnableDelegationPrivilege",
			"SeImpersonatePrivilege","SeIncreaseBasePriorityPrivilege","SeIncreaseQuotaPrivilege","SeIncreaseWorkingSetPrivilege","SeInteractiveLogonRight","SeLoadDriverPrivilege",
			"SeLockMemoryPrivilege","SeMachineAccountPrivilege","SeManageVolumePrivilege","SeNetworkLogonRight","SeProfileSingleProcessPrivilege","SeRelabelPrivilege",
			"SeRemoteInteractiveLogonRight","SeRemoteShutdownPrivilege","SeRestorePrivilege","SeSecurityPrivilege","SeServiceLogonRight","SeShutdownPrivilege",
			"SeSyncAgentPrivilege","SeSystemEnvironmentPrivilege","SeSystemProfilePrivilege","SeSystemtimePrivilege","SeTakeOwnershipPrivilege","SeTcbPrivilege",
			"SeTimeZonePrivilege","SeTrustedCredManAccessPrivilege","SeUndockPrivilege","SeUnsolicitedInputPrivilege")]
		[string] $privilege,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What Account needs Security Policy updates?')]
		[string] $HostName

	)
	try
	{
		if((Test-Path "\\$HostName\C$\Temp\Carbon") -ne $true)
		{
			Write-Log -Level WARN -Message "Carbon files not on host: $Hostname.  Copying Files."
			Copy-Item ".\Carbon\" -Destination "\\$HostName\C$\Temp\Carbon" -Recurse
			##Adding a sleep, occasionally function moves on while file copy still in progress.
			If($(Test-Path -Path "\\$HostName\C$\Temp\Carbon"))
			{
				Write-Log -Level WARN -Message "Carbon files Copied to: \\$HostName\C$\Temp\Carbon on host: $Hostname.  Copying Files."
			}
			Else
			{
				Write-Log -Level ERROR -Message "Unable to Copy carbon Files to \\$HostName\C$\Temp\Carbon.  Please copy the carbon directory manually from Source to target host."
			}
		}
        Write-Log -Level INFO -Message "Attempting to Grant $privilege to $Identity on Host: $HostName"
		
		#SecPol trims the accounts down to 25 characters need to do this manually for it to process adding an account. 
		if($identity.Length -ge 25)
		{
			$identity = $identity.Substring(0,25) 
		}
		#generate script block to run remotely on the target.
        $scriptblock = {
						param($Id, $priv)
						$CarbonDLLPath = "C:\Temp\Carbon\Carbon.dll"
						[System.Reflection.Assembly]::LoadFile($CarbonDLLPath) | Out-Null
						[Carbon.Security.Privilege]::GrantPrivileges($Id,$priv)
					   }
		$errorVar = $null
		Invoke-Command -ComputerName $HostName -scriptBlock  $scriptblock -ArgumentList($identity,$privilege) -ErrorVariable $errorVar -ErrorAction Stop

        Write-Log -Level INFO -Message "Successful Grant of $privilege to $Identity on Host: $HostName"
	}
	catch
	{
		Write-Log -Level Error -Message "Failed to Grant Privilege: $Privilege to Identity: $Identity on Host: $HostName,  Error Message $ErrorMessage"
	}
}

function Add-LocalGroupMember
{
<# 
.SYNOPSIS 
	Adds an account to a local group on the target host.
.DESCRIPTION 
	remotely add accounts to local groups on a target host.  
.PARAMETER Identity
	The login or local user name
.PARAMETER LcoalGroup
	The name of the local group
.PARAMETER HostName
	The name of the host that will be affected.
.OUTPUTS 
	None
.EXAMPLE 
	Add-LocalGroupMember -Identity "AAWH\SomeUser" -LocalGroup "Administrators" -HostName MyFavoriteComputer 
#>
	[cmdletbinding()]
	param
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What Account to be added to a local group?')]
		[string] $Identity,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What Group is it?')]
		[string] $Localgroup,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
		[string] $HostName
	)

	Write-Log -Level INFO -Message "Attempting to add User: $identity to localgroup: $localgroup on Host:$HostName"
	
	#Get the domain from the identity string and separate them
	if($identity.Contains('\'))
	{
		[int] $pos = $identity.IndexOf('\')
		[string] $domain = $identity.Substring(0,$pos)
		$identity = $identity.Substring(($pos+1))
	}
	else
	{
		[string] $domain = $null
	}
	try
	{
		#add if block to check if user is already a member of the group
		
		#create the group and user ADSI objects
		$objUser = [ADSI]("WinNT://$domain/$identity") 
		$objGroup = [ADSI]("WinNT://$HostName/$localgroup,group") 
		#get the group member objects
		$ADSIObjectGroupMembers = @($objGroup.PSBase.Invoke("Members"))
		$GroupMembers = @()
		
		#get the actual User and group names. 
		Foreach($member in $ADSIObjectGroupMembers)
		{
			$name = $member.GetType().InvokeMember("Name", 'GetProperty', $null, $member, $null)
			$class = $member.GetType().InvokeMember("Class", 'GetProperty', $null, $member, $null)
			$path = $member.GetType().InvokeMember("ADsPath", 'GetProperty', $null, $member, $null)
			$path = $($path.Replace("WinNT://","")).Replace('/','\')
			#add the actual names to a flattened list, with the domain attached.
			if($path -eq $($domain+'\'+$name))
			{
				$GroupMembers += ($domain+'\'+$name).ToString()
			}
		}
		#If the user/group is not already a member of the local group add it.
		if($GroupMembers -notcontains $($domain+'\'+$identity))
		{
			$objGroup.PSBase.Invoke("Add",$objUser.PSBase.Path) 
			Write-Log -Level INFO -Message "Successfully added User: $identity to localgroup: $localgroup on Host:$HostName"
		}
		else
		{
			Write-Log -Level WARN -Message "$domain\$identity is already a member of the localgroup: $localgroup on host: $HostName"
		}
	}
	catch
	{
		$ErrorMessage = $_.Exception.Message
		Write-Log -Level ERROR -Message "Failed to add User: $identity to localgroup: $localgroup on Host: $HostName, Error: $ErrorMessage"
	}
}
function Set-ServiceLogin
{
<# 
.SYNOPSIS 
	Changes the login information for a Service
.DESCRIPTION 
	Use this to update a service with new login information.  If the service is started, it will be restarted for the new account to take effect. 
	If the service is already stopped the service will be left off.  It will still be validated for the change.
.PARAMETER Identity
	The login or local user name
.PARAMETER Password
	A secure string holding the password
.PARAMETER ServiceDisplayName
	The display name of the service to be updated. 
.PARAMETER HostName
	The name of the host that will be affected.
.OUTPUTS 
	None
.EXAMPLE 
	Set-ServiceLogin -Identity "AAWH\SomeUser" -Password "A SECURE STRING OBJECT SEE PARAMTERS" -ServiceDisplayName "Certificate Propagation" -HostName MyFavoriteComputer 
#>
	[cmdletbinding()]
	param
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What Account do you want to run the service?')]
		[string] $Identity,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
		[System.Security.SecureString] $Password,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the display name of the service?')]
		[string] $ServiceDisplayName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
		[string] $HostName

	)
	
	Write-Log -Level INFO "Attempting to Udpate logon to: $identity for service: $ServiceDisplayName on Host: $hostname..."
	try{
		#Get the real service name, not the displayname
		$ServiceName = $(Get-Service -DisplayName $ServiceDisplayName -ComputerName $HostName).Name
		#pull the service object
  		$ServiceObj = Get-WmiObject Win32_Service -ComputerName $HostName -Filter "name='$ServiceName'" 
		#Decrypt the password
		$PlainPass = SecureStringToPlainText -SecureString $Password

		#get the samAccountName (shortname/Pre-Windows 2000 name)
		$samIdentity = $null
		$samDomainName = $null
		$FilterUserName = $null
		if($Identity.Contains('\'))
		{
			$samDomainName = $Identity.Substring(0,$Identity.IndexOf('\'))
			$FilterUserName = $Identity.Substring($Identity.IndexOf('\')+1)
		}
		else
		{
			$FilterUserName = $Identity
		}
		$samAccountNAme = (Get-samAccountName -LoginDisplayName $FilterUserName)

		#Update the service's account/password, and check if the change committed
		$ChangeStatus = $ServiceObj.change($null,$null,$null,$null,$null,$null,($samDomainName+'\'+$samAccountName),$PlainPass,$null,$null,$null).ReturnValue
		#Remove  the variable
		Remove-Variable PlainPass
		$PlainPass = 'MyLittlePony'  ##cannot be zerod like the binary string. So redirect the pointer to something useless.

		#Change Status codes for Service.Change() method: https://msdn.microsoft.com/en-us/library/aa384901(v=vs.85).aspx
		If ($ChangeStatus -eq 0 -and $ServiceObj.Started)
		{
			Write-Log -Level INFO -Message "Service $ServiceDisplayName is running, Restarting $ServiceDisplayName for password change to take effect."
			try
			{
				Restart-Service -DisplayName $ServiceDisplayName -Force
			}
			Catch
			{
				Write-Log -Level ERROR -Message "Unable to restart Service $ServiceDisplayName on Host $HostName."
			}
		}
		ElseIf($ChangeStatus -eq 0 -and !$ServiceObj.Started)
		{
			Write-Log -Level INFO -Message "The Service $ServiceDisplayName was already in the stopped state, leaving the service off...."
			Write-Log -Level INFO -Message "Account/Password updated for $ServiceDisplayName"
		}
		Else 
		{
			Write-Log -Level ERROR -Message "Failed to update account/Password for service $ServiceDisplayName, the change status code was: $ChangeStatus.  Review status codes here: https://msdn.microsoft.com/en-us/library/aa384901(v=vs.85).aspx"
		}
	}
	catch
	{
		$ExceptionMessage = $_.Exception.Message
		Write-Log -Level ERROR -Message "Failed to Update logon account to: $identity, for service:$serviceDisplayName,on host: $hostname. Exception: $ExceptionMessage"
	}
}
function Convert-SecureStringToPlainText
{
<# 
  .SYNOPSIS 
   Converts a securestring to a plaintext string.
  .DESCRIPTION 
   Use this to decrypt your secure strings in a clean and reliable way.
  .EXAMPLE 
   Convert-SecureSTringToPlainText -SecureString $MySecureString
   Returns "MyStringInPlainText"
  .PARAMETER SecureString
  [System.Security.SecureString] string type.
#>
	[cmdletbinding()]
	param
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
		[System.Security.SecureString] $SecureString
	)
	#convert string to binary, and then plain text
	$BinaryString = [System.runtime.interopservices.marshal]::SecureStringToBSTR($SecureString)
	$PlainString = [System.runtime.interopservices.marshal]::PtrToStringAuto($BinaryString)
	
	#CleanUp the variable to remove sensitive info
	[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BinaryString)  #to be safe, zeroing out the pointer to the memory space.
	Remove-Variable BinaryString  #removes the variable data
	

	return $PlainString
}
function Copy-DirectoryWithBITSTransfer
{
<# 
.SYNOPSIS 
	Copies one directory to another using Bits-Transfer cmdlets 
.DESCRIPTION 
	Copies all the files in a the source directory to the destination, maintainning folder structure.
	Using bits to include a porgress bar.
.EXAMPLE 
	Copy-DirectoryWithBITSTransfer -SourceDirectory "\\Host\C$\Temp\SQL" -DestinationDirectory "\\Host\D$\Temp\SQL" 
.PARAMETER SourceDirectory 
	Source folder to copy
.PARAMETER DestinationDirectory
	Destination folder
.OUTPUT
	N/A
#> 
	[cmdletbinding()]
	param
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
		[string] $SourceDirectory,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
		[string] $DestinationDirectory
	)
    
    #create the destination if it doesnt exist
    If(!(test-path -Path $DestinationDirectory))
    {
        New-Item $DestinationDirectory -ItemType Directory |Out-Null
    }

    If (!(test-Path -Path $SourceDirectory))
    {
        Write-Log -Level ERROR -Message "File copy failed! $SourceDirectory DOES NOT EXIST."
    }
    else
    {
        try
        {
            Write-Log -Level INFO -Message "Collecting file list from Source: $SourceDirectory.  THIS MAY TAKE SOME TIME."
			#get all folders in the source directory for a future loop to copy the files
	        $SourceFolders = Get-ChildItem -Name -Path $SourceDirectory -Directory -Recurse
            #Transfer the top level files
			$TopFiles = Get-ChildItem -File -Path $SourceDirectory | Where-Object {$_.Name -notmatch "autorun.inf"}
			Write-Log -Level INFO -Message "Starting transfer of files from $SourceDirectory to $DestinationDirectory"
			Foreach( $file in $TopFiles)
			{
				If($file.FullName -notmatch 'AutoRun.inf')
				{
					Write-Verbose "Starting transfer of file: $file"
					Start-BitsTransfer -Source $SourceDirectory\$file -Destination $DestinationDirectory\$file -Description "Transfering File: $file" -DisplayName $file
				}
            }
            #Loop throug the files in the subfolders
            Foreach($file in $SourceFolders)
            {
                #double check that xcopy created all the sub folders, if not create them. 
                $exists = Test-Path $DestinationDirectory\$File
                If($exists -eq $false) 
                {
                    New-Item $DestinationDirectory\$file -ItemType Directory | Out-Null
                }
				Write-Verbose "Starting transfer of file: $file"
				Start-BitsTransfer -Source $SourceDirectory\$file\*.* -Destination $DestinationDirectory\$file -Description "Transfering File: $file" -DisplayName $file 
            }
			#close down our bit-transfer jobs. Removing for now,  this doesnt appear to function the same way anymore. 
            #$BitSessions = Get-BitsTransfer -AllUsers  #| Complete-BitsTransfer
			
        }
        Catch
        {
            $ExceptionMessage = $_.Exception.Message
            Write-Log -Level ERROR -message "File copy from Source: $sourceDirectory to Destination: $DestinationDirectory, Failed. Exception: $ExceptionMessage"
        }
    }
    Write-Log -Level INFO -Message "Successful file Transfer of Source: $SourceDirectory to Destiniation: $DestinationDirectory "
}

function Get-samAccountName
{
<# 
.SYNOPSIS 
   Converts a login to its Pre-Windows 2000 lenght (Domain\ + 20 characters) or samAccountName
.DESCRIPTION 
   Some older applications and interfaces still reference the Pre-Windows 2000 logon length.  This will take a modern name and return the Pre-Windows 2000 User Logon Name
.EXAMPLE 
   Get-Win2000Login
   Returns "Login samAccountName as type string"
.PARAMETER LoginDisplayName
  [String] string type.
.OUTPUT
	String of samAccountName
#>
	[cmdletbinding()]
	param
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
		[string] $LoginDisplayName
	)
	try{
		#return variable
		[string]$samAccountName = $null
		If($LoginDisplayName.Contains('\'))
		{
			$DomainName = $LoginDisplayName.Substring(0,$LoginDisplayName.IndexOf('\')+1)
			$LoginDisplayName = $LoginDisplayName.Substring($LoginDisplayName.IndexOf('\')+1)
		}
		#create our search crawler filter
		$strFilter = "(&(objectCategory=User)(DisplayName=$LoginDisplayName))"
		#Create the directory connection
		$objDomain = New-Object System.DirectoryServices.DirectoryEntry
		#create the search crawler
		$objSearcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]"")
		#Tell the search crawler what domain to use
		$objSearcher.SearchRoot = $objDomain
		#limit the result set so we dont crap out the local host or the AD server
		$objSearcher.PageSize = 1000
		#filter based on our filter
		$objSearcher.Filter = $strFilter

		#run the search get the results
		$Results = $objSearcher.FindAll()

		#if we have to little or to many results error out.
		if($Results.Count -gt 1 -or $Results.count -eq 0)
		{
		    write-log -level ERROR -Message "the Active Directory Search found $($Results.count) accounts.  Please confirm the account name is correct and unique"
		}

		#for each result (should only be one, but an array is returned) Pull out the property we need.
		foreach ($objResult in $Results)
		{
		    $objItem = $objResult.Properties; 
		    #$objItem.samaccounttype 
		    $samAccountName = $objItem.samaccountname
		    #$objItem.displayname
		    #$objItem.distinguishedname
		}
		return ($DomainName+$samAccountName)
	}
	catch
	{
		$ExceptionMessage = $_.Exception.Message
		Write-Log -Level ERROR -Message "Failed to get SamAccountName for Login: $LoginDisplayName. Exception: $ExceptionMessage"
	}
}

function Enable-RDPAccess
{
<# 
  .SYNOPSIS 
   Enables remote desktop on a host.
  .DESCRIPTION 
   Enables remote desktop on a host, enforces at least version 6.0 of the MS RDP client.
  .EXAMPLE 
   Enable-RDPAccess -HostName "MyNewServer"
  .PARAMETER HostName
  [String] Name of the Host to enable RDP on.
#>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
        [string] $hostname
    )

    $errorResults = 0
	## TODO Add capture of change results
	## TODO Add try catch error handling
	try
	{
		#Enable Terminal Service Connections
		$RDP =(Get-WmiObject Win32_TerminalServiceSetting -Namespace root\cimv2\TerminalServices -ComputerName $hostname) 
		$RDPResult = ($RDP.SetAllowTSConnections(1,1)).ReturnValue
        
        if($RDPResult -eq 0)
        {
			#Set the authentication method to 1, enforcing windows RDP version 6 or higher
			##https://msdn.microsoft.com/en-us/library/aa383441(v=vs.85).aspx.
		    $RDP2 = (Get-WmiObject -Class "Win32_TSGeneralSetting" -ComputerName $hostname -Namespace root\cimv2\TerminalServices -Filter "TerminalName='RDP-tcp'")
		    $RDP2.SetUserAuthenticationRequired(1) | Out-Null
            If($RDP2.UserAuthenticationRequired -ne 1)
            {
				Write-Log -Level INFO -Message "RDP authentication required was not set to 1, this might be a problem. Sleeping for 3 seconds trying again. https://msdn.microsoft.com/en-us/library/aa383441(v=vs.85).aspx"
				start-sleep -Seconds 3
				$RDP2.SetUserAuthenticationRequired(1) | Out-Null
				if($RDP2.UserAuthenticationRequired -ne 1)
				{
					Write-Log -Level ERROR -Message "Unable to set UserAuthenticationRequired to strict mode (1) on Host: $HostName"
				}
            }
        }
        else
        {
            Write-Log -Level ERROR -Message "Unable to enable RDP on $HOSTName.  ResultCode: $RDPResult, WMI RDP error codes: https://msdn.microsoft.com/en-us/library/aa383513(v=vs.85).aspx"
        }
        Write-Log -level INFO -Message "RDP enabled on Host: $HostName"
	}
	catch
	{
		$ExceptionMessage = $_.Exception.Message
		Write-Log -Level ERROR -Message "Unable to enable RDP access on $HostName.  Exception: $ExceptionMessage"
	}
}

function Test-ADComputerObjectExists
{
<# 
  .SYNOPSIS 
   Converts a login to its Pre-Windows 2000 lenght (Domain\ + 20 characters) or samAccountName
  .DESCRIPTION 
   Some older applications and interfaces still reference the Pre-Windows 2000 logon length.  This will take a modern name and return the Pre-Windows 2000 User Logon Name
  .EXAMPLE 
   Get-Win2000Login
   Returns "Login samAccountName as type string"
  .PARAMETER LoginDisplayName
  [String] string type.
#>
	[cmdletbinding()]
	param
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
		[string] $ObjectDisplayName
	)
	try{
		#return variable
		[string]$samAccountName = $null

		#create our search crawler filter
		$strFilter = "(&(Name=$ObjectDisplayName))"
		#Create the directory connection
		$objDomain = New-Object System.DirectoryServices.DirectoryEntry
		#create the search crawler
		$objSearcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]"")
		#Tell the search crawler what domain to use
		$objSearcher.SearchRoot = $objDomain
		#limit the result set so we dont crap out the local host or the AD server
		$objSearcher.PageSize = 1000
		#filter based on our filter
		$objSearcher.Filter = $strFilter

		#run the search get the results
		$Results = $objSearcher.FindAll()

		#if we have to little or to many results error out.
		if($Results.Count -gt 1)
		{
		    write-log -level ERROR -Message "the Active Directory Search found $($Results.count) results.  Please confirm the display name is correct and unique"
		}
		elseif( $Results.Count -eq 1)
		{
			#got one result, return true object exits
			##Debug line to expand all properties of an AD Object.  
            #$Results | Select -ExpandProperty Properties  
			return $true
		}
		else
		{
			#got 0 results object does not exist
			return $false
		}
	}
	catch
	{
		$Exception = $_.Exception.Message
		Write-Log -Level ERROR -Message "Failed to search for ObjecDisplayname: $ObjectDisplayName. Exception: $Exception"
	}
}
Function Get-RandomString
{
<# 
.SYNOPSIS 
   Generates a random string of the specificed length
.DESCRIPTION 
   Generate random strings of random lengths!
.EXAMPLE 
   Get-RandomString -Length 20
   Returns String of 20 characters
.PARAMETER Length
  [int] a number representing the desired length of the string
#>
	[cmdletbinding()]
	param
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
		[int] $Length = 16
	)
	
	$ReturnString = $null
	For($i=0; $i -lt $Length; $i++ )
	{
		$ReturnString += [Char][Byte](Get-Random -Maximum 127 -Minimum 33)
	}
	return $ReturnString
}
function Dismount-IsoFile
{
<# 
.SYNOPSIS 
	Finds a specificed ISO mounted to a server, and dismounts it.
.DESCRIPTION 
	Finds and iso remotely mounted to server and safely dismounts it. 
.EXAMPLE 
	Dismount-IsoFile -HostName SHDQAIMSSQLAO04 -IsoName "SQL"
.EXAMPLE 
	Dismount-IsoFile -HostName SHDQAIMSSQLAO04 -IsoName "Windows"
.PARAMETER HostName
	Name of the server
.PARAMETER IsoName
	Name of the iso you want to dismount.  This is passed into a like statement to find it, you do not need the full name.
.OUTPUT
	None.
#> 
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
        [string] $HostName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the iso (does not need to be full name)?')]
        [string] $IsoName
	)

	$Drive = Get-WmiObject win32_volume -ComputerName $HostName | WHERE {$_.DriveType -eq 5 -and $_.label -like "$IsoName*"}
	if($Drive -ne $null)
	{
		$Mount = Get-volume -CimSession $HostName -DriveLetter $Drive.DriveLetter.Replace(":","")
		$Image = $Mount | Get-DiskImage 
		[String] $ImagePath = $Image.ImagePath
		$Image | Dismount-DiskImage
		$ImagePath = $ImagePath.Replace(":","$")
		Remove-Item "\\$Hostname\$ImagePath"
	}

}
function Get-DiskImageDriveLetter
{
<# 
.SYNOPSIS 
	Finds the drive letter for a particular ISO that has been mounted.
.DESCRIPTION 
	Finds the drive letter for a particular ISO that has been mounted.
.EXAMPLE 
	Get-DiskImageDriveLetter -HostName SHDQAIMSSQLAO04 -IsoName "SQL"
.EXAMPLE 
	Get-DiskImageDriveLetter -HostName SHDQAIMSSQLAO04 -IsoName "Windows"
.PARAMETER HostName
	Name of the server
.PARAMETER IsoName
	Name of the iso you want to find.  This is passed into a like statement to find it, you do not need the full name.
.OUTPUT
	String DriveLetter.
#> 
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
        [string] $HostName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the iso (does not need to be full name)?')]
        [string] $IsoName
	)

	$Drive = Get-WmiObject win32_volume -ComputerName $HostName | WHERE {$_.DriveType -eq 5 -and $_.label -like "$IsoName*"}
	return $Drive.DriveLetter
} 

function Get-SPN
{
<#
    .SYNOPSIS
        Get Service Principal Names

    .DESCRIPTION
        Get Service Principal Names

        Output includes:
            ComputerName - SPN Host
            Specification - SPN Port (or Instance)
            ServiceClass - SPN Service Class (MSSQLSvc, HTTP, etc.)
            sAMAccountName - sAMAccountName for the AD object with a matching SPN
            SPN - Full SPN string

    .PARAMETER ComputerName
        One or more hostnames to filter on.  Default is *

    .PARAMETER ServiceClass
        Service class to filter on.
        
        Examples:
            HOST
            MSSQLSvc
            TERMSRV
            RestrictedKrbHost
            HTTP

    .PARAMETER Specification
        Filter results to this specific port or instance name

    .PARAMETER SPN
        If specified, filter explicitly and only on this SPN.  Accepts Wildcards.

    .PARAMETER Domain
        If specified, search in this domain. Use a fully qualified domain name, e.g. contoso.org

        If not specified, we search the current user's domain

    .EXAMPLE
        Get-Spn -ServiceType MSSQLSvc
        
        #This command gets all MSSQLSvc SPNs for the current domain
    
    .EXAMPLE
        Get-Spn -ComputerName SQLServer54, SQLServer55
        
        #List SPNs associated with SQLServer54, SQLServer55
    
    .EXAMPLE
        Get-SPN -SPN http*

        #List SPNs maching http*
    
    .EXAMPLE
        Get-SPN -ComputerName SQLServer54 -Domain Contoso.org

        # List SPNs associated with SQLServer54 in contoso.org

    .NOTES 
        Adapted from
			https://gallery.technet.microsoft.com/scriptcenter/Get-SPN-Get-Service-3bd5524a
            http://www.itadmintools.com/2011/08/list-spns-in-active-directory-using.html
            http://poshcode.org/3234
        Version History 
            v1.0   - Chad Miller - Initial release 
            v1.1   - ramblingcookiemonster - added parameters to specify service type, host, and specification
            v1.1.1 - ramblingcookiemonster - added parameterset for explicit SPN lookup, added ServiceClass to results

    .FUNCTIONALITY
        Active Directory             
#>
    
    [cmdletbinding(DefaultParameterSetName='Parse')]
    param(
        [Parameter( Position=0,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ParameterSetName='Parse' )]
        [string[]]$ComputerName = "*",

        [Parameter(ParameterSetName='Parse')]
        [string]$ServiceClass = "*",

        [Parameter(ParameterSetName='Parse')]
        [string]$Specification = "*",

        [Parameter(ParameterSetName='Explicit')]
        [string]$SPN,

        [string]$Domain
    )
    
    #Set up domain specification, borrowed from PyroTek3
    #https://github.com/PyroTek3/PowerShell-AD-Recon/blob/master/Find-PSServiceAccounts
        if(-not $Domain)
        {
            $ADDomainInfo = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
            $Domain = $ADDomainInfo.Name
        }
        $DomainDN = "DC=" + $Domain -Replace("\.",',DC=')
        $DomainLDAP = "LDAP://$DomainDN"
        Write-Verbose "Search root: $DomainLDAP"

    #Filter based on service type and specification.  For regexes, convert * to .*
        if($PsCmdlet.ParameterSetName -like "Parse")
        {
            $ServiceFilter = If($ServiceClass -eq "*"){".*"} else {$ServiceClass}
            $SpecificationFilter = if($Specification -ne "*"){".$Domain`:$specification"} else{"*"}
        }
        else
        {
            #To use same logic as 'parse' parameterset, set these variables up...
                $ComputerName = @("*")
                $Specification = "*"
        }

    #Set up objects for searching
        $SearchRoot = [ADSI]$DomainLDAP
        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $searcher.SearchRoot = $SearchRoot
        $searcher.PageSize = 1000

    #Loop through all the computers and search!
    foreach($computer in $ComputerName)
    {
        #Set filter - Parse SPN or use the explicit SPN parameter
        if($PsCmdlet.ParameterSetName -like "Parse")
        {
            $filter = "(servicePrincipalName=$ServiceClass/$computer$SpecificationFilter)"
        }
        else
        {
            $filter = "(servicePrincipalName=$SPN)"
        }
        $searcher.Filter = $filter

        Write-Verbose "Searching for SPNs with filter $filter"
        foreach ($result in $searcher.FindAll()) {

            $account = $result.GetDirectoryEntry()
            foreach ($servicePrincipalName in $account.servicePrincipalName.Value) {
                
                #Regex will capture computername and port/instance
                if($servicePrincipalName -match "^(?<ServiceClass>$ServiceFilter)\/(?<computer>[^\.|^:]+)[^:]*(:{1}(?<port>\w+))?$") {
                    
                    #Build up an object, get properties in the right order, filter on computername
                    New-Object psobject -property @{
                        ComputerName=$matches.computer
                        Specification=$matches.port
                        ServiceClass=$matches.ServiceClass
                        sAMAccountName=$($account.sAMAccountName)
                        SPN=$servicePrincipalName
                    } | 
                        Select-Object ComputerName, Specification, ServiceClass, sAMAccountName, SPN |
                        #To get results that match parameters, filter on comp and spec
                        Where-Object {$_.ComputerName -like $computer -and $_.Specification -like $Specification}
                } 
            }
        }
    }
}
Function Get-DistinguishedName
{
<#
.SYNOPSIS
    Get Distinguished Name
.DESCRIPTION
	Returns the full distinguished name for an ad computer object.
.PARAMETER ComputerName
    Name of the computer to lookup.
.EXAMPLE
    Get-DistinguishedName -ComputerName SMDCAIMSSQLAO01
	#returns the full ou list for the computer name
.OUTPUT 
	String
.NOTES 
    Adapted from
		https://gallery.technet.microsoft.com/scriptcenter/Script-to-determine-the-OU-5a22a0e0h
.FUNCTIONALITY
    Active Directory     
#>
    [cmdletbinding()]
    param
    (
        [Parameter( Position=0, Mandatory = $true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$ComputerName
    )
    $Filter = "(&(objectCategory=Computer)(Name=$ComputerName))"

    $DirectorySearcher = New-Object System.DirectoryServices.DirectorySearcher
    $DirectorySearcher.Filter = $Filter
    $SearcherPath = $DirectorySearcher.FindOne()
    $DistinguishedName = $SearcherPath.GetDirectoryEntry().DistinguishedName

    $OUName = ($DistinguishedName.Split(","))[1]
    $OUMainName = $OUName.SubString($OUName.IndexOf("=")+1)
    
#    $Obj = New-Object -TypeName PSObject -Property @{"ComputerName" = $ComputerName
#                                                     "BelongsToOU" = $OUMainName}
    Return $DistinguishedName
}

function Start-SleeperBar
{
<#
.SYNOPSIS
    Pause with progress bar/timer
.DESCRIPTION
	Pauses as script and displays: A count down timer, a progress bar, and a title
.PARAMETER Seconds
    number of minutes to sleep
.PARAMETER ProgressBarTitle
	Title that will be displayed above the count down timer
.EXAMPLE
    Start-SleeperBar -Seconds 10 -ProgressBarTitle "Pausing For disk format"
.OUTPUT 
	None
.NOTES 
    Adapted from
		http://universitytechnology.blogspot.com/2008/11/powershell-progress-bar-with-time.html
.FUNCTIONALITY
    Sleep command with progress bar    
#>
    [cmdletbinding()]
    param
    (
        [Parameter( Position=0, Mandatory = $true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [int] $Seconds,
		[Parameter( Position=0, Mandatory = $true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [String] $ProgressBarTitle

    )

	$x = $Seconds
	$length = $x / 100
	while($x -gt 0) 
	{
		$min = [int](([string]($x/60)).split('.')[0])
		$text = " " + $min + " minutes " + ($x % 60) + " seconds left"
		Write-Progress $ProgressBarTitle -status $text -perc ($x/$length)
		start-sleep -s 1
		$x--
	}
}
Function Set-DefaultDTCConfiguration
{
<#
.SYNOPSIS 
	Set the default settings for the DTC service.  
.DESCRIPTION 
	Sets dtc security: remote client access = true, Inbound and Outbound Transactions = true, Authentication Level NoAuth  (lowest possible level until we get kerberos and other things setup).
.EXAMPLE 
	Set-DtcNetworkSettings -HostName "SXDCNewVSQLInstance"
.PARAMETER HostName
	Name of the target host
.OUTPUT
	None
#>
	[cmdletbinding()]
	Param
	(
    	[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the host?')]
		[string]$HostName
	)
	#TODO Set service to run as same service account running SQL server
	Set-DtcNetworkSetting -DtcName Local -RemoteClientAccessEnabled $true -InboundTransactionsEnabled $true -OutboundTransactionsEnabled $true -AuthenticationLevel NoAuth -CimSession $HostName -Confirm
}

Function Set-OSPowerPlan
{
<#
.SYNOPSIS 
	Set power plan on a target host.  
.DESCRIPTION 
	Changes the power plan on the target host to the desired exsiting plan.
.EXAMPLE 
	Set-OSPowerPlan -HostName "SXDCNewVSQLInstance" -PowerPlan HighPerformance
.PARAMETER HostName
	Name of the target host
.PARAMETER PowerPlan
	Name of the power plan
.OUTPUT
	None
#>
	[cmdletbinding()]
	Param
	(
    	[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the host?')]
		[string]$HostName,
		[Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Which power plan (balanced/HighPerfomance)?')]
		[ValidateSet("Balanced","High performance","Power saver")]
		[string]$PowerPlan
	)
	Begin{}
	Process
	{
		#get the power plan using Get-CimInstance instead of Get-WmiObject, its faster but has an odd way to call the object methods.
		$Power = Get-CimInstance -Name root\cimv2\power -Class win32_PowerPlan -Filter "ElementName = '$PowerPlan'" -CimSession $HostName 
		#Remotly invoke the Activate method on our power plan      
		Invoke-CimMethod -InputObject $Power -MethodName Activate
	}
	End{}
	
}
