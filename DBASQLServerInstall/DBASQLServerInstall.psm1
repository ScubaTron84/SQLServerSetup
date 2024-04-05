#
# AAWHSQLServerInstall.psm1
function Confirm-IsSQLAlreadyInstalled
{
<# 
  .SYNOPSIS 
  Creates base folders for standard AAWH sql server installs on the approriate disks.
  .DESCRIPTION 
  Works remotely, looks for and creates necessary SQL server paths on the standard sql server disks.
  .EXAMPLE 
  New-SQLFolders -HostName "SXDCTestSQLServer"
  .PARAMETER HostName
  The Name of host to create folders on.
  .OUTPUT
  Creates folders for TempDB, User Data, User logs, and the SystemDBs on the respective drives.
#>
[cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
        [string] $HostName
	)
	$SQLService = $null
	$SQLService = Get-Service -ComputerName $HostName | WHERE {$_.Name -eq "MSSQLSERVER"}
	if($SQLService -ne $null)
	{
		return $true;
	}
	else
	{
		return $false
	}
}

#TODO make this find the drives letters instead of requiring input, and have better default inputs.
Function New-SQLFolders
{
<# 
  .SYNOPSIS 
  Creates base folders for standard AAWH sql server installs on the approriate disks.
  .DESCRIPTION 
  Works remotely, looks for and creates necessary SQL server paths on the standard sql server disks.
  .EXAMPLE 
  New-SQLFolders -HostName "SXDCTestSQLServer"
  .PARAMETER HostName
  The Name of host to create folders on.
  .OUTPUT
  Creates folders for TempDB, User Data, User logs, and the SystemDBs on the respective drives.
#>

# TODO Create folder paths for additional drives.
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
        [string] $HostName,
		[Parameter(Mandatory=$False,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Enter the drive letter for the system dbs')]
		[string] $SystemDBDriveLetter,
		[Parameter(Mandatory=$False,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Enter the drive letter for the user data drive.')]
		[string] $DataDriveLetter,
		[Parameter(Mandatory=$False,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Enter the drive letter for the user log drive.')]
		[string] $LogDriveLetter,
		[Parameter(Mandatory=$False,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Enter the drive letter for tempdb.')]
		[string] $TempDBDriveLetter,
		[Parameter(Mandatory=$False,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Enter the drive letter for default backups.')]
		[string] $BackupDriveLetter,
		[Parameter(Mandatory=$False,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Enter the path for the system dbs')]
		[string] $SystemPath,
		[Parameter(Mandatory=$False,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Enter the path for the user data drive.')]
		[string] $DataPath,
		[Parameter(Mandatory=$False,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Enter the path for the user log drive.')]
		[string] $LogPath,
		[Parameter(Mandatory=$False,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Enter the path for tempdb.')]
		[string] $TempDBPath,
		[Parameter(Mandatory=$False,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Enter the path for default backups.')]
		[string] $BackupPath
    )

    try
    {	
		If($SystemDBDriveLetter -eq $null -or $dataDriveLetter -eq $null -or $LogDriveLetter -eq $null -or $TempDBDriveLetter -eq $null -or $BackupDriveLetter -eq $null)
		{
			Write-Log -Level Error -Message "Unable to Locate a drive by letter, to create the necessary SQL folders.  You may need to create them manually"
		}
        if(!(test-path -Path "\\$HostName\$DataDriveLetter$\$DataPath"))
        {
            New-Item \\$HostName\$DataDriveLetter$\$Datapath -type directory | Out-Null
        }
		if(!(test-path -Path "\\$HostName\$BackupDriveLetter$\$BackupPath"))
        {
            New-Item \\$HostName\$BackupDriveLetter$\$BackupPath -type directory | Out-Null
        }
        if(!(test-path -Path "\\$HostName\$LogDriveLetter$\$LogPath"))
        {
            New-Item \\$HostName\$LogDriveLetter$\$LogPath -type directory | Out-Null
        }
        if(!(test-path -Path "\\$HostName\$SystemDBDriveLetter$\$SystemPath"))
        {
            New-Item \\$HostName\$SystemDBDriveLetter$\$SystemPath -type directory | Out-Null
        }
        if(!(test-path -Path "\\$HostName\$TempDBDriveLetter$\$TempDBPath"))
        {
            New-Item \\$hostName\$TempDBDriveLetter$\$TempDBPath -type directory | Out-Null
        }
    }
    catch
    {
        $ExecptionMessage = $_.Exception.Message
        $ExceptionItem = $_.Excepetion.ItemName
        Write-Log -Level ERROR -Message "Folder creation on $hostname FAILED... $ExecptionMessage $ExceptionItem"
    }
}
# TODO Pass keys and passwords securely to the target host.  No Plain Text over the wire in revision 2.
# TODO copy the sql iso with BITStransfer instead of file by file.
# TODO create an enable-psremoting wrapper that also creates a limited winRM profile so it can stay on and is less dangerous.
# TODO put in install command switch for the various combinations of SQL server install and Versions.
# TODO MAYBE stop using configuration.ini files, do entire install from command line, removes the need to save and copy files
Function Install-SQLServerRemotely
{
<# 
.SYNOPSIS 
	Installs SQL server on a remote Host 
.DESCRIPTION 
	reads the the sqlconfiguration.ini file to install a new sql server using Windows RemoteManagement (Win RM) .
.EXAMPLE 
	Install-SQLServerRemotely -Hostname "MySQLHost" -SetupLocation "C:\Temp\Setup.exe" -SQLServiceAccount "svcSQlAccount" -Password [SecureSTring]
	returns an imported csv file.
.PARAMETER HostName 
	Host to install sql on
.PARAMETER SetupLocation
	Local Path on host to setup.exe for SQL server install
.PARAMETER SQLServiceAccount
	The Domain account that will run sql (can be an AD Managed Service Acccount)
.PARAMETER Password
	the secure string form of the service account.
.PARAMETER InstanceDirectory
	the install directory for the SQL server instance
.PARAMETER SQLBackupDirectory
	The default backup directory for SQL server	 
.PARAMETER SQLUserDBDirectory
	The default data file directory for user databases
.PARAMETER SQLUserLogDirectory
	The default log file directory for user databases
.PARAMETER SQLTempDBDirectory
	The default directory for TempDB data and log files
.PARAMETER SQLSysAdminAccounts
	String of login names, separated with spaces.  These logins will be added to the Server SYSADMIN role. 
.PARAMETER SQLVersion
	The year version of SQL server to install.  (2012,2014,2016)
.OUTPUT
	imported csv file.
#> 
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
        [string] $HostName,
		[Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is AD service account that will run SQL Server?')]
        [string] $SQLServiceAccount,
		[Parameter(Mandatory=$true,Position=2,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Password For SQL Service account')]
		[System.Security.SecureString] $Password,
		[Parameter(Mandatory=$true,Position=3,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Please provide system path/directory')]
        [string]$InstanceDirectory,
		[Parameter(Mandatory=$true,Position=4,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Please provide the default backup path/directory')]
        [string]$SQLBackupDirectory,
		[Parameter(Mandatory=$true,Position=5,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Please provide the user data path/directory')]
        [string]$SQLUserDBDirectory,
		[Parameter(Mandatory=$true,Position=6,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Please provide the user log path/directory')]
        [string]$SQLUserLogDirectory,
		[Parameter(Mandatory=$true,Position=7,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Please provide the tempdb path/directory')]
        [string]$SQLTempDBDirectory,
		[Parameter(Mandatory=$true,Position=8,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Please provide one Windows AD group that will have SysAdmin access')]
        [string]$SQLSysAdminAccounts,
		[Parameter(Mandatory=$true,Position=9,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Please Specify the Version of SQL Server (2012,2014,2016')]
		[ValidateSet("2012","2014","2016")]
        [string]$SQLVersion
    )
	#Useful article on several ways to remotely install software.
	##http://kunaludapi.blogspot.in/2015/09/multiple-ways-to-install-software.html

	If($(Confirm-IsSQLAlreadyInstalled -HostName $HostName))
	{
		Write-Log -Level WARN -Message " It looks like the default instance of sql is already installed on host: $hostName, skipping Install.."
		return;
	}

    
	#TODO setup our passwords, This needs to change,  the password should go over encrypted and be decrypted on the other side.
	#TODO Better would be pulling the password dynamically from CyberArc on the remote machine.  (cant do that until the cyberarc upgrade.
	$PlainPass = (Convert-SecureStringToPlainText -SecureString $Password)
    $PlainPass=$PlainPass.Replace('^',"`^")
    $PlainPass=$PlainPass.Replace(';',"``;")
    $PlainPass=$PlainPass.Replace('\',"``\")
    $PlainPass=$PlainPass.Replace('&',"``&")
    $PlainPass=$PlainPass.Replace('|',"``|")
    $PlainPass=$PlainPass.Replace('>',"``>")
    $PlainPass=$PlainPass.Replace('<',"``<")
    $PlainPass=$PlainPass.Replace('$',"``$")
    $PlainPass=$PlainPass.Replace('(',"``(")
    $PlainPass=$PlainPass.Replace(')',"``)")
	$PlainPass=$PlainPass.Replace('[',"``[")
    $PlainPass=$PlainPass.Replace(']',"``]")
    $PlainPass=$PlainPass.Replace('{',"``{")
    $PlainPass=$PlainPass.Replace('}',"``}")



	$SAPassword = Get-RandomString -Length 20
    $SAPassword=$SAPassword.Replace('\','1')
    $SAPassword=$SAPassword.Replace('&','1')
    $SAPassword=$SAPassword.Replace('.','2')
	$SAPassword=$SAPassword.Replace('(','3')
    $SAPassword=$SAPassword.Replace(')','3')
    $SAPassword=$SAPassword.Replace('{','4')
	$SAPassword=$SAPassword.Replace('}','4')
	$SAPassword=$SAPassword.Replace(':','5')
	$SAPassword=$SAPassword.Replace(';','5')
	$SAPassword=$SAPassword.Replace('$','A')
	$SAPassword=$SAPassword.Replace('"','E')
	$SAPassword=$SAPassword.Replace("'",'B')
	$SAPassword=$SAPassword.Replace('`','!')
    $SAPassword=$SAPassword.Replace('|','=')
    $SAPassword=$SAPassword.Replace('[','^')
    $SAPassword=$SAPassword.Replace(']','-')
	$SAPassword=$SAPassword.Replace(',','!')
	
	#Get SamAccountName for service.
	$SQLShortAccount = Get-samAccountName -LoginDisplayName $SQLServiceAccount
    
	#set the configini file location
    $SQLConfigini = "$SQLSystemDisk"+":\SQLInstall\SQLConfiguration.ini"
	$SetupLocation = $(Get-DiskImageDriveLetter -HostName $HostName -IsoName "SQL") + "\Setup.exe"
	$UpdateLocation = $SQLSystemDisk+":\SQLInstall\Updates"
	
	Write-Log -Level INFO -Message "Starting install process of SQL Server on Host: $HostName from $env:ComputerName"
	#ISSVCPASSWORD RSSVCPASSWORD
	
	try
	{
		#check if this is an actual remote install
		if($HostName -ne $env:ComputerName)
		{
			Write-Log -Level INFO -Message "Install is not local, current client is $Env:ComputerName, sql server host is $hostName. Enabling PSRemoting..."
			#enabling ps remoting on local client
			try{
				$WinRMStatus = Get-Service -Name "WinRM"
				If($WinRMStatus.Status -ne "Running") # -and $HostName -ne $env:ComputerName)
				{
					Enable-PSRemoting -Force
				}
			}
			catch
			{
				$ExceptionMessage = $_.Exception.Message
				Write-Log -Level ERROR -Message "Error enabling WinRM (PSremoting) on Client $env:ComputerName"
			}
			#create our remote script to run.  add Using command to pipe our local variables over toe the remote host.
			##Insert version check if($SQLVersion)
			if($SQLVersion -ne "2016")
			{
				$scriptBlockVar = { $command = "$Using:SetupLocation /ConfigurationFile=""$Using:SqlConfigini"" /ACTION=""Install"" /IACCEPTSQLSERVERLICENSETERMS /INSTANCEDIR=""$Using:InstanceDirectory"" /SQLBackupDir=""$Using:SQLBackupDirectory"" /SQLUSERDBDIR=""$Using:SQLUserDBDirectory"" /SQLUSERDBLOGDIR=""$Using:SQLUserLogDirectory"" /SQLTEMPDBDIR=""$Using:SQLTempDBDirectory"" /UpdateSource=""$Using:UpdateLocation"" /SQLSYSADMINACCOUNTS=""$Using:SQLSysAdminAccounts"" /SQLSVCACCOUNT=""$Using:SQLShortAccount"" /SQLSVCPASSWORD=""$Using:PlainPass"" /AGTSVCACCOUNT=""$Using:SQLShortAccount"" /AGTSVCPASSWORD=""$Using:PlainPass"" /SAPWD=""$Using:SAPassword"" /Q"
									powershell.exe "$command"}
						            #write-host $command }
			}
			else
			{
				$scriptBlockVar = { $command = "$Using:SetupLocation /ConfigurationFile=""$Using:SqlConfigini"" /ACTION=""Install"" /IACCEPTSQLSERVERLICENSETERMS /INSTANCEDIR=""$Using:InstanceDirectory"" /SQLBackupDir=""$Using:SQLBackupDirectory"" /SQLUSERDBDIR=""$Using:SQLUserDBDirectory"" /SQLUSERDBLOGDIR=""$Using:SQLUserLogDirectory"" /SQLTEMPDBDIR=""$Using:SQLTempDBDirectory"" /UpdateSource=""$Using:UpdateLocation"" /SQLSYSADMINACCOUNTS=""$Using:SQLSysAdminAccounts"" /SQLSVCACCOUNT=""$Using:SQLShortAccount"" /SQLSVCPASSWORD=""$Using:PlainPass"" /AGTSVCACCOUNT=""$Using:SQLShortAccount"" /AGTSVCPASSWORD=""$Using:PlainPass"" /SAPWD=""$Using:SAPassword"" /Q"
									powershell.exe "$command"}
						            #write-host $command }
			}
			#temporarily enable credential sharing between Local host and SQL Server.  Else install will fail when authenticating Service accounts against AD.
			Write-Log -Level INFO -Message "Temporarily enabling WSManCredSSP on $env:COMPUTERNAME as client"
			try
			{
				Enable-WSManCredSSP -Role Client -DelegateComputer "$HostName" -Force | out-null
			}
			catch
			{
				$ExceptionMessage = $_.Exception.Message
				Write-Log -Level ERROR -Message "Unable to enable WSMANCredSSP on $env:COMPUTERNAME as client. ExceptionMessage: $ExceptionMessage"
			}
			Write-Log -Level INFO -Message "Temporarily enabling WSManCredSSP on $hostname as Server"
			try
			{
				Invoke-Command -ComputerName $HostName -ScriptBlock {Enable-WSManCredSSP -Role Server -Force | Out-Null}
				##Confirm SPN was setup for target host to enable PSRemoting
				$SpnListForHostName = get-spn -ComputerName $HostName -ServiceClass "WSMAN"
				If($SpnListForHostName -ne $null -or $SpnListForHostName.Count -gt 0)
				{
				    Write-log -Level INFO -Message "SPN WSMAN created for delegate host: $Hostname successfully."
				}
				Else
				{
				    Write-log -Level Warn -Message "SPN WSMAN does not exist for delegate host: $Hostname, attempting restart of remote service and checking again."
					$RemoteService = Get-Service -ComputerName $hostName -Name "WinRM"
					Restart-Service -InputObject $RemoteService
					sleep 3
					$SpnCheck = Get-SPN -ComputerName $HostName -ServiceClass "WSMAN"
					If($spnCheck -eq $null -or $spnCheck.count -eq 0)
					{
						Write-Log -Level ERROR -Message "Unable to create necessary SPN: WSMAN on host $HostName.  Please use SetSpn.exe to manually create the spn, and rerun the script."
						Throw "error stopping script spn failure"
					}
				}
			}
			Catch
			{
				$ExceptionMessage = $_.Exception.Message
				Write-Log -Level ERROR -Message "Unable to enable WSMANCredSSP on $HostName as Delegate. ExceptionMessage: $ExceptionMessage"
			}

			#Fire Remote command
			Write-Log -Level INFO -Message "Starting install...Enter your credentials."
			Invoke-Command -ScriptBlock $ScriptBlockVar -ComputerName $HostName -Credential $("$Env:USERDOMAIN\$Env:USERNAME")  -Authentication Credssp 

			#Turn off credential sharing.
			Write-Log -Level INFO -Message "Disabling WSManCredSSP on $env:computerName and $hostname"
			Disable-WSManCredSSP -Role Client
			Invoke-Command -ComputerName $HostName -ScriptBlock{Disable-WSManCredSSP -Role Server}
		}
		Else
		{
			#create our remote script to run.  add Using command to pipe our local variables over toe the remote host.
			if($SQLVersion -ne "2016")
			{
				$scriptBlockVar = { $command = "$SetupLocation /ConfigurationFile=""$SqlConfigini"" /ACTION=Install /IACCEPTSQLSERVERLICENSETERMS /INSTANCEDIR=$InstanceDirectory /SQLBackupDir=$SQLBackupDirectory /SQLUSERDBDIR=$SQLUserDBDirectory /SQLUSERDBLOGDIR=$SQLUserLogDirectory /SQLTEMPDBDIR=$SQLTempDBDirectory /UpdateSource=""$UpdateLocation"" /SQLSYSADMINACCOUNTS=""$SQLSysAdminAccounts"" /AGTSVCACCOUNT=""$SQLShortAccount"" /AGTSVCPASSWORD=""$PlainPass"" /SQLSVCACCOUNT=""$SQLShortAccount"" /SQLSVCPASSWORD=""$PlainPass"" /ISSVCACCOUNT=""$SQLShortAccount"" /ISSVCPASSWORD=""$PlainPass"" /SAPWD=""$SAPassword"" /QS"
					                powershell.exe "$command"}
			}
			else
			{
				$scriptBlockVar = { $command = "$SetupLocation /ConfigurationFile=""$SqlConfigini"" /ACTION=Install /IACCEPTSQLSERVERLICENSETERMS /INSTANCEDIR=$InstanceDirectory /SQLBackupDir=$SQLBackupDirectory /SQLUSERDBDIR=$SQLUserDBDirectory /SQLUSERDBLOGDIR=$SQLUserLogDirectory /SQLTEMPDBDIR=$SQLTempDBDirectory /UpdateSource=""$UpdateLocation"" /SQLSYSADMINACCOUNTS=""$SQLSysAdminAccounts"" /AGTSVCACCOUNT=""$SQLShortAccount"" /AGTSVCPASSWORD=""$PlainPass"" /SQLSVCACCOUNT=""$SQLShortAccount"" /SQLSVCPASSWORD=""$PlainPass"" /ISSVCACCOUNT=""$SQLShortAccount"" /ISSVCPASSWORD=""$PlainPass"" /SAPWD=""$SAPassword"" /QS"
					                powershell.exe "$command"}
			}
			Invoke-Command $scriptBlockVar
		}
		#Remove Variables for cleanup and safet
		if($PlainPass -ne $null) 
		{ 
			Remove-Variable plainPass
		}
		if($SAPassword -ne $null)
		{
			Remove-Variable SAPassword
		}
		If($scriptBlockVar -ne $null)
		{
			Remove-Variable scriptBlockVar
		}
		If(!(Confirm-IsSQLAlreadyInstalled -HostName $HostName))
		{
			Write-Log -Level ERROR -Message "SQL failed to install on Host: $Hostname, check the install log on the host, and double check the service account information."
		}
		Write-Log -Level INFO -Message "SQL Install completed on Host: $HostName from $env:ComputerName"
	}
	catch
	{
		$ExceptionMessage = $_.Exception.Message
		Write-Log -Level ERROR -Message "There was an error during the SQL install on host $hostName. Exception: $ExceptionMessage"
	}
}
function Get-SQLConfigIniFile
{
<# 
.SYNOPSIS 
	Finds the SQLConfiguration ini file to pipe to a sql install
.DESCRIPTION 
	Finds the SQLConfiguration ini file to pipe to a sql install. Requires the name of the configuration file to be Engine_Version_Configuration.ini 
	Where Version = Year of sql version (2012, 2014, 2016) and Engine = SQL, SSIS, SSRS
.EXAMPLE 
	Get-SQLConfigIniFile -SQLVersion 2014 -Engine SSIS
	Returns path to ConfigIni file
	returns an imported csv file.
.PARAMETER SQLVersion 
	Version of SQL to install, accepted values are 2012, 2014, 2016
.PARAMETER Engine
	Which component of sql to install.  SQL SSIS or SSRS
.OUTPUT
	Path to ini file.
#> 
	[cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Please select a version (2012,2014, or 2016)')]
        [ValidateSet("2012","2014","2016")]
        [String]$SQLVersion = "2014",
		[Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Please select which engine to install (SQL,SSRS,SSIS')]
        [ValidateSet("SQL","SSIS","SSRS")]
        [String]$Engine = "SQL"
    )
	$FilterString = "$Engine" +"_"+"$SQLVersion"+"_ConfigurationFile.ini"
	$ConfigIniFile = (Get-ChildItem -Path ".\SQLConfigINITemplates\" -Filter "$FilterString").FullName

	##Copy the file to the destination

	if($ConfigIniFile -ne $null)
	{
		return $ConfigIniFile
	}
	else
	{
		Throw "Unable to find Configuration.ini file for SQLVersion: $SQLVersion and Engine: $Engine" 
	}
}

###TODO PASS DRIVE LETTER FOR SYSTEM Drive and use as path to copy files.
###TODO switch to ISO files for SQL 2014, will make copy faster and more accurate. 
###TODO add lookup for all patches in folder path.
function Copy-SQLInstallFiles
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
        [string] $HostName,
		[Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the host name?')]
        [string] $LocalDriveLetter,
        [Parameter(Mandatory=$true,Position=2,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Please select a version (2012,2014, or 2016)')]
        [ValidateSet("2012","2014","2016")]
        [String]$SQLVersion = "2014",
		[Parameter(Mandatory=$true,Position=3,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Please select a version (2012,2014, or 2016)')]
        [ValidateSet("SQL","SSIS","SSRS")]
        [String]$Engine = "SQL",
		[Parameter(Mandatory=$true,Position=4,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Please provide the full path to the sql installation iso')]
        [string] $SQLfiles,
		[Parameter(Mandatory=$false,Position=5,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Please provide a path to all sql patches')]
        [string] $SQLPatches
    )

	If($(Confirm-IsSQLAlreadyInstalled -HostName $HostName))
	{
		Write-Log -Level WARN -Message " It looks like the default instance of sql is already installed on host: $hostName, skipping file copy"
		return;
	}

	#Ensure any old isos are dismounted.  
	Dismount-IsoFile -HostName $HostName -IsoName "SQL"
	Dismount-IsoFile -HostName $HostName -IsoName "Windows"

    $InstallationMediaPath = $SQLfiles
	$InstallationMediaPathPatches = $SQLPatches -split ';'

    try
    {
		#Set Default Destination location
		##TODO add a parameter, base this on the System Disk Letter from the install csv file.
        $Destination = "$LocalDriveLetter$\SQLInstall\"
		
		#if old media is found delete it, to make sure we have the right files.
        If((Test-path "\\$HostName\$Destination"))
        {
            Write-Log -Level WARN -Message "Old install files exist: \\$HostName\$Destination, cleaning up..."
            try
            {
                Remove-Item "\\$HostName\$Destination" -recurse -Force
                Write-Log -Level WARN -Message "Finished file cleanup"
            }
            catch
            {
                $ExecptionMessage = $_.Exception.Message
                $ExceptionItem = $_.Excepetion.ItemName
                Write-Log -Level ERROR -Message "File Cleanup failed: \\$HostName\$Destination, manually cleanup the files.  Stopping installation. $ExecptionMessage $ExceptionItem"
            }
        }
		Write-Log -Level WARN -Message "Install files do not exist at Destination: \\$HostName\$Destination, creating path..."
		try
		{
			New-Item -ItemType Directory -Path "\\$HostName\$Destination" |out-null
		}
		catch
		{
			$ExecptionMessage = $_.Exception.Message
            $ExceptionItem = $_.Excepetion.ItemName
            Write-Log -Level ERROR -Message "Folder creation failed: \\$HostName\$Destination Stopping installation. $ExecptionMessage $ExceptionItem"
		}
        
		#Copy the media to the destination 
		Write-Log -Level INFO -Message "Copying SQL Version: $SQLVersion Media to Destination: $Destination"
		$SQLIsoName = "SQL" + $SQLVersion + "InstallationMedia"
		$IsoPath = Copy-IsoFile -Hostname $HostName -MediaPath $InstallationMediaPath -DestinationPath $Destination -DestinationISOName $SQLIsoName
		Write-Log -Level INFO -Message "Copy of SQL $SQLVersion installation media to $IsoPath complete"
		#MOUNT THE ISO, if there is an error dismount.
		Write-Log -level INFO -Message "Mounting $SQLIsoName ISO on $Global:HostName from $IsoPath."
		try
		{
			$mountResult = Mount-DiskImage -ImagePath $IsoPath.Replace("$",":") -CimSession $Global:HostName -StorageType ISO -PassThru
			$SourceLoc = (($mountResult|Get-Volume).DriveLetter +":\setup.exe")
		}
		catch
		{
			$ExecptionMessage = $_.Exception.Message
			$ExceptionItem = $_.Excepetion.ItemName
			Dismount-IsoFile -HostName $HostName -IsoName "SQL"
            Write-Log -Level ERROR -Message "Mouting SQL ISO failed. HostName: \\$HostName. $ExecptionMessage $ExceptionItem"
		}
		Write-Log -Level INFO -Message "SQL ISO was mount on $Global:HostName to location: $SourceLoc"
		########################
		#Copy all patches to updates folder for slip stream install
		
		##Make Update Directory
		$UpdateDirectory = "\\$HostName\$LocalDriveLetter$\SQLInstall\Updates"
		If((Test-Path $UpdateDirectory))
		{
			Write-Log -Level WARN -Message "Cleaning Updates Directory ($UpdateDirectory) on host: $HostName"
			Remove-Item $UpdateDirectory -Recurse -Force
		}
		Write-Log -Level INFO -Message "Creating directory ($UpdateDirectory) for Updates on host: $HostName "
		New-Item $UpdateDirectory -ItemType Directory | Out-Null
		Write-Log -Level INFO -Message "Created Directory"
        
		If(($InstallationMediaPathPatches.Length -gt 1))
        {
			Foreach($PatchPath in $InstallationMediaPathPatches)
			{
				Write-Log -Level INFO -Message "Copying SQL $SQLVersion PATCH Media: $PatchPath  to \\$Hostname\S$\SQLInstall\Updates"
				Copy-DirectoryWithBITSTransfer -SourceDirectory  $PatchPath -DestinationDirectory "\\$HostName\S$\SQLInstall\Updates"
				Write-Log -Level INFO -Message "Copy of PATCHES: $PatchPath to \\$Hostname\S$\SQLInstall\Updates complete"
			}
        }

		#Copy the correct configuration.ini file for a commandline install.
		$ConfigurationIniFile = (Get-SQLConfigIniFile -SQLVersion $SQLVersion -Engine $Engine)
		Write-Log -Level INFO -Message "Copying configuration.ini file from $ConfigurationIniFile to $($Destination)SQLConfiguration.ini"
        $Destination = "\\$Hostname\$Destination"
		Start-BitsTransfer -Source $ConfigurationIniFile -Destination "$($Destination)SQLConfiguration.ini" -Description "Transfer of SQL Configuration.ini file" -DisplayName "SQLConfiguration.ini"
		Write-Log -Level INFO -Message "Copy SQLConfiguration.ini file complete"
    }
    catch
    {
        $ExecptionMessage = $_.Exception.Message
        $ExceptionItem = $_.Excepetion.ItemName
		Dismount-IsoFile -HostName $HostName -IsoName "SQL"
        Write-Log -Level ERROR -Message "Copying installation media failed. Stopping installation. $ExecptionMessage $ExceptionItem"
    }
}