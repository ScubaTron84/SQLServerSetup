#
# AAWHSQLDatabaseMigrations.psm1
#
function Run-SQLQuery {
<# 
.SYNOPSIS 
	Execute a sql query, return the results as a table
.DESCRIPTION 
	Execute a sql query, return the results as a table
.EXAMPLE 
	Execute-SQLQuery -InstanceName "SXDCVSQL04" -DatabaseName "DBAdmin" -query "SELECT * FROM dbo.MyTable" -ApplicationName "MyTestApplication"
.PARAMETER InstanceName 
	Instance of SQL server to query.
.PARAMETER DatabaseName
	Name of the database to query.
.PARAMETER query
	The TSQL query to execute
.PARAMETER SQLConnection
	If you already have a sqlconnection pass it through and reuse the connection
.PARAMETER ApplicationName
	Name of the application or script executing the command.  Used to make the script identifiable on the sql process list.
.OUTPUT
	System.Data.DataTable object of databases with names, online status, recovery mode, and page verify option as columns.
#> 
	Param
	(	
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
		[string]$InstanceName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the Database name?')]
		[string]$DatabaseName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the query name?')]
		[string]$query,
		[Parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the connection Object?')]
		[System.Data.SqlClient.SqlConnection] $SQLConnection,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the application name?')]
		[string] $ApplicationName
	)

	if($SQLConnection -eq $null)
	{
		$sqlConnection = New-Object System.Data.SqlClient.SqlConnection
		$sqlConnection.ConnectionString = "Server=$InstanceName;Database=$DatabaseName;Integrated Security=SSPI;Application Name=$ApplicationName"
	}
	
	$Command = New-Object System.Data.SQLclient.SQLCommand 
	$Command.Commandtimeout = 120 
	$Command.CommandType = 'text'
	$Command.CommandText = $query
	$Command.Connection = $sqlConnection
	
	##need to refactor this to leave this as a persistant open connection if the connection string was already provided. 
	$sqlConnection.Open()
	$Reader = $Command.ExecuteReader()
    $DataTable = New-Object System.Data.DataTable
    $DataTable.Load($reader)
	$sqlConnection.Close()
	
    return $DataTable
}
function Get-DatabasesToMigrate
{
##TODO LOOK FOR DATABASES ALREADY MIRRORED....ASSUMING MIRRORING WILL BE PRIMARY METHOD FOR MIGRATING OLD Databases (pre and including 2008 R2, for 2012 and higher use always on)
    Param
    (
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the source instance name?')]
		[string]$SourceInstanceName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='are their any databases you dont want ot migrate (separate by comma)?')]
		[string]$DatabasesToExclude,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the target instance name?')]
		[string]$TargetInstanceName

    )
$Query = @"
SELECT d.name, recovery_model, SUM(mf.size)*8.0/1024.0 as DBsizeMB 
FROM sys.databases d
inner join sys.master_files mf on d.database_id = mf.database_id
Left join sys.database_mirroring dm on d.database_id = dm.database_id
WHERE d.Database_ID > 4 
AND d.State <> 6
and d.is_read_only = 0
AND d.name NOT IN ('DBAdmin',$DatabasesToExclude)
AND dm.mirroring_guid is NOT NULL
Group by d.name, recovery_model
order by SUM(mf.size)*8.0/1024.0 asc
"@

 $Results = Invoke-Sqlcmd -ServerInstance $SourceInstanceName -Query $Query 
 return $Results
}

function Check-AlwaysOnEnabled
{
 <# 
.SYNOPSIS 
	Verifies alwaysOn is enabled on an instance 
.DESCRIPTION 
	Verifies Alwayson is enabled on a given SQL Server instance.  USES SQL SMO objects to verify status.
.EXAMPLE 
	Test-AlwaysOnEnabled -InstanceName "SXDCVSQL04"
.PARAMETER InstanceName 
	Instance of SQL server to query.
.OUTPUT
	returns $true if enabled, false if disabled.
#> 
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
        [string] $InstanceName,
		[Parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='SMO Object')]
		[Microsoft.SQLServer.Management.SMO.server] $SMO
    )

    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SQLServer.SMO')|Out-Null
    $SQLObject = New-Object Microsoft.SQLServer.Management.SMO.Server($InstanceName)

    Return $SQLObject.IsHadrEnabled
}

function Backup-MultiFileSQLDatabase
{
 <# 
.SYNOPSIS 
	Peforms a full database backup to 4 separate files to one backup directory.  
.DESCRIPTION 
	This is mainly used to initialize a fresh copy of a database on a new server.  Peforms a full backup from a target, and saves the files to a network path as 4 separate files.
.EXAMPLE 
	Backup-MultiFileSQLDatabase -InstanceName "SXDCVSQL04" -DatabaseName "Master" -BackupPath "\\SXDCFDS02\SQL_Backup2\Migrations"
.PARAMETER InstanceName 
	Instance of SQL server to query.
.PARAMETER DatabaseName
    Name of the database to be backed up
.PARAMETER BackupPath
    Network path to store the backup.
.OUTPUT
	returns a string array of backup files.
#> 
	Param
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
        [string] $InstanceName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the account running sql server?')]
		[string] $DatabaseName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the account running sql server?')]
		[string] $BackupPath
	)
    
    if (!($backuppath.EndsWith('\')))
    {
        $BackupPath +='\'
    }
    [string]$CurrentDateTime = $(Get-Date -Format ddMMyyyy_HHmmss).ToString()

    [string[]]$Backupfiles = @()
    $Backupfiles += ($BackupPath + "_"+$DatabaseName+"_"+$CurrentDateTime+"_01.bak")
    $Backupfiles += ($BackupPath + "_"+$DatabaseName+"_"+$CurrentDateTime+"_02.bak")
    $Backupfiles += ($BackupPath + "_"+$DatabaseName+"_"+$CurrentDateTime+"_03.bak")
    $Backupfiles += ($BackupPath + "_"+$DatabaseName+"_"+$CurrentDateTime+"_04.bak")
    
    Backup-SqlDatabase -ServerInstance $InstanceName -Database $DatabaseName -BackupFile $Backupfiles -BackupAction Database -Initialize

    return $Backupfiles
}
#Function Restore-MultiFileDatabaseBackup
#{
# <# 
#.SYNOPSIS 
#	Peforms a full database backup to 4 separate files to one backup directory.  
#.DESCRIPTION 
#	This is mainly used to initialize a fresh copy of a database on a new server.  Peforms a full backup from a target, and saves the files to a network path as 4 separate files.
#.EXAMPLE 
#	Backup-MultiFileSQLDatabase -InstanceName "SXDCVSQL04" -DatabaseName "Master" -BackupPath "\\SXDCFDS02\SQL_Backup2\Migrations"
#.PARAMETER InstanceName 
#	Instance of SQL server to query.
#.PARAMETER DatabaseName
#    Name of the database to be backed up
#.PARAMETER BackupPath
#    Network path to store the backup.
#.OUTPUT
#	returns a string array of backup files.
##> 
#	Param
#	(
#		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
#        [string] $InstanceName,
#		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the account running sql server?')]
#		[string] $DatabaseName,
#        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the account running sql server?')]
#		[string] $BackupPath
#	)
#    
#    if (!($backuppath.EndsWith('\')))
#    {
#        $BackupPath +='\'
#    }
#    [string]$CurrentDateTime = $(Get-Date -Format ddMMyyyy_HHmmss).ToString()
#
#    [string[]]$Backupfiles = @()
#    $Backupfiles += ($BackupPath + "_"+$DatabaseName+"_"+$CurrentDateTime+"_01.bak")
#    $Backupfiles += ($BackupPath + "_"+$DatabaseName+"_"+$CurrentDateTime+"_02.bak")
#    $Backupfiles += ($BackupPath + "_"+$DatabaseName+"_"+$CurrentDateTime+"_03.bak")
#    $Backupfiles += ($BackupPath + "_"+$DatabaseName+"_"+$CurrentDateTime+"_04.bak")
#    
#    Backup-SqlDatabase -ServerInstance $InstanceName -Database $DatabaseName -BackupFile $Backupfiles -BackupAction Database -Initialize
#
#    return $Backupfiles
#}
function Set-DatabaseRecoveryModel
{
<# 
.SYNOPSIS 
	Changes the recovery model of a database using Invoke-SQLCmd and a written query statement instead of SQL ps objects.  
.DESCRIPTION 
	Changes the recovery model of a database using Invoke-SQLCmd and a written query statement instead of SQL ps objects.  
.EXAMPLE 
	Set-DatabaseRecoveryModel -InstanceName SXDCVSQL01 -DatabaseName "Model" -RecoveryModel "FULL"
.PARAMETER InstanceName 
	Instance of SQL server to query.
.PARAMETER DatabaseName
    Name of the database to be backed up
.PARAMETER RecoveryModel
    The recovery option of the database. Valid options are FULL, BULK-LOGGED, or SIMPLE
.OUTPUT
	results of change request.
#> 
    Param
    (
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
		[string]$InstanceName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the database name?')]
		[string]$DatabaseName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What recovery model do you want?')]
        [ValidateSet("FULL","Bulk-Logged","SIMPLE")]
		[string]$RecoveryModel
    )

$Query = @"
ALTER DATABASE [$DatabaseName] SET RECOVERY $RecoveryModel
"@
write-host "here $instanceName $databaseName $RecoveryModel"
Write-host $Query
 $Results = Invoke-Sqlcmd -ServerInstance $InstanceName -Query $Query
 return $Results

}