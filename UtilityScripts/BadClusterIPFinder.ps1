#
# BadClusterIPFinder.ps1
#

#class to capture a Cluster IP object
Class SQLClusterIp
{
    #Properties
    [string] $ClusterName 
    [string] $SQLInstanceName
    [Microsoft.FailoverClusters.PowerShell.ClusterParameter[]] $IPParamList
    [bool] $cleanIps = $true

    #Constructors
    SQLClusterIp([string] $SQLServer)
    {
        $this.SQLInstanceName = $SQLServer
    }

    [void] GetClusterNameFromSQLName()
    {
        $Query = "SELECT SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS NodeName"
        $Results = Invoke-Sqlcmd -ServerInstance $this.SQLInstanceName -Query $Query -Database master -ConnectionTimeout 0 -QueryTimeout 10
        $this.ClusterName = Get-Cluster $Results.NodeName 
    }

    [Void]GetClusterIpResources()
    {
        Try
        {
            [Microsoft.FailoverClusters.PowerShell.Cluster]$clusterObj = Get-Cluster -Name $this.ClusterName 
            [Microsoft.FailoverClusters.PowerShell.ClusterResource[]]$Resources = Get-ClusterResource -InputObject $clusterObj | WHERE {$_.ResourceType -eq "IP Address"}
            [Microsoft.FailoverClusters.PowerShell.ClusterParameter[]]$IpList = @()
            Foreach($res in $Resources)
            {
                $this.IPParamList += Get-ClusterParameter -InputObject $res -Name "Address"
            }
        }
        Catch
        {
            Write-Error -Exception $_.exception 
        }  
    }
    [void] CheckCleanIps()
    {
        Foreach ($ipAddress in $this.IPParamList)
        {
            if($ipAddress.Value -like "10.22.*")
            {
                $this.cleanIps = $false
                break
            }
        }
        
    }
}

##Main##
$MySQLNames = @("")
$GLobal:ManualFollowup = @()
$GoodClusterList = @()
$BadClusterList = @()
Foreach ($SQLName in $MySQLNames)
{
    $SQLClusterIpObject = [SQLClusterIp]::new($SQLName)
    try
    {
        $SQLClusterIpObject.GetClusterNameFromSQLName()
    }
    catch
    {
        $GLobal:ManualFollowup += $SQLClusterIpObject
    }
    $SQLClusterIpObject.GetClusterIpResources()
    $SQLClusterIpObject.CheckCleanIps()
    if($SQLClusterIpObject.cleanIps -eq $false)
    {
        $BadClusterList += $SQLClusterIpObject
    }
    else
    {
        $GoodClusterList +=$SQLClusterIpObject
    }
}

Write-Host "------These Cluster are okay------" -ForegroundColor Green
$GoodClusterList
Write-Host " ------Bad hosts------" 
$BadClusterList

Foreach ($Bad in $BadClusterList)
{
    Write-Host "---Specific Ips to remove For: $($Bad.ClusterName),$($Bad.SQLInstanceName)--- " -ForegroundColor Yellow
    Foreach ($IpObj in $($Bad.IPParamList))
    {
      If ($ipobj.Value -notlike "10.224.*")
      {
        Write-Host "$($IpObj.ClusterObject), $($IpObj.Value)"
      }
    }
     Write-Host "`n"
}