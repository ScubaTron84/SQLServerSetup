$ErrorActionPreference = "Stop"
function Get-DatabasesReadyForMirroring
{
    Param
    (
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
		[string]$InstanceName
    )
$Query = @"
SELECT d.name, recovery_model, SUM(mf.size)*8.0/1024.0 as DBsizeMB 
FROM sys.databases d
inner join sys.master_files mf on d.database_id = mf.database_id
Left join sys.database_mirroring dm on d.database_id = dm.database_id
WHERE d.Database_ID > 4 
AND d.State not in (6,1)
and d.is_read_only = 0
AND d.name IN ('XDCVCenterDB')
and dm.mirroring_guid is null
Group by d.name, recovery_model
order by SUM(mf.size)*8.0/1024.0 asc
"@

 $Results = Invoke-Sqlcmd -ServerInstance $InstanceName -Query $Query 
 return $Results

}

Function Get-RestoreFileListOnlyResults
{
	[cmdletbinding()]
	Param
	(
	   	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
		[string]$InstanceName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is fullpath to the backup file?')]
		[string]$BackupFilePath
	)

		$query = "RESTORE FILELISTONLY FROM DISK =N'$BackupFilePath'"
		$FileList = Invoke-Sqlcmd -ServerInstance $InstanceName -Database "master" -Query $query -QueryTimeout 0
		return $FileList
}

function Get-DefaultDatabasePaths
{
	[cmdletbinding()]
    Param
    (
    	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the instance name?')]
		[string]$InstanceName
	)

	$QueryDataPath = "SELECT SERVERPROPERTY('InstanceDefaultDataPath') AS DefaultDataPath"
	$QueryLogPath = "SELECT SERVERPROPERTY('InstanceDefaultLogPath') AS DefaultLogPath"
	$DataPath = Invoke-Sqlcmd -ServerInstance $InstanceName -Query $QueryDataPath -QueryTimeout 0
	$LogPath = Invoke-Sqlcmd -ServerInstance $InstanceName -Query $QueryLogPath -QueryTimeout 0

	return $DataPath,$LogPath

}

function Set-DatabaseRecoveryModel
{
	[cmdletbinding()]
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

##Main##
CLS
[string]$PrincipalInstance = $(Read-host -Prompt "What is the prinicpal Instance name?:").ToString()
[string]$FailoverPartnerInstance = $(Read-Host -Prompt "What is the Failover Partner Instance name?:").ToString()
[string]$BackupFilePath = $(Read-Host -Prompt "Where do you want to put the backups? (hit enter for default):").ToString()
[string]$AsyncMode = $(Read-Host -Prompt "Do you want to set the databases to ASYNC Mirrors? (Y/N)").ToString()

if($BackupFilePath.Length -le 1)
{
	$BackupFilePath ="\\shdqsqlarc01\SQLSERVER_Archive_03\MirrorSetup\"
} 
if(!$BackupFilePath.EndsWith('\'))
{
	$BackupFilePath+='\'
}

write-host "The principal is: $PrincipalInstance, the Failover Partner is: $FailoverPartnerInstance. AyncMode is $AsyncMode. BackupFilePath is $BackupFilePath"

#Get list of dbs to mirror
$Databases = Get-DatabasesReadyForMirroring $PrincipalInstance
$Databases
Foreach($DB in $Databases)
{
  
  #Get the current DB to mirror
  $Dbname = $null
  $recoveryModel = $null
  $Dbname = $DB.Name
  $recoveryModel = $DB.Recovery_model

  #announce which database is currently being worked on, between which instances.
  Write-host "Setting up mirror for DB: $Dbname, between XDC: $PrincipalInstance and MDC: $FailoverPartnerInstance"

  #make sure the DB is in full recovery.
  if($recoveryModel -ne 1)
  {
    write-host "Recovery Model is not FULL. Changing recovery to Full."
    $RecoveryChange = Set-DatabaseRecoveryModel -InstanceName $PrincipalInstance -DatabaseName $Dbname -RecoveryModel FULL
    $RecoveryChange 
  }

  #Take a backup from principal server
  $fullBackupFiles = @()
  $fullBackupfiles += "$BackupFilePath"+$Dbname+"_01.bak"
  $fullBackupfiles += "$BackupFilePath"+$Dbname+"_02.bak"
  $fullBackupfiles += "$BackupFilePath"+$Dbname+"_03.bak"
  $fullBackupfiles += "$BackupFilePath"+$Dbname+"_04.bak"
  write-Host "Backing Up DB: $Dbname from Server: $PrincipalInstance  to location: $($fullBackupFiles[0])"
  Backup-SqlDatabase -BackupAction Database -ServerInstance $PrincipalInstance -Database $DBname -BackupFile $FullBackupFiles -Initialize #-Compression On
  
  #Get the database file information, so we can move it to other drives as needed
  $DatabaseFileList = Get-RestoreFileListOnlyResults -InstanceName $FailoverPartnerInstance -BackupFilePath $fullBackupFiles[0] 

  #Get the Default Database File and log paths on the failover partner.
  $DefaultData,$DefaultLog = Get-DefaultDatabasePaths -InstanceName $FailoverPartnerInstance

  #make sure the default paths end in \
  If (!$DefaultData.DefaultDataPath.EndsWith('\'))
  {
    $DefaultData.DefaultDataPath+= '\'
  }
  If (!$DefaultLog.DefaultLogPath.EndsWith('\'))
  {
    $DefaultLog.DefaultLogPath+= '\'
  }

  #update the Data file paths to the new default location
  Foreach ($file in $DatabaseFileList)
  {
    if($file.Type -eq 'D')
    {
        $file.PhysicalName = $DefaultData.DefaultDataPath + $file.PhysicalName.SubString($file.PhysicalName.LastIndexOf('\'))
    }
    elseif($file.Type -eq 'L')
    {
        $file.PhysicalName = $DefaultLog.DefaultLogPath + $file.PhysicalName.SubString($file.PhysicalName.LastIndexOf('\'))
    }
  }

  #Create the array of files to relocate
  $FilesToRelocate =@() 
  Foreach ($file in $DatabaseFileList)
  {
    $RelocateData = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($file.LogicalName.ToString(), $file.PhysicalName.ToString())
    $FilesToRelocate += $RelocateData
  }

  #Restore Database to FailoverPartner
  write-Host "Restoring DB: $Dbname to Server: $FailoverPartnerInstance from location: $($fullBackupFiles[0])"
  Restore-SqlDatabase -RestoreAction Database -ServerInstance $FailoverPartnerInstance -Database $DBName -BackupFile $FullBackupFiles -ReplaceDatabase -NoRecovery -RelocateFile $FilesToRelocate
  
  #Backup Log from principal
  $LogBackupFile = $null
  $LogBackupFile = "$BackupFilePath"+$dbname+"_MirrorLog.trn"
  write-Host "Backing Up Log of DB: $Dbname from Server: $PrincipalInstance  to location: $LogBackupFile "
  Backup-SqlDatabase -BackupAction Log -ServerInstance $PrincipalInstance -Database $DBname -BackupFile $LogBackupFile  -Initialize
  
  #Restore Log to FailoverPartner
  write-Host "Restoring Log of DB: $Dbname to Server: $FailoverPartnerInstance from location: $LogBackupFile" 
  Restore-SqlDatabase -RestoreAction Log -ServerInstance $FailoverPartnerInstance -Database $DBName -BackupFile $LogBackupFile -NoRecovery
  
  #Enable Mirroring for Failover Partner
  $PrincipalEndpoint = 'TCP://'+$PrincipalInstance+'.aawh.******.com:5022'
  $FailoverMirrorQuery = "ALTER DATABASE ["+$Dbname+"] SET PARTNER = '$PrincipalEndpoint'; "
  Write-host "Enabling mirroring for DB: $Dbname on server: $FailoverPartnerInstance"
  Invoke-Sqlcmd -ServerInstance $FailoverPartnerInstance -Database "Master"  -Query $FailoverMirrorQuery
  
  #Enable Mirroring on Principle
  $FailoverEndpoint = 'TCP://'+$FailoverPartnerInstance+'.aawh.*******.com:5022'
  $FailoverMirrorQuery = "ALTER DATABASE ["+$Dbname+"] SET PARTNER = '$FailoverEndpoint'; "
  $MirrorSafetyQuery = "ALTER DATABASE ["+$Dbname+"] SET SAFETY OFF;"
  Write-host "Enabling mirroring for DB: $Dbname on server: $PrincipalInstance"
  Invoke-Sqlcmd -ServerInstance $PrincipalInstance -Database "master" -Query $FailoverMirrorQuery
  
  #Set Mirror to Async Mode if $AsyncMode = Y
  If($AsyncMode -eq 'Y')
  {
    Write-host "Setting mirroring for DB: $Dbname on server: $PrincipalInstance to ASYNC mode."
    Invoke-Sqlcmd -ServerInstance $PrincipalInstance -Database "master" -Query $MirrorSafetyQuery
  }
  
  write-host "Finished mirroring $Dbname"

}

Write-Host "Databases mirrored"