#
# AlwaysOnDatabases.ps1
#

##############
#### MAIN ####
##############
CLS
#Set current path to path of script invocation
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Set-Location $scriptDir
$LogStamp = (Get-Date -Format "yyyymmdd_hhMMss").toString()
$Global:Logfile = ".\LogFile_$LogStamp.txt"

##Import AAWH Modules
Import-Module .\AAWHClusterInstall -Force 
Import-Module .\AAWHOSConfiguration -Force
Import-Module .\AAWHSQLServerInstall -Force
Import-Module .\AAWHSQLDatabaseMigrations -Force
#Import Microsoft Modules
Import-Module BitsTransfer -Force |out-null #Microsoft Windows Module, not loaded by default 

#Declare Globals for later use use
$Global:ApplicationName = "AlwaysOnDatabases.ps1"
$Global:InteractionLevel = $null
$Global:PrimaryReplica = $null
$Global:SecondaryReplicas = @()
$Global:SQLServerConfig = $null
$Global:Databases = @()
$Global:HADRPortNumber =$null
$Global:HADRdomain = $null

##Interactive install prompt, see if the user wants to run an unattended install or not.
$TitleInteractiveMode ="Interactive Mode"
$MessageInteractiveMode = "Do you want to run the script in Interactive mode or Unattended? Unattended will continue without verification."
$Unattended = New-Object System.Management.Automation.Host.ChoiceDescription "&Unattended", `
    "The databases will all be added to the default always on group will run in AutoPilot mode."
$Interactive = New-Object System.Management.Automation.Host.ChoiceDescription "&Interactive", `
    "User will be prompted for input and confirmation throughout the install."
$OptionsInteractiveMode = [System.Management.Automation.Host.ChoiceDescription[]]($Unattended, $Interactive)
$Global:InteractionLevel = $host.ui.PromptForChoice($titleInteractiveMode, $messageInteractiveMode, $OptionsInteractiveMode, 0) 

##Based on user selection, tell the user what iwll happen next.
switch ($Global:InteractionLevel)
    {
        0 {Write-Log -Level INFO -Message "You selected Unattended."}
        1 {Write-Log -Level INFO -Message "You selected Interactive."}
    }
##Interactive Install selected.  Prompt for the ServerName and config file location.  
### TODO: Needs to include prompts between steps of code.  Prompt for everything. 
If($Global:InteractionLevel -eq 1)
{
    $Global:PrimaryReplica = read-host -Prompt "Principal Replica Server Name:" 
    Write-Log -Level INFO -Message "Server Selected: $Global:PrimaryReplica"
	$host.UI.RawUI.WindowTitle = "AlwaysOn initialization: $Global:PrimaryReplica"
}

#Create the connection to the primary replica
$PrimaryReplicaConnectionString = New-Object System.Data.SQLClient.SQLConnection ("Server=$Global:PrimaryReplica;Integrated Security=SSPI;Database=master;Application Name=AlwaysOnDatabases.ps1;")
#Optional do all primary only replica stuff here, then delve into the secondaries:
#Check Always on is on,
#MakeSure endpoint is up.
#Create Alwayson Group if it doesnt exists

	
	#Setup Secondary Replica
	ForEach ($SecondaryReplica in $Global:SecondaryReplicas)
	{
		#$SecondaryReplicaConnectionString = New-Object System.Data.SQLClient.SQLConnection ("Server=$Global:SecondaryReplica;Integrated Security=TRUE;Database=master;Application Name=AlwaysOnDatabases.ps1;")
		If(!(Check-AlwaysOnEnabled -InstanceName $SecondaryReplica))
		{
			write-log -level WARN -Message "AlwaysOn Disabled on instance: $SecondaryReplica.  Attempting to enable..."
			try
			{
				Enable-SqlAlwaysOn -ServerInstance $SecondaryReplica -Force -NoServiceRestart
			}
			catch
			{
				 Write-Log -Level error -Message "Failed to enable alwayson for instance: $SecondaryReplica"
			}
			Write-Log -Level Info -Message "alwaysOn now enabled on instance: $SecondaryReplica"
		}
		Else
		{
			Write-Log -Level INFO -Message "AlwaysOn is already enabled..."
		}
		#Make Sure endpoint is up
		$EndpointTable = new-object System.Data.DataTable
		$EndpointQuery = @"
						 SELECT e.name,tcpe.port 
						 FROM sys.endpoints e 
						 INNER JOIN sys.tcp_endpoints  tcpe 
							ON tcpe.endpoint_id = e.endpoint_id
						 WHERE e.type = 4 
"@
		$EndpointTable = Run-SQLQuery -InstanceName $SecondaryReplica -DatabaseName "Master" -query $EndpointQuery -ApplicationName $Global:ApplicationName
		If($EndpointTable.count -ne 1)
		{
			Write-Log -Level Error -Message "Mirroring Endpoint not set on $SecondaryReplica"
		}
			#gets the FQDN
		$FullDomainName = [System.Net.Dns]::GetHostByName($SecondaryReplica).HostName
		#Join replica to always on group
		#Foreach DB, restore it 
		#Take a diff From Source 
		#Restore Diff
		#Take Log from source
		#restore it
		#Join the DB to the always on group.
		
	}


#Connect to the source SQL server
#Connect to the destination SQL server
#Make sure always on is on for both
#Make sure the endpoint is setup
##if not create it per the standard
#Create the always on group
#join both replicas
##Set Synchronization style based on...........config file?
#Set database to full recovery
#Make sure log backups are set for the databases
#Disable Log backup jobs
#Add initial database to group
##if needed take a backup
#Backup the databases
#Restore the databases
#Backup the TLogs
#Restore the TLogs
#Join Secondary databases to group.