#
# UpdatePowerPlans.ps1
#
Import-module .\DBAOSConfiguration -Force
Import-Module ActiveDirectory

Function Get-AllSQLservers
{
	[cmdletbinding()]
	Param
	(
		[String] $SQLOuPath = "OU=SQL,OU=Computer Resources,DC=AAWH,DC=******,DC=com" 
	)

	$SQLServers = (Get-ADComputer -SearchBase $SQLOuPath -Filter "Description -notlike 'Failover Cluster*'").Name
	Return $SQLServers
}

Write-Host "Getting all sql servers from default OU path: OU=SQL,OU=Computer Resources,DC=AAWH,DC=******,DC=com"
$SQLServers = Get-AllSQLservers

Foreach($SQLServer in $SQLServers)
{
	Set-OSPowerPlan -HostName 
}

