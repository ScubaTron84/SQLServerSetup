#
# UpgradeToEnterprise.ps1
#
<# 
	Author: ScubaTron84
	Date: 2017-09-13
	Version 1.0.0.0
	Description: To upgrade a target SQL Server to Enterpise edition from Developer
#>

##############
#### MAIN ####
##############
CLS
#Set current path to path of script invocation
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Set-Location $scriptDir
$LogStamp = (Get-Date -Format "yyyymmdd_hhMMss").toString()
$Global:Logfile = ".\LogFile_$LogStamp.txt"

##Import DBA Modules
Import-Module .\DBAOSConfiguration -Force
Import-Module .\DBAClusterInstall -Force
Import-Module .\DBASQLServerInstall -Force
Import-Module .\DBASQLServerConfiguration -Force
#Import Microsoft Modules
Import-Module BitsTransfer -Force |out-null #Microsoft Windows Module, not loaded by default
Import-Module ActiveDirectory -Force | Out-Null #Active directory module, used to move the computer from one ou to another.


<# 
	1.)find the server
	2.) check who is running sql, 
	2.5) copy iso files and patches to box
	3.) if Dev, swap accounts.
	4.) run the upgrade
	5.) Include slip stream patches
	6.) See if TEMP DB is on the right drive
	7.) move TEMP DB files to appropriate

#>

Foreach ($ServerName in $HostList){
	
	#Confirm sql is already installed.  
		Confirm-IsSQLAlreadyInstalled -HostName $ServerName
	#Copy SQL server install files to local host target
		Copy-SQLInstallFiles -HostName $ServerName -SQLVersion $SQLVersion -Engine $Engine -LocalDriveLetter $SQLSystemDisk -SQLfiles $SQLfiles -SQLPatches $SQLpatches
	
	#Install SQL Server Remotely
			Install-SQLServerRemotely -HostName $HostName -SQLServiceAccount $SQLServiceLogin -Password $SQLServiceLoginPassword `
				-InstanceDirectory "$($SQLSystemDisk):$($SQLSystemPath)" -SQLBackupDirectory "$($SQLBackupDisk):$($SQLBackupPath)"`
				-SQLUserDBDirectory	"$($UserDataDisk):$($UserDataPath)" -SQLUserLogDirectory "$($UserLogDisk):$($UserLogPath)"`
				-SQLTempDBDirectory	"$($TempDBDisk):$($TempDBPath)"` -SQLSysAdminAccounts "Domain\DBAdmins" -SQLVersion $SQLVersion
	##Post install cleanup
		CleanupPostInstall
		Write-Log -Level INFO -Message "Setup of SQL Server Complete for $HostName"
}
