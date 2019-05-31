#
# RestoreMultiFileBackup.ps1
#
#Function Restore-MultiFileDatabaseBackup
#{
# <# 
#.SYNOPSIS 
#	Peforms a full database backup to 4 separate files to one backup directory.  
#.DESCRIPTION 
#	This is mainly used to initialize a fresh copy of a database on a new server.  Peforms a full backup from a target, and saves the files to a network path as 4 separate files.
#.EXAMPLE 
#	Backup-MultiFileSQLDatabase -InstanceName "TESTSERVER" -DatabaseName "Master" -BackupPath "\\ABackupServerShare\SQL_Backup2\Migrations"
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