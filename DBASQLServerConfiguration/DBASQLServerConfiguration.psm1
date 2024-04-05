##Load the SQLServer SQLWmiManagment library
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SqlWmiManagement')| Out-Null
Function Confirm-ServiceIsUp
{
	<#
	.SYNOPSIS 
		Checks if a service is up, if not, checks every 5 seconds for a status change up to one minute.
	.DESCRIPTION 
		Checks if a service is up, if not, checks every 5 seconds for a status change up to one minute.
	.EXAMPLE 
		Confirm-ServiceIsUp -HostName "SXDCNewVSQLInstance" -ServiceName
	.PARAMETER HostName
		Name of the target host
	.PARAMETER ServiceName
		Name of the service to find, actual servicename not the Service DisplayName.
	.OUTPUT
		Bool
	#>
	[cmdletbinding()]
	Param
	(
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the host?')]
		[string]$HostName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the service to check?')]
		[string]$ServiceName
	)
		$i = 0
		While ($(Get-Service -ComputerName $HostName -Name $ServiceName).Status -ne "Running" -and $i -lt 12)
		{
			write-log -Level INFO -Message "Waiting on service: $ServiceName on Host: $HostName to start...."
			sleep 5
			$i++
		}
		$CheckService = Get-Service -ComputerName $HostName -Name $ServiceName
		if($CheckService.Status -eq "Running")
		{
			Write-Log -Level INFO -Message "Successfully started service: $ServiceName on host: $HostName."
			return $true
		}   
		else
		{
			Write-Log -Level Error -Message "Service: $ServiceName, failed to start on host: $HostName. haulting script.  Please investigate."
			return $false
		}
}
Function Get-SQLVersion
{
	<#
	.SYNOPSIS 
		Gets the full product version number of sql server
	.DESCRIPTION 
		Runs the following query: SELECT SERVERPROPERTY('ProductVersion') AS ProductVersion, against a target instance.  Returns a string value of the full product version.
	.EXAMPLE 
		Get-SQLVersion -InstanceName "SXDCNewVSQLInstance"
	.PARAMETER InstanceName
		The instance of sql server to configure
	.OUTPUT
		System.Data.Row containing a single entry of type string, with the full productnumber.  ex.  2008 R2 10.50.0000
	#>
	[cmdletbinding()]
	Param
	(
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
		[string]$InstanceName
	)
	$Query = @"
SELECT SERVERPROPERTY('ProductVersion') AS ProductVersion
"@
	$Results = Invoke-Sqlcmd -ServerInstance $InstanceName -Query $Query 
	return $Results
}
function Confirm-IsAlwaysOnEnabled
{
	Param
	(
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
		[string]$InstanceName
	)
	$Query = @"
SELECT SERVERPROPERTY('IsHadrEnabled') AS IsHadrEnabled
"@
	$Results = Invoke-Sqlcmd -ServerInstance $InstanceName -Query $Query 
	If($Results.IsHadrEnabled -eq 1)
	{
		return $true
	}
	else
	{
		return $false
	}
}

function Set-AlwaysOnOn
{
<#
	.SYNOPSIS 
		Force AlwaysOn to enabled.
	.DESCRIPTION 
		Forcibly enables alwaysOn for a target instance.  This uses WinRM to remotely call Enable-SQLAlwayson powershell functions.  This allows us to enforce the correct version of the SQLPS libraries to be used.
	.EXAMPLE 
		Set-AlwaysOnOn -InstanceName ServerInstance1
	.PARAMETER InstanceName
		The instance of sql server to configure
#>
	[cmdletbinding()]
	Param
	(
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
		[string]$InstanceName
	)
		#Enable AlwaysOn via SQLPS command Enable-SQLAlwaysOn.  Need to run as a remote command,  since the version here matters.
		$ScriptBlock = {
					#Load the assembly by partial name lookup
					[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SqlWmiManagement')|Out-Null
					Enable-SqlAlwaysOn -ServerInstance $Using:InstanceName -Force
                   }
		Invoke-Command -ComputerName $HostName -ScriptBlock $ScriptBlock
}
function Set-SQLStartupParameters
{
	<#
	.SYNOPSIS 
		Add or changes startup paramters to sql server.
	.DESCRIPTION 
		Changes or adds additional SQL Startup parameters. This can be used to change -d (master data file location), -e (errorlog location, -l (master log file location)
		or Set new Trace flags, -T3226.  NOTE THIS REPLACES EXISTING TRACE FLAGS.  If you want to keep them, add them to the list.  This does not restart the SQL Service, you must do so
		manually after the trace flags are set.
	.EXAMPLE 
		Set-SQLStartupParameters -InstanceName "SXDCNewVSQLInstance" -HostName $hostName -StartUpParameters -T2115,-T3226,-T1222
	.PARAMETER InstanceName
		The instance of sql server to configure
	.PARAMETER HostName
		The name of the host that the SQL server lives on.
	.LINK
		https://github.com/MikeFal/PowerShell/blob/master/Set-SqlStartupParameters.ps1 
	#>
	[cmdletbinding(SupportsShouldProcess=$true)]
	Param
	(
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
		[string]$InstanceName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the Host name?')]
		[string]$HostName,
		[Parameter(Mandatory = $true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Which flag do you want set?')]
		[string[]]$StartupParameters
	)
	#1118 removes single page alocation, reducing contention on SGAM
	#1204 gathers deadlock info.
	#3605  dumps deadlock to error log
	#1222 dumps the deadlock as XML.
	##3023 Enables checksum option by default for backup command.
	#3226  Prevents log backups from writting success messages to sql server error log every log backup.
	#4136 prevent parameter sniffing
    [bool]$SystemPaths = $false
    
	#Get the instance name base on service naming convention.
	$InstanceName = ($InstanceName.Split('\'))[1]
    #Get service account names, set service account for change
    $ServiceName = if($InstanceName){"MSSQL`$$InstanceName"}else{'MSSQLSERVER'}
	
    <#Use wmi to change account, need to invoke-command on target host directly.
	Unfortunately there is currently a bug in SQL Management SMO libraries.  Each version is not fully compatible with all versions of SQL.
	If the wrong version is used, it will not return Service Information, parameters, etc.
	To get around this we do the same command we would normally do, but on the freshly installed SQL server.  
	This will ensure the right version of the Management SMO is used.
	We pipe back the results, and once we are ready to update the parameters, we send the new list over in the same way.
	#>
    $ScriptBlock = {
					#Load the assembly by partial name lookup
					[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SqlWmiManagement')|Out-Null
					#Create our special SQL Management Object with Windows Management Instruments.
                    $smowmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer $Using:HostName
					#pull out the service for sql server.  NOTE we do this from SMOWMI to WMI, to ensure we get the startup parameters.  Else we wont, and can corrupt the service.
                    $wmisvc = $smowmi.Services | Where-Object {$_.Name -eq $Using:ServiceName}
                    $oldParams = $wmisvc.StartupParameters -split ';'
                    return $oldParams
                   }

	$CurrentStartupParams = Invoke-Command -ComputerName $HostName -ScriptBlock $ScriptBlock

    Write-Log -Level INFO -Message "Old Parameters for Instance: $InstanceName on Host: $HostName...."
    Write-Log -Level INFO -Message "Old Params:  $CurrentStartupParams"

    #Wrangle updated params with existing startup params (-d,-e,-l)
	if($CurrentStartupParams.count -eq 0)
	{
		Write-Log -Level WARN -Message "Missing Parameters -d,-e,-l for instance: $InstanceName"
		Write-Log -Level ERROR -Message "Unable to Pull default Startup Parameters for Instance: $InstanceName.  Ensure the script is running with ADMINISTRATOR PERMISSIONS!!"
	}
    $newparams = @()
	$RequestedParams = $StartupParameters -split ';'
    foreach($param in $RequestedParams){
        if($param.Substring(0,2) -match '-d|-e|-l')
		{
            $SystemPaths = $true
            $newparams += $param
            $CurrentStartupParams = $CurrentStartupParams | Where-Object {$_.Substring(0,2) -ne $param.Substring(0,2)}
        }
		elseif($CurrentStartupParams -contains $param)
		{
			Write-Log -Level WARN -Message "SQL Instance: $InstanceName already has Startup Parameter: $param, skipping this param"
		}
        else
		{
            $newparams += $param
        }
    }
	if($newparams.Count -gt 0)
	{
		$newparams += $CurrentStartupParams | Where-Object {$_.Substring(0,2) -match '-d|-e|-l'}
		$paramstring = ($newparams | Sort-Object) -join ';'
		
		Write-Log -Level INFO -Message "New Startup Parameters for SQL instance: $InstanceName on Host: $HostName...."
		Write-Log -Level  INFO -Message $paramstring

		#If not -WhatIf, apply the change. Otherwise display an informational message.
		if($PSCmdlet.ShouldProcess($InstanceName,$paramstring))
		{
			$ScriptBlock = {
							#Load the assembly by partial name lookup
							[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SqlWmiManagement')|Out-Null
							#Create our special SQL Management Object with Windows Management Instruments.
							$smowmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer $Using:HostName
							#pull out the service for sql server.  NOTE we do this from SMOWMI to WMI, to ensure we get the startup parameters.  Else we wont, and can corrupt the service.
							$wmisvc = $smowmi.Services | Where-Object {$_.Name -eq $Using:ServiceName}
							#Change the Startup Parameters for SQL
							$wmisvc.StartupParameters = $Using:paramstring
							#Commit the changes!
							$wmisvc.Alter()
							#NOTE THE CHANGES WILL NOT TAKE AFFECT UNTIL A SQL SERVER SERVICE RESTART
							return $wmisvc.StartupParameters
						}

			$NewStartupParams = Invoke-Command -ComputerName $HostName -ScriptBlock $ScriptBlock
		    Write-Log -Level WARN -Message "Startup Parameters for SQL instance: $InstanceName updated."
			Write-Log -Level INFO -Message "New Parameters: $($NewStartupParams -join ';' )"
			Write-Log -Level WARN -Message "You will need to restart the service for these changes to take effect."
		    If($SystemPaths)
			{
				Write-Log -Level WARN -Message "You have changed the system paths for SQL Instance: $InstanceName. Please make sure the paths are valid before restarting the service"
			}
			return $true
		}
	}
	else
	{
		Write-Log -Level INFO -Message "SQL Instance: $InstanceName, 0 new Startup Parameters to add.  Moving on.." 
		return $false
	}
}

function Get-ProcessorCount
{
	<#
	.SYNOPSIS 
		Get the number of LOGICAL processors on the host. SQL Sees the Logical number as the total of processors to work with.
	.DESCRIPTION 
		Using WMI interfaces, returns the number of processors available to a sql server host.
	.EXAMPLE 
		Get-ProcessorCount -HostName "SXDCNewVSQLInstance"
	.PARAMETER HostName
		The Hostname of the server the sql instance is installed on.
	.OUTPUT 
		an integer return value.
	#>
	[cmdletbinding()]
	Param
	(
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
		[string]$HostName
	)
	#ToDo Try catch
	$HostInformation = $(Get-WmiObject -Class Win32_ComputerSystem -ComputerName $HostName)
	[int] $LogicalProcessorCount = $HostInformation.NumberOfLogicalProcessors
	Return $LogicalProcessorCount

}

function Get-MemoryCount
{
	<#
	.SYNOPSIS 
		Get the amount of memory installed on a host.
	.DESCRIPTION 
		Using WMI interfaces, returns the amount of memory available in GB.
	.EXAMPLE 
		Get-MemoryCount -HostName "SXDCNewVSQLInstance"
	.PARAMETER HostName
		The Hostname of the server the sql instance is installed on.
	#>
	[cmdletbinding()]
	Param
	(
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the Host name?')]
		[string] $HostName
	)

	$WmiOutput = get-wmiobject -Class win32_ComputerSystem -Namespace root\CIMV2 -ComputerName $HostName
	$MemoryCountGB = [math]::Round($WmiOutput.TotalPhysicalMemory/1024/1024/1024, 0)

	return $MemoryCountGB
}

function Get-DiskSizeByLetter
{
	<#
	.SYNOPSIS 
		Get the size of disk on a host by drive letter.
	.DESCRIPTION 
		Get the size of disk on a host by drive letter.
	.EXAMPLE 
		Get-DiskSizeByLetter -HostName "SXDCNewVSQLHost"
	.PARAMETER HostName
		The Hostname of the server the sql instance is installed on.
	.OUTPUT
		integer, size of the drive in GB.  
	#>
	[cmdletbinding()]
	Param
	(
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the Host name?')]
		[string] $HostName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is drive letter?')]
		[string] $DriveLetter
	)
	#Size is actually returned in bytes, need to do math to get it to GB. https://msdn.microsoft.com/en-us/library/windows/desktop/hh830524(v=vs.85).aspx
	$SizeGB = [MATH]::Round((Get-Partition -CimSession $HostName -DriveLetter $DriveLetter).Size)/1024/1024/1024
	return $SizeGB
}

function Get-TempDBDriveLocation
{
	<#
	.SYNOPSIS 
		Gets the Drive Letter for the default tempdb files.
	.DESCRIPTION 
		Connects to the sql instance, to pull the  location of first two tempdb files.  If they match the letter is returned.
		thing on the disk).  
	.EXAMPLE 
		Get-TempDBDriveLocation -InstanceName "Hostname\SQLInstanceName"
	.PARAMETER InstanceName
		The InstanceName of the sql server
	.OUTPUT
		One character for the drive letter of tempdb.
	#>
		[cmdletbinding()]
	Param
	(
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
		[string] $InstanceName
	)
	##Connect to sql, get host name
$Query =@"
SELECT
Physical_Name
FROM sys.master_files
WHERE Database_Id = 2
"@
	#query for tempdb files
	$QueryResults = Invoke-Sqlcmd -Serverinstance $InstanceName -query $Query
	
	#If file count is bigger than 2, tempdb has already been partially
	if($QueryResults.Count -ne 2)
	{
		Write-Log -Level WARN -Message "There are more than 2 tempdb files already on instance: $InstanceName, skipping tempdb configuration.  Please investigate manually."
		return;
	}
	
	#Returns and object array.  The object has the property Physical_Name
	#Compare the data file and log file, make sure they are on the same drive, if not throw a warning.
	$FirstFile = $QueryResults[0].Physical_Name 
	$SecondFile = $QueryResults[1].Physical_Name 

	If ($FirstFile.SubString(0,$FirstFile.IndexOf(':')) -ne $SecondFile.SubString(0,$SecondFile.IndexOf(':')) )
	{
		Write-Log -Level WARN -Message "The TempDB files are on Different drives for instance: $InstanceName, something might be wrong. Please investigate manually."
		return;
	}

	#only two files on the same drive as expected, return drive letter
	return $($FirstFile.SubString(0,$FirstFile.IndexOf(':')))
}
Function Get-HostNameOfSQLInstance
{
	<#
	.SYNOPSIS 
		Gets the underlying host name for a sqlinstance
	.DESCRIPTION 
		Connects the the sql instance and queries for the underlying hostname using SERVERPROPERTY
	.EXAMPLE 
		Get-HostNameOfSQLInstance -InstanceName "Hostname\SQLInstanceName"
	.PARAMETER InstanceName
		The Hostname of the server the sql instance is installed on.
	.OUTPUT
		String type, the HostName that the SQL Instance Lives on.  
	#>
	[cmdletbinding()]
	Param
	(
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
		[string] $InstanceName
	)

$Query = @" 
SELECT SERVERPROPERTY('ComputerNamePhysicalNetBios') AS HostName
"@
	#Cheating a little, because we know there will only be one result returned, we can reference the actual column name to get a string value back instead of an object with one Property of Hostname.
	$QueryResult = $(Invoke-Sqlcmd -ServerInstance $InstanceName -Query $Query).HostName

	return $QueryResult

}

Function Measure-TempDBRecommendFileSizes
{
	<#
	.SYNOPSIS 
		Figures out how many files and what size the files should be for tempdb.
	.DESCRIPTION 
		Figures out how many files and what size the files should be for tempdb. Leverages Get-ProcessorCount and drive size
	.EXAMPLE 
		Get-HostNameOfSQLInstance -InstanceName "Hostname\SQLInstanceName"
	.PARAMETER DriveSizeGB
		The size of the TempDB drive in GB
	.PARAMETER NumberOfProcessors
		The number of processors on the host
	.OUTPUT
		Three ints, SpaceLeftForDataFiles (total space for data files in GB), SingleDataFilesGB (A single datafile size in GB) and TempDBLogFileSpaceGB (
	#>
	[cmdletbinding()]
	Param
	(
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
		[int] $DriveSizeGB,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
		[int] $NumberOfProcessors
	)
	#Leave room on the drive for future expansion of log in an emergency
	$80PercentOfDriveSizeGB = $DriveSizeGB * .80
	$TempDBLogFileSpaceGB = $80PercentOfDriveSizeGB * .30
	#Leave the log with a bit more space than the data drives.
	$SpaceLeftForDataFiles = $80PercentOfDriveSizeGB - $TempDBLogFileSpaceGB
	$SingleDataFileGB = $SpaceLeftForDataFiles/$NumberOfProcessors

	Return $SpaceLeftForDataFiles, $SingleDataFileGB, $TempDBLogFileSpaceGB
}

Function Set-DatabaseFiles
{
	<#
	.SYNOPSIS 
		Set the number of desired data files, data file size, data file grow, log file size, and log growth for a target database.
	.DESCRIPTION 
		This command is used to set a database from 1 data file and 1 log file with the default sizes and growth settings to Multiple datafiles, one log file, and consistant growth and size settings.
	.EXAMPLE 
		Set-DatabaseFiles -InstanceName "Hostname\SQLInstanceName" -DatabaseName "TempDB" -DataFileCount 8 -DataFileSizeMB 20480 -LogFileSizeMB 25480 -DataFileGrowthMB 0 -LogfileGrowthMB 0
	.PARAMETER InstanceName
		The Hostname of the server the sql instance is installed on.
	.PARAMETER DatabaseName
		The Name of the database to change file setup.
	.PARAMETER DataFileCount
		Number of Data files the database will need.
	.PARAMETER DataFileSizeMB
		The initial size of each data file in Megabytes.
	.PARAMETER LogFileSizeMB
		The initial size of the log file in Megabytes.
	.PARAMETER DataFileGrowhtMB
		Growth interval for each data file in Megabytes.  A value of 0 will disable auto growth for the data files. 
	.PARAMETER LogFileGrowhtMB
		Growth interval for the log file in Megabytes.  A value of 0 will disable auto growth for the log file.
	.OUTPUT
		String type, the HostName that the SQL Instance Lives on.  
	#>
	[cmdletbinding()]
	Param
	(
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
		[string]$InstanceName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Which Database?')]
		[string]$DatabaseName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='How many DataFiles should it have?')]
		[int] $DataFileCount,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='How Big should each data file be in MB?')]
		[int] $DataFileSizeMB,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='How Big should the log file be in MB?')]
		[int] $LogFileSizeMB,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='When the data file needs to grow, how many MB should it grow?
		If 0, the data files will be set not to grow')]
		[int] $DataFileGrowthMB,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='When the log file needs to grow, how many MB should it grow?  
		If 0, log file growth will be turned off.')]
		[int] $LogFileGrowthMB
	)

	#on the assumption there is one data file and one log file already

$QueryDatafile = @" 
SELECT Name, physical_name 
FROM sys.master_files  
WHERE Database_id = DB_ID('$DatabaseName')
AND type = 0
"@

$QueryLogFile = @" 
SELECT Name, physical_name  
FROM sys.master_files  
WHERE Database_id = DB_ID('$DatabaseName')
AND type = 1
"@
	[string] $DataGrowthMB = $DataFileGrowthMB.ToString() +"MB"
	[string] $DataSizeMB = $DataFileSizeMB.ToString() +"MB"
	[string] $LogGrowthMB = $LogFileGrowthMB.ToString() +"MB"
	[string] $LogSizeMB = $LogFileSizeMB.ToString() +"MB"
	$DataFileResults = Invoke-Sqlcmd -ServerInstance $InstanceName -Query $QueryDatafile 
	$LogFileResults = Invoke-Sqlcmd -ServerInstance $InstanceName -Query $QueryLogfile 

$QueryFileSettings = @"
USE MASTER
ALTER DATABASE [$DatabaseName] MODIFY FILE ( NAME = N'$($DataFileResults.Name)', SIZE = $DataSizeMB , FILEGROWTH = $DataGrowthMB )
ALTER DATABASE [$DatabaseName] MODIFY FILE ( NAME = N'$($LogFileResults.Name)', SIZE = $LogSizeMB , FILEGROWTH = $LogGrowthMB )

"@

##Get filepath for data files
	$NewFileDataPath = $($DataFileResults.physical_name).Substring(0,$DataFileResults.physical_name.LastIndexOf('\')+1)
	[int] $i = 2
	While ($i -le $DataFileCount)
	{
$QueryTemp = @"
ALTER DATABASE [$DatabaseName] ADD FILE ( NAME = N'$($DataFileResults.Name + $($i.ToString()))', FILENAME = N'$($NewFileDataPath + $DatabaseName.ToString()+$i.ToString()).ndf' , SIZE = $DataSizeMB , FILEGROWTH = $DataGrowthMB)

"@
        $QueryFileSettings+=$QueryTemp
		$i++
	}
	Invoke-sqlcmd -Serverinstance $InstanceName -Database master $QueryFileSettings -QueryTimeout 0
}

Function Get-DatabaseFiles
{
	<# 
	.SYNOPSIS 
		Lists out all of the files in a database
	.DESCRIPTION 
		Configures a sql server per standards, sets startup traces flags, tempdb size, sp_configuration options: query timeout settings, memory limits, ad-hoc workloads; 
		enables database mail, enables always on, creates always on alerts, creates always on endpoints and permissions them, creats sp_help_revlogin and dependencies, 
	.EXAMPLE 
		Get-DatabaseFiles -InstanceName "SXDCNewVSQLInstance" -DatabaseName "TempDB"
	.PARAMETER InstanceName
		The instance of sql server to configure
	.PARAMETER DatabaseName
		A string refering to the database name.
	.OUTPUT
		An array of database files, all properties of sys.Master_files table in sql server
	#>
	[cmdletbinding()]
	Param
	(
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
		[string]$InstanceName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the database?')]
		[string]$DatabaseName
	)

	$FileList = Invoke-Sqlcmd -ServerInstance $InstanceName -Database "master" -Query "SELECT * FROM sys.master_files where Database_id = DB_ID('$DatabaseName')"
	Return $FileList
}

Function Start-AllSQLConfgurationScripts
{
	<# 
	  .SYNOPSIS 
		Configures a sql server for the first time.  WILL RESTART SQL SERVER AS NEEDED.
	  .DESCRIPTION 
		Configures a sql server per standards, sets startup traces flags, tempdb size, sp_configuration options: query timeout settings, memory limits, ad-hoc workloads; 
		enables database mail, enables always on, creates always on alerts, creates always on endpoints and permissions them, creats sp_help_revlogin and dependencies, 
	  .EXAMPLE 
		Start-AllSQLConfgurationScripts -InstanceName "SXDCNewVSQLInstance" -ConfigurationTSQLScriptsPath "C:\Temp\scripts\TSQLConfigurationScripts"
	  .PARAMETER InstanceName
		The instance of sql server to configure
	  .PARAMETER ConfigurationTSQLScriptsPath
		The folder path to the TSQL scripts to run against the instance.
	#>
	[cmdletbinding()]
	Param
	(
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
		[string]$InstanceName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Enter the file path to your sql configuration scripts')]
		[string]$ConfigurationTSQLScriptsPath
	)

	$SQLConfigurationTSQLScripts = (Get-ChildItem -Path $ConfigurationTSQLScriptsPath -Include "*.sql" -Recurse | Sort name )

	Foreach($TSQLScript in $SQLConfigurationTSQLScripts)
	{
		Write-Log -Level INFO -Message "Executing script $TSQLScript on instance: $instanceName"
		Invoke-Sqlcmd -ServerInstance $InstanceName -Database "master" -InputFile $TSQLScript
		Write-Log -Level INFO -Message "Finished script $TSQLScript on instance: $instanceName"
	}
}

Function New-SQLServerConfiguration
{
<# 
  .SYNOPSIS 
	Configures a sql server for the first time.  WILL RESTART SQL SERVER AS NEEDED.
  .DESCRIPTION 
	Configures a sql server per standards, sets startup traces flags, tempdb size, sp_configuration options: query timeout settings, memory limits, ad-hoc workloads; 
	enables database mail, enables always on, creates always on alerts, creates always on endpoints and permissions them, creats sp_help_revlogin and dependencies, 
  .EXAMPLE 
	New-SQLServerConfiguration -InstanceName "SXDCNewVSQLInstance"
  .PARAMETER InstanceName
	The instance of sql server to configure
#>
	[cmdletbinding()]
	Param
	(
    	[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
		[string]$InstanceName,
		[Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Provide a comma separated list of trace flags. ex: -T1226,-T33588')]
		[string[]] $TraceFlagDefaults
	)

	Write-Log -LEVEL INFO -Message "Starting Configuration of SQL server on instance: $InstanceName"
	if((Confirm-IsSQLAlreadyInstalled -HostName $InstanceName))
	{
		$SQLStatus = Get-Service -ComputerName $InstanceName -Name "MSSQLSERVER"
		If($SQLStatus.Status -ne "Running")
		{
			Write-Log -Level WARN -Message "SQL appears to be offline on host: $InstanceName, attempting to start SQL Server"
			$SQLService = Get-Service -ComputerName $InstanceName -Name "MSSQLSERVER"
			$SQLService.Start()
			if(!(Confirm-ServiceIsUp -HostName $InstanceName -ServiceName "MSSQLSERVER"))
			{
				Write-Log -Level Error -Message "SQL Failed to start on host: $InstanceName, You have broken the Flux Capacitor"
			}
		}
	}
	else 
	{
		Write-Log -Level ERROR -Message "SQL is not installed!  Please execute Copy-SQLInstallFiles and Install-SQLServerRemotely first."
	}
	#Getting Underlying Some data for later
	$HostName = Get-HostNameOfSQLInstance -InstanceName $InstanceName
	$ProcCount = Get-ProcessorCount -HostName $HostName
	
	#Make sure the server is up
	If(!(Test-Connection -ComputerName $InstanceName -Quiet))
	{
		Write-Log -LEVEL ERROR -Message "Host/SQL Instance: $InstanceName is not responding to ping, please investigate.."
	}
	#Check the version of SQL Server
	Write-Log -LEVEL INFO -Message "Getting the SQL Product Version for instance: $InstanceName"
	try
	{
		[String] $ProductVersionFull = $(Get-SQLVersion -InstanceName $InstanceName).ProductVersion
		[Int] $ProductMajorVersion = $ProductVersionFull.Substring(0,$ProductVersionFull.IndexOf('.')) -as [Int]
	}
	catch
	{
		$ExecptionMessage = $_.Exception.Message
		$ExceptionItem = $_.Excepetion.ItemName
		Write-Log -LEVEL ERROR -Message "Unable to pull ProductMajorVersion Number for instance: $Instance. Exception: $ExecptionMessage $ExceptionItem"
	}
	#If the product version is 11 (2012) or higher, turn on always on
	If($ProductMajorVersion -gt 10)
	{
		Write-Log -LEVEL INFO -Message "Instance: $InstanceName is version $ProductVersionFull, Checking if AlwaysOn is already enabled"
		if(!$(Confirm-IsAlwaysOnEnabled -InstanceName $InstanceName))
		{
			try
			{
				Write-Log -LEVEL WARN -Message "Force Starting Alwayson for instance: $InstanceName. INSTANCE WILL RESTART"
				Set-AlwaysOnOn -InstanceName $InstanceName
				if(!$(Confirm-IsAlwaysOnEnabled -InstanceName $InstanceName))
				{
					Write-Log -Level WARN -Message "AlwaysOn didnt turn on for instance: $InstanceName, check manually configuration will continue."
				}
			}
			catch
			{
				$ExecptionMessage = $_.Exception.Message
			    $ExceptionItem = $_.Excepetion.ItemName
			    Write-Log -Level ERROR -Message "Unable to Enable AlwaysOn for Instance:$InstanceName, Exception: $ExecptionMessage $ExceptionItem"
			}
			Write-Log -LEVEL INFO -Message "Successfully enabled AlwaysOn for Instance: $InstanceName..."
		}
		else
		{
			Write-Log -LEVEL WARN -Message "AlwaysOn is already enabled on instance: $InstanceName, please confirm manually! The server may have already been configured."
		}
	}

	<# 
		##### Trace Flage list #######
	1118 removes single page alocation, reducing contention on SGAM
	1204 gathers deadlock info.
	3605  dumps deadlock to error log
	1222 dumps the deadlock as XML.
	#3023 Enables checksum option by default for backup command.
	3226  Prevents log backups from writting success messages to sql server error log every log backup.
	4136 prevent parameter sniffing
	#>

	#Set Startup Parameters/Trace Flags
	
	##Check to see if we need new trace flags.
	##[string[]] $TraceFlagDefaults = @("-T1118","-T1204","-T1222","-T3226")
	Write-Log -LEVEL INFO -Message "Checking default startup parameters for SQL Instance: $InstanceName"
	try
	{
		[bool]$didStartupParamsChange = Set-SQLStartupParameters -InstanceName $InstanceName -HostName $HostName -StartupParameters $TraceFlagDefaults
	}
	catch
	{
		$ExecptionMessage = $_.Exception.Message
		$ExceptionItem = $_.Excepetion.ItemName
		Write-Log -Level WARN -Message "Unable to set SQLStartupParameters for Instance:$InstanceName, Please set manually!!! Exception: $ExecptionMessage $ExceptionItem"
	}
	if($didStartupParamsChange)
	{
		Write-Log -Level INFO -Message "Restarting SQL service for Instance: $instanceName for StartUp Parameter Changes"
		try
		{
			#TODO THIS NEEDS TO BE THE SERVICE NAME< GET THAT ABOVE, NOT THE INSTANCE NAME 
			$ServiceToRestart = Get-Service -ComputerName $Hostname -Name "MSSQLSERVER"
			Write-Log -Level INFO -Message "Stopping SQL Service, and sleeping for 45 seconds on instance: $InstanceName"
			$ServiceToRestart.Stop();
			Start-sleeperbar -seconds 45 -ProgressBarTitle "Waiting for sql to start"
			Write-Log -Level INFO -Message "Starting SQL service on instance: $InstanceName"
			$ServiceToRestart.Start();
			[bool]$didSQLStart = Confirm-ServiceIsUp -HostName $HostName -ServiceName "MSSQLSERVER"
			if(!$didSQLStart)
			{
				Write-Log -Level ERROR -Message "SQL didnt start for instance: $InstanceName"
			}
		}
		catch
		{
			$StatusOfService = $(Get-Service -ComputerName $Hostname -Name "MSSQLSERVER").Status
			$ExecptionMessage = $_.Exception.Message
			$ExceptionItem = $_.Excepetion.ItemName
			Write-Log -Level ERROR -Message "Failed to restart SQLServer Services for Instance:$InstanceName, Please CHECK! ServiceStatus is ($StatusOfService) Exception: $ExecptionMessage $ExceptionItem"
		}
		Write-Log -Level INFO -Message "Successfully Started SQL Server Service for instance: $InstanceName"
		Write-Log -Level INFO -Message "TraceFlags Set on Instance: $InstanceName."
	}
	
	#Ensure SQL Agent Came up as well.
	Write-Log -Level INFO -Message "Checking status of SQLAGENT on SQL Instance: $InstanceName."
	$SQLAgentService = $(Get-Service -ComputerName $HostName -Name "SQLSERVERAGENT")

	##Todo figure out a wait for service to be running.
	#TODO make name of SQLSERVERAGENT dynamic
	if($SQLAgentService.Status -ne "Running")
	{
		Write-Log -Level INFO -Message "Starting SQL AGENT for instance: $InstanceName"
		$SQLAgentService.Start()
		Start-SleeperBar -Seconds 45 -ProgressBarTitle "Waiting for SQL agent to come up."
		[bool]$isSQLAgentUp = Confirm-ServiceIsUp -HostName $HostName -ServiceName "SQLSERVERAGENT"
        if(!$isSQLAgentUp)
        {
            Write-Log -Level Error -Message "SQLAGENT failed to start on SQL instance: $IntanceName haulting script.  Please investigate and rerun the script."
        }    
	}
	Write-Log -Level INFO -Message "SQLAGENT Running on SQL Instance $InstanceName"
	##TODO Try Catch block
	#If tempdb only has initial 2 files, configure tempdb, else its already been configured.  Leave it alone.
	Write-Log -Level INFO -Message "Checking Configuration of TempDB on SQL instance: $InstanceName"
	If($(Get-DatabaseFiles -InstanceName $InstanceName -DatabaseName "TempDB").count -eq 2)
	{
		Write-Log -Level INFO -Message "Configuring TempDB for the first time on Instance: $InstanceName. Number of Data files: $ProcCount"
		$TempDBDriveLetter = Get-TempDBDriveLocation -InstanceName $InstanceName
		$TempDBDriveSizeGB = Get-DiskSizeByLetter -HostName $HostName -DriveLetter $TempDBDriveLetter
		##Get recommended sizes of tempdb files spaced on tempdb disk size and number of processors. Then set the files.
		$DataFilesTotalSpaceGB, $SingleDataFileSpaceGB, $LogFileSpaceGB = Measure-TempDBRecommendFileSizes -DriveSizeGB $TempDBDriveSizeGB -NumberOfProcessors $ProcCount
		Write-Log -Level INFO -Message "TempDB files sizes for instance: $InstanceName  Data Files Total Space: $DataFilesTotalSpaceGB, Single Data File Space GB: $SingleDataFileSpaceGB, Log File Space GB: $LogFileSpaceGB"
		Write-Log -Level INFO -Message "Attempting to Resize TempDB on instance: $InstanceName";
		Set-DatabaseFiles -InstanceName $InstanceName -DatabaseName "TempDB" -DataFileCount $ProcCount -DataFileSizeMB ($SingleDataFileSpaceGB * 1024) -LogFileSizeMB ($LogFileSpaceGB * 1024) -DataFileGrowthMB 0 -LogFileGrowthMB 0
		Write-Log -LEVEL INFO -Message "TempDB successfully configured for Instance: $InstanceName"
	}
	else
	{
		##TODO log what the config should be and spit out the sql command to get it there.
		Write-Log -Level WARN -Message "TempDB on instance: $InstanceName has more than 2 files, check manually if it was already configured."
	}
    
    #Run TSQL configurations scripts
	Write-Log -Level INFO -Message "Executing default configuration scripts against SQL Instance: $InstanceName"
    try
    {
        Start-AllSQLConfgurationScripts -InstanceName $InstanceName -ConfigurationTSQLScriptsPath ".\SQLConfigurationScripts"
    }
    catch
    {
        $ExecptionMessage = $_.Exception.Message
		$ExceptionItem = $_.Excepetion.ItemName
		Write-Log -Level Warn -Message "Failed to execute TSQL Configuration Scripts on SQL Instance:$InstanceName, Please run them manually!! $ExceptionMessage, $ExceptionItem"
    }
    Write-Log -LEVEL INFO -Message "SQL Instance: $InstanceName configured complete"    
}
Function Create-NewAlwaysOnGroup
{
<# 
  .SYNOPSIS 
	adds an AlwaysOn group.
  .DESCRIPTION 
	Creates a new AlwaysOn group on a target instance, can join other replicas to the group.
  .EXAMPLE 
	New-SQLServerConfiguration -InstanceName "SXDCNewVSQLInstance"
  .PARAMETER InstanceName
	The instance of sql server to configure
#>
	[cmdletbinding()]
	Param
	(
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What are the Primary Replicas (separated by ,) ?')]
		[string[]]$PrimaryReplicas,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What are the secondary replica names (separated by , )?')]
		[string[]]$SecondaryReplicas,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the new AlwaysOn Group Name?')]
		[string]$AlwaysOnGroupName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the SQL version of the replicas (major)?')]
		[ValidSet(11,12,13,14)]
		[int] $SQLMajorVersion
	)
	$primaryTemplates = $null
	$Query = @"
SELECT SERVERPROPERTY('IsHadrEnabled') AS IsHadrEnabled
"@
	Foreach($Primary in $PrimaryReplicas)
	{

		$HADREndpoint = Invoke-Sqlcmd -ServerInstance $Primary -Database master -QueryTimeout .\1033 -Query 
		$primaryTemplates += New-SqlAvailabilityReplica -AvailabilityMode SynchronousCommit -FailoverMode Automatic -EndpointUrl 
	}
	New-SqlAvailabilityReplica -AvailabilityMode SynchronousCommit -FailoverMode Manual -SessionTimeout 45 -ConnectionModeInPrimaryRole AllowAllConnections -ConnectionModeInSecondaryRole AllowNoConnections -AsTemplate -Name $PrimaryReplica -BackupPriority 50 -
	New-SqlAvailabilityGroup -Name $AlwaysOnGroupName -AutomatedBackupPreference Unknown -HealthCheckTimeout 45 -DatabaseHealthTrigger -AvailabilityReplica

}

Function Get-EndpointURL
{
<# 
  .SYNOPSIS 
	Get the mirroring endpoint url on a sql 
  .DESCRIPTION 
	Uses invoke-sqlcmd to get the mirroring endpoint URL on a sql instance.  
  .EXAMPLE 
	New-SQLServerConfiguration -InstanceName "SXDCNewVSQLInstance"
  .PARAMETER InstanceName
	The instance of sql server to configure
#>
	[cmdletbinding()]
	Param
	(
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What are the SQL InstanceName?')]
		[string[]]$InstanceName
	)

}