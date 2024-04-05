#
# DatabaseRefresher.ps1
#
function Get-DatabaseBackup
{
    param
    (
        [string] $InstanceName,
        [string] $DatabaseName,
        [DateTime] $DateTime
    )
    If($DateTime -eq $null)
    {
        $DateTime = $(Get-Date).AddDays(-1)
    }
    Else
    {
        $DateTime = $DateTime.AddDays(-1)
    }
    [string]$DateTimeString = $DateTime.toString("yyyy-MM-dd HH:mm:ss")

    $Query = @"
SELECT TOP 1 bs.database_name, Bs.backup_start_date, bmf.physical_device_name FROM msdb.dbo.backupset bs INNER JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
WHERE bs.backup_start_date > '$DateTimeString'
AND bs.database_name = '$DatabaseName'
AND bs.type = 'D'
"@
   $BackupFile = Invoke-Sqlcmd -ServerInstance $InstanceName -Database MSDB -Query $Query
   return $backupFile.physical_device_name
}
Function Restore-FileListOnly
{
    
}


###Main###
$DBBackupFile = Get-DatabaseBackup -InstanceName "SXDCAIMSSQL03" -DatabaseName "GTI"
