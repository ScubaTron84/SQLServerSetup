##will be the bulk of setting up a cluster, calling the smaller functions
##TODO Add flag for storage vs no storage
## add node preference for IPs so SXDC ips only go to SXDC nodes etc.
## Remove forced failover from advanced policy on FileShare resource group.  Dont want the cluster to fail over on a witness drop.
Function Initialize-NewCluster
{
<# 
.SYNOPSIS 
	Setup a new cluster
.DESCRIPTION 
	This function will try to create a new cluster based on the cluster name provided.  If the cluster name already exists on the domain, the function will attempt to add the node to 
	the cluster instead.
.EXAMPLE 
	Initialize-NewCluster -HostName MyFavoriteComputer -ClusterName "MyNewCluster" -ClusterIPAddress "172.19.23.15" -SQLOU OU=SQL.OU=Computers.DC=aawh.DC=aa.=DC=com -fileShareWitnessPath \\SomeServer\SomeShare -DataCenter Primary -ListenerGroup SQL_AOLN_Creators
.PARAMETER HostName
	Hostname you are trying to create the cluster with or add to the cluster.
.PARAMETER ClusterName
	Name of the cluster object.  (CNO)
.PARAMETER ClusterIpAddress
	Address to add for the cluster name, resource.
.PARAMETER SQLOU
	Path to the OU
.PARAMETER FileShareWitnessPath
	FileShare to be used as the witness.
.PARAMETER DataCenter
	Which datacenter does the server live (primary, Secondary, HDQ)
.PARAMETER ListenerGroup
.OUTPUTS 
	None
#>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the name of the host?')]
        [string] $HostName,
        [Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the clustername ?')]
        [string] $ClusterName,
        [Parameter(Mandatory=$false,Position=2,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What The ip for the cluster name?')]
        [string] $ClusterIpAddress,
        [Parameter(Mandatory=$true,Position=3,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What Ou for the cluster?')]
        [string] $SQLOU,
        [Parameter(Mandatory=$true,Position=4,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the path to the witness file share?')]
        [string] $FileShareWitnessPath,
		[Parameter(Mandatory=$true,Position=5,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Which data center is this server in?')]
        [string] $DataCenter,
		[Parameter(Mandatory=$false,Position=6,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='Which Group does this cluster obj need to be in to create listeners?')]
        [string] $ListenerGroup

    )

	#ClusterIPName Initilization
	$ClusterIPName = $null

    #build the cluster network name based on the host name
    switch ($DataCenter)
	{
		"Primary" { $ClusterIPName = "Cluster IP PD" }
		"Secondary" { $ClusterIPName = "Cluster IP DR" }
		"HDQ" { $ClusterIPName = "Cluster IP HDQ" }
		Default { $ClusterIPName = "Cluster IP $HostName" }
	}

   #create the new cluster if it doesnt exist
   Try
   {
		Write-Log -Level INFO -Message "Checking if Cluster: $ClusterName exists already."
		#if the get-cluster fails, the catch will create it.
		if(Test-ADComputerObjectExists -ObjectDisplayName $ClusterName)
		{
			Write-Log -Level INFO -Message "Cluster $ClusterName already exists, checking if Host: $HostName, is already a node member."
			
			#Get the cluster object
			$ClusterObj = Get-Cluster $ClusterName
			
			#Add a new node with an ip, if its not already part of the cluster
			If(!(Resolve-IsNodeMemberOfCluster -HostName $HostName -ClusterObj $ClusterObj))
			{
				Write-Log -Level INFO -Message "The Host $hostname is not a member of the cluster $ClusterName.  Adding it as a new node."
				Add-NewClusterNode -HostName $HostName -ClusterObj $ClusterObj -ClusterIpAddress $ClusterIpAddress -ClusterIpAddressName $ClusterIPName
			}
			else
			{
				Write-Log -Level WARN -Message "The Host $Hostname is already a node in the cluster $ClusterName."
			}
			
			#Check if the Fileshare was already added or not
			##TODO cleawn up make one line with Cluster Resources
			$resources = $ClusterObj | Get-ClusterResource
			if($resources.Name -notcontains "File Share Witness" -or $($resources |Get-ClusterParameter | Where {$_.name -eq "SharePath"}).Value -ne $FileShareWitnessPath)
			{
				Set-ClusterQuorum -NodeAndFileShareMajority $FileShareWitnessPath -Cluster $($clusterObj.Name) -ErrorAction Stop | Out-Null
			}
			#TODO BUG HERE FIX THIS STUFF SO you can set a network resource dependency.
			$ipResources = Get-ClusterResource -Cluster $ClusterName | WHERE { $_.ResourceType -eq "IP Address" -and $_.OwnerGroup -eq "Cluster Group"}
			if($ipResources.Count -eq 2)
			{
				Set-ClusterNameIPDependency -ClusterName $ClusterName -ClusterNameIPResourceName1 ($ClusterIPName.Replace("DR","PD")) -ClusterNameIPResourceName2 ($ClusterIPName.Replace("PD","DR"))
			}
			elseif($ipResources.Count -eq 1 -and $ipResources.name -notcontains $ClusterIPName )  # swicth this to check if ipResource.IP not contains.
			{
				Add-ClusterNetworkNameIP -ClusterName $ClusterName -ClusterIPName $ClusterIPName -IpAddress $ClusterIpAddress
				$ipResources = Get-ClusterResource -Cluster $ClusterName | WHERE { $_.ResourceType -eq "IP Address" -and $_.OwnerGroup -eq "Cluster Group"}
				if($ipResources.Count -eq 2)
				{
					Set-ClusterNameIPDependency -ClusterName $ClusterName -ClusterNameIPResourceName1 ($ClusterIPName.Replace("DR","PD")) -ClusterNameIPResourceName2 ($ClusterIPName.Replace("PD","DR"))
				}
			}
			Write-Log -Level INFO -Message "Cluster Setup step complete for cluster: $ClusterName and node: $HostName"
		}
	   #Cluster does not exist in AD
		else
		{
			Write-Log -level INFO -Message "did not find Cluster: $ClusterName. CNO not registered in AD.  Creating New cluster"
			##Cluster didnt exist, create it without network or storage
			###Build Full OU placement string
			$SQLOU = $SQLOU.Trim()
			$SQLOU = $SQLOU.Replace('.',',')
			If(!($SQLOU.EndsWith(',')))
			{
				$SQLOU=$SQLOU.Trim()+','  ##adding trim for strange addition of extra whitespace
			}
			$CNPath = "CN=$ClusterName,"+$SQLOU+"DC=aawh,DC=******,DC=com"
			write-log -level INFO -Message "New path AD Object Path for cluster: $CNPath"

			if(Test-IpAddressInUse -IpAddress $ClusterIpAddress)
			{
				Write-Log -Level ERROR -Message "Cannot create new Cluster $ClusterName.  IP Address $ClusterIPAddress is already in use! Halting install."
			}

			$ClusterObj = New-Cluster -Name $CNPath -Node $HostName -StaticAddress $ClusterIpAddress -NoStorage -errorAction Stop
			##Update cluster Ip Resource Name
			Write-Log -Level INFO -Message "Cluster $ClusterName Created.  Adjusting Network Resource Name."
			$resourceIP = $ClusterObj | Get-ClusterResource | Where {$_.Name -eq "Cluster IP Address" -and $_.OwnerGroup -eq "Cluster Group"}
			if($resourceIP -ne $null)
			{
				$resourceIP.Name = $ClusterIPName
			}
			else
			{
				Write-Log -Level Error -Message "Unable to set Cluster $ClusterName resource Cluster IP address name to $ClusterIPName, did not find resource."
			}
			##Sleeping to allow completion of Cluster creation
			Write-log -level INFO -Message "Sleeping for 15 minutes so the cluster name registers in ActiveDirectoy And Replicates"
			Start-SleeperBar -Seconds 900 -ProgressBarTitle "Waiting for ClusterName replication in AD"

			##Add Quorum FileShare Witness
			Try
			{
				Write-Log -Level INFO -Message "Setting Quorum FileShare: $FileShareWitnessPath on Cluster: $($clusterObj.Name)"
				Set-ClusterQuorum -NodeAndFileShareMajority $FileShareWitnessPath -Cluster $($clusterObj.Name) -ErrorAction Stop | Out-Null
				Write-log -Level INFO -Message "FileShare witness set for $($clusterObj.name)"
			}
			Catch
			{
				$ExceptionMessage = $_.Exception.Message
				write-log -Level WARN -Message "Unable to add fileshare witness. A second attempt will be madew when a new node is added. Exception:$ExceptionMessage"
			}
			
			Write-Log -Level INFO "New Cluster: $ClusterName created Successfully with node: $HostName"
		}

		##Add the cluster name to the listener creation AD Group
		write-log -level INFO -message "Checking if Cluster Name is a member of SQL_AOLN_Creators.  This group allows a cluster to create AO listeners."
		
		try
		{
			$SQLAOLNCreatorMembers = (Get-ADGroupMember -Identity $ListenerGroup -Recursive | WHERE {$_.ObjectClass -eq "Computer" } |  SELECT -ExpandProperty Name )
			if($SQLAOLNCreatorMembers -notcontains $($ClusterObj.Name))
			{
				Write-Log -Level WARN -Message "Cluster: $(ClusterObj.Name) is not a member of the Listener Creation Group: $ListenerGroup.  Adding new member..."
				$ComputerObj = Get-ADComputer -Identity $($ClusterObj.Name)
				$GroupObj = Get-ADGroup -Identity $ListenerGroup
				Add-ADGroupMember -Identity $GroupObj -Members $ComputerObj
			}
			Write-Log -Level INFO -Message "Cluster: $($ClusterObj.Name) is a member of the ListenerGroup: $ListenerGroup"
		}
		catch
		{
			$ExceptionMessage = $_.Exception.Message
			write-log -Level WARN -Message "Unable to add Cluster: $($ClusterObj.name) to SQL_AOLN_Creators. Please manually add this to the add group. Or the cluster will not be able to create listeners. Exception:$ExceptionMessage"
		}
   }
   catch
   {
		$ExceptionMessage = $_.Exception.Message
		write-log -Level ERROR -Message "Something went wrong creating the new cluster: $ClusterName with node: $hostName. Exception:$ExceptionMessage"
   }
}
Function Resolve-IsNodeMemberOfCluster
{
<# 
.SYNOPSIS 
	Checks if a host is already a node in a given cluster
.DESCRIPTION 
	This function attempts to validate if the supplied cluster exists, and if the supplied host is currently a member.  If the cluster exists and the 
	node is not a member, false is returned. If the cluster exists and the node is already a member, true is returned.  If the clsuter does not exist, 
	the function fails.
.PARAMETER HostName
	Hostname you are trying to create the cluster with or add to the cluster.
.PARAMETER ClusterName
	Name of the cluster object.  (CNO)
.PARAMETER ClusterObj
	Microsoft failoverCluster Powershell object.
.OUTPUTS 
	Bool
.EXAMPLE 
	Resolve-IsNodeMemberOfCluster -HostName "SXDCSOMEServer" -ClusterName "SXDCTestCluster"
.EXAMPLE
	Resolve-IsNodeMemberOfCluster -HostName SXDCSOMEServer -ClusterObj $MyClusterObject
#>
	[cmdletbinding()]
	param
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What SQL Server Instance?')]
		[string] $HostName,
		[Parameter(Mandatory=$true,ParameterSetName='ClusterName',ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What SQL Server Instance?')]
		[string] $ClusterName,
		[Parameter(Mandatory=$true,ParameterSetName='ClusterObject',ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What SQL Server Instance?')]
		[Microsoft.FailoverClusters.PowerShell.Cluster] $ClusterObj
	)
	try
	{
		If($ClusterObj -eq $null)
		{
			If((Test-ADComputerObjectExists -ObjectDisplayName $ClusterName))
			{
				$ClusterObj = Get-Cluster $ClusterName
			}
			else
			{
				Write-Log -Level ERROR -Message "Error Validating Host: $HostName, is member of Cluster: $ClusterName. Cluster Does Not Exists!"
			}
		}
		Else
		{
			$ClusterName = $ClusterObj.Name
		}
		$ClusterNodes = ($ClusterObj | Get-ClusterNode)
		
		If($ClusterNodes.Name -notcontains $hostName)
		{
			return $false;
		}
		else 
		{
			return $true;
		}
	}
	catch
	{
		$Exception = $_.Exception.Message
		Write-Log -Level ERROR -Message "Error Validating Host:$HostName is member of Cluster:$ClusterName. Exception: $Exception"
	}
}

##Add an ip address to the core cluster group
Function Add-NewClusterNode
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What SQL Server Instance?')]
        [string] $HostName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What SQL Server Instance?')]
        [Microsoft.FailoverClusters.PowerShell.Cluster] $ClusterObj,
        [Parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What SQL Server Instance?')]
        [string] $ClusterIpAddress,
        [Parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What SQL Server Instance?')]
        [string] $ClusterIpAddressName
    )
        
        #Try to add the node
        try
        {
            Write-Log -Level INFO -Message "Adding Cluster Node $HostName to cluster: $($clusterObj.Name)"
            Add-ClusterNode -Cluster $ClusterObj -Name $HostName -NoStorage
            Write-Log -Level INFO -Message "Successfully added node: $HostName to Cluster $($clusterObj.Name)"
        }
        catch 
        {
			$ExceptionMessage = $_.Exception.Message
            Write-Log -Level ERROR -Message "Unable to add the clusterNode $HostName to cluster: $($clusterObj.Name). Exception: $ExceptionMessage" 
        }
		If($ClusterIpAddress -ne $null)
        {
				Add-ClusterNetworkNameIP -ClusterName $clusterName -ClusterIPName $ClusterIpAddressName -IpAddress $ClusterIpAddress 
        }
}

Function Add-ClusterNetworkNameIP
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the cluster name?')]
        [string] $ClusterName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What cluster network RESOURCE name?')]
        [string] $ClusterIPName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What ip address?')]
        [string] $IpAddress
    )

    try
    {
        write-log -Level INFO -Message "Checking if Cluster IP needs to be added/updated Cluster Network Name IP Resource.  Cluster: $ClusterName, Network Resource Name: $ClusterIPName, IP: $IpAddress"

        ## get our cluster object
        $cluster = Get-Cluster -Name $ClusterName
        ##limit our needs down to the default cluster group
        $clusterGroup = $cluster|get-clusterGroup "Cluster Group"

        ##check to see if the ips already exists
        $res = $clusterGroup | Get-ClusterResource

        ##verify we dont already have this IP added as a resource
        $IpList = ($res | WHERE {$_.ResourceType.Name -eq "IP Address"} | Get-ClusterParameter | WHERE{$_.name -eq "Address"}).value

		if($IpAddress -eq $null)
		{
			Write-Log -Level ERROR -Message "Cannot add NULL ip to Cluster: $ClusterName for Cluster IP named: $ClusterIPName"
		}

        if($IpList -notcontains $IpAddress)
        {
			#If the ip is not a resource, make sure another host isn't using it already
			If((Test-IpAddressInUse -IpAddress $IpAddress))
			{
				Write-Log -Level ERROR -Message "Cannot Add IP Address $IpAddress to cluster $ClusterName.  IP is already in use by another system. Please confirm you have the correct IP."
			}
			Else
			{
				$NewResource = Add-ClusterResource -Name $ClusterIPName -Group $clusterGroup -Cluster $ClusterName -ResourceType "IP Address"
				Set-IPParameters -IPResourceObj $NewResource -IPAddress $IpAddress
				write-log -Level info -Message "Successfully Added Cluster Network Name IP Resource.  Cluster: $ClusterName, Network Resource Name: $ClusterIPName, IP: $IpAddress"
			}
        }
		Else
		{
			Write-Log -Level INFO "IP address: $IpAddres is already a resource of the cluster $ClusterName.  Skipping addition of IP Resource."
		}
    }
    catch
    {
		$Exception = $_.Exception.Message 
        write-log -Level ERROR -Message "Unable to add cluster Network Name IP address resource. Exception: $Exception"
    }
}

Function Set-IPParameters
{
    [cmdletbinding()]
    Param(
            [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='what is the cluster resource?')]
            [Microsoft.FailoverClusters.PowerShell.ClusterResource] $IPResourceObj,
            [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What ip address?')]
            [string] $IpAddress
        )
    try
    {
        Write-Log -Level INFO -Message "Attempting to set IP Address resource Parameters"
        $IPAddressParam = New-Object Microsoft.FailoverClusters.PowerShell.ClusterParameter $IPResourceObj,Address,$IpAddress
        $IPSubnetParam = New-Object Microsoft.FailoverClusters.PowerShell.ClusterParameter $IPResourceObj,SubnetMask,255.255.255.0
        $params = $IPAddressParam,$IPSubnetParam
        $params | Set-ClusterParameter
        Write-Log -Level INFO -Message "Successfully set IP Address resource Parameters"
    }
    catch
    {
		$Exception = $_.Exception.Message
        Write-Log -Level ERROR -Message "Error setting IP address resource Parameters. Exception: $Exception"
    }
}
function Test-IpAddressInUse
{
<# 
.SYNOPSIS 
	Tests if an IP address is already in use.
.DESCRIPTION 
	Used to determine if an IP address is already in use by another system.  If it is, the function returns $true.  If the IP is not in use it will return $false 
.EXAMPLE 
	Test-IpAddressInUse -IpAddress 172.19.30.42
	returns true if its in use, false if its not.
.PARAMETER IpAddress
	Address to check.
.OUTPUTS 
	Bool
#>
	[cmdletbinding()]
	Param
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='what IP address do you need to check ?')]
        [String] $IpAddress
	)
	try
	{
		[bool]$TestResults = Test-Connection -Count 1 -Quiet -ComputerName $IpAddress
		return $TestResults
	}
	catch
	{
		$Exception = $_.Exception.Message
		Write-Log -Level INFO -Message "Failed to test IP Address: $IpAddress. Exception: $Exception"
	}
}

function Set-FileShareWitness
{
<# 
.SYNOPSIS 
	Adds a fileshare witness to a cluster
.DESCRIPTION 
	Disables current quorum and switches cluster quorum to a Node and FileShare Majority quorum.
.EXAMPLE 
	Set-FileShareWitness -FileShareWitness "\\Path\To\Share" -ClusterName "MyCluster"
.EXAMPLE 
	Set-FileShareWitness -FileShareWitness "\\Path\To\Share" -ClusterObj $MyClusterObj
.PARAMETER ClusterObj
	Microsoft Failover Clusters Powershell Cluster object representing the cluster to be updated
.PARAMETER ClusterName
	Name of the cluster to be updated
.PARAMETER FileShareWitnessPath
	Path to the file share that will act as the quorum.
.OUTPUTS 
	N/A
#>
	[cmdletbinding()]
	Param
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the cluster name?',ParameterSetName="ClusterObject")]
        [Microsoft.FailoverClusters.PowerShell.Cluster] $ClusterObj,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the cluster name?',ParameterSetName="ClusterName")]
        [String] $ClusterName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='what is the cluster resource?')]
        [String] $FileShareWitnessPath
	)
    If($ClusterName -ne $null)
    {
		Write-Log -Level INFO -Message "Enabling FileShareWitness: $FilesShareWitnessPath on cluster: $ClusterName"
        $ClusterObj = (Get-Cluster -Name $ClusterName)
    }
	Else
	{
		Write-Log -Level INFO -Message "Enabling FileShareWitness: $FilesShareWitnessPath on cluster: $($ClusterObj.Name)"
	}
	Try
	{
		#clean up any existing quorum settings
		Set-ClusterQuorum -Cluster $ClusterObj -NoWitness
		#Set Quorum to our file share
		Set-ClusterQuorum -Cluster $ClusterObj -FileShareWitness $FileShareWitnessPath
	}
	Catch
	{
		$ExceptionMessage = $_.Exception.Message
		Write-Log -Level ERROR -Message "Unable to update $FilesShareWitnessPath on $($clusterObj.Name)"
	}
	Write-Log -Level INFO -Message "FileShareWitness set: $FilesShareWitnessPath on Cluster: $($clusterObj.Name)"
}

function Set-ClusterPermissions
{
<# 
.SYNOPSIS 
	Manage permissions on the cluster
.DESCRIPTION 
	Grant or Revoke cluster level permissions to a group or login.  
.EXAMPLE 
	Set-ClusterPermissions -Identity "AAWH\DBAdmins" -Grant -PermissionType FULL -ClusterName "MyCluster"
	Grants full access to DBAdmins group on MyCluster
.EXAMPLE 
	Set-ClusterPermissions -Identity "AAWH\DBAdmins" -Grant -PermissionType FULL -ClusterObj $ClusterObj
	Grants full access to DBAdmins group on the ClusterObject (object type Cluster).
.EXAMPLE 
	Set-ClusterPermissions -Identity "AAWH\DBadmins" -ClusterName "MyCluster"
	Revokes all cluster access for DBadmins group on MyCluster
.PARAMETER ClusterObj
	Microsoft Failover Clusters Powershell Cluster object representing the cluster to be updated
.PARAMETER ClusterName
	Name of the cluster to be updated
.PARAMETER Grant
	Switch, if present, permissions will be granted to the Identity.  If not present permissions will be revoked.
.PARAMETER PermissionType
	Permissions to grant to the Identity.  Options are Full or ReadOnly.
.OUTPUTS 
	N/A
#>
	[cmdletbinding()]
	param
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="What is the Login/group name to grant access to?")]
		[String] $Identity,
		[Parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="are you Granting or Removing permissions? Default is Grant")]
		[switch] $Grant,
	    [Parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="are you setting FULL or READONLY access?")]
		[ValidateSet("ReadOnly","Full")]
		[String] $PermissionType,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the cluster name?',ParameterSetName="ClusterName")]
        [String] $ClusterName,
		[Parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the cluster name?',ParameterSetName="ClusterObject")]
        [Microsoft.FailoverClusters.PowerShell.Cluster] $ClusterObj
	)
	Write-Log -Level INFO "Granting:$Grant Cluster access $PermissionType on cluster $ClusterName to $identity."
	try
	{
		If($grant)
        {
				switch($PermissionType)
				{
					"ReadOnly" {Grant-ClusterAccess -User $Identity -Cluster $ClusterName -ReadOnly -ErrorAction STOP}
					"Full" {Grant-ClusterAccess -User $Identity -Cluster $ClusterName -Full -ErrorAction STOP}
				}
		}
		Else
        {
		    Remove-ClusterAccess -User $Identity -Cluster $ClusterName -ErrorAction STOP
		}
	}
	Catch
	{
		$_.Exception.Message
        $_.exception
		Write-Log -Level ERROR -Message "Failed to update cluster access on Cluster: $ClusterName for Login: $Identity. Grant:$Grant. Exception:$Exception"
	}
	Write-Log -Level INFO -Message "Succesful Grant:$Grant of cluster Access on Cluster $ClusterName to $Identity"
}
Function Set-HostRecordTTL
{
<# 
.SYNOPSIS 
	Change the time to live of a Host Record associated with the cluster.
.DESCRIPTION 
	Change the time to live of a Host Record in seconds. The Host record has to be a parameter of a resource of a cluster.
.EXAMPLE 
	Set-HostRecordTTL -ClusterObj $ClusterObj -HostRecordName "MyClusterName" -SecondsToExpire 60
	Changes the time to live on Host Record MyClusterName for cluster MyFavoriteCluster to 60 seconds.
.PARAMETER ClusterObj
	Microsoft Failover Clusters Powershell Cluster object representing the cluster to be updated
.PARAMETER HostRecordName
	ARecord to be udpated.
.PARAMETER SecondsToLive
	Number Of seconds to the host record should live.
.OUTPUTS 
	N/A
#>
	[cmdletbinding()]
	Param
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the cluster name?')]
        [Microsoft.FailoverClusters.PowerShell.Cluster] $ClusterObj,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='what is the cluster resource?')]
        [String] $HostRecordName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='How Many seconds until the record expires')]
		[int] $SecondsToLive
	)
	Try
	{
		$resource = $ClusterObj | Get-ClusterResource | WHERE {$_.ResourceType -eq "Network Name" -and ($(Get-ClusterParameter -InputObject $_).Value -contains $HostRecordName)} 
		$resource | Set-ClusterParameter "HostRecordTTL" $SecondsToLive
		$ParamResults = $resource | Get-ClusterParameter | WHERE {$_.Name -eq "HostRecordTTL"}
		Write-Log -Level INFO -Message "Restarting Cluster Resource ($resource.Name) on Cluster ($ClusterObj.Name) to update HostRecord $HostRecordName TTL to $SecondsToLive."
		Stop-ClusterResource $resource | Out-Null
		Start-ClusterResource $resource | Out-Null
		Start-SleeperBar -Seconds 5 -ProgressBarTitle "Waiting for cluster Resource to restart." 
		$RestartResults = $ClusterObj | Get-ClusterResource -Name ($resource.name) 
		If($RestartResults.State -ne "Online")
		{
			Write-Log -Level ERROR -Message "There was a problem Restarting the resource ($Resource.Name) on cluster ($ClusterObj.Name)"
		}
		Else
		{
			Write-Log -Level INFO -Message "HostRecord $HostRecordName TimeToLive updated to $SecondsToLive seconds on cluster ($ClusterObj.Name) successful."
		}
	}
	catch
	{
		$Exception = $_.Exception.Message 
		Write-Log -Level ERROR -Message "There was a problem updating the HostRecord $HostRecordName Time to live on Cluster ($ClusterObj.Name)"
	}
}

function Set-ClusterNameIPDependency
{
	<# 
.SYNOPSIS 
	Set Dependency on both cluster name IPs for a cluster name.
.DESCRIPTION 
	Set Dependency on both cluster name IPs for a cluster name. Sets the dependency with the OR condition
.EXAMPLE 
	Set-ClusterNameIPDependency -ClusterName "MyCluster" -ClusterNameIPResourceName1 "CLuster IP PD" -ClusterNameIPResourceName2 "Cluster IP DR"
.PARAMETER ClusterObj
	Microsoft Failover Clusters Powershell Cluster object representing the cluster to be updated
.PARAMETER HostRecordName
	ARecord to be udpated.
.PARAMETER SecondsToLive
	Number Of seconds to the host record should live.
.OUTPUTS 
	N/A
#>
	[cmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='What is the cluster name?')]
        [string] $ClusterName,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='what is first the cluster resource name?')]
        [String] $ClusterNameIPResourceName1,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage='what is second the cluster resource name?')]
        [String] $ClusterNameIPResourceName2
	)
	#get dependencies for Cluster Name
	$DependencyExpression = (Get-ClusterResourceDependency -Resource @("Cluster Name") -Cluster $ClusterName -ErrorAction STOP).DependencyExpression
	#make sure we have both ip resources, and they are named correctly.
	$Resources = Get-ClusterResource -Cluster $ClusterName -name @($ClusterNameIPResourceName1,$ClusterNameIPResourceName2) -ErrorAction STOP
	if($Resources.count -ne 2)
	{
		Write-Log -Level ERROR -Message "Ip Resources may be missing or named incorrectly on Cluster $ClusterName. Halting configuration."
	}
	If($DependencyExpression -notlike "([$ClusterNameIPResourceName1] OR [$ClusterNameIPResourceName2])")
	{
		Write-Log -Level INFO -Message "Setting cluster name resource dependencies for Cluster $ClusterName"
		try
		{
			Set-ClusterResourceDependency -Resource "Cluster Name" -Cluster $ClusterName -Dependency "[$ClusterNameIPResourceName1] or [$ClusterNameIPResourceName2]" -ErrorAction STOP
		}
		catch
		{
			$ExceptionMessage = $_.Exception.Message
			Write-Log -Level ERROR -Message "Issue Setting Cluster Name Resource Dependencies on cluster $ClusterName."
		}
		Write-Log -Level INFO -Message "Cluster Name Resource Dependencies updated on cluster $ClusterName to [$ClusterNameIPResourceName1] or [$ClusterNameIPResourceName2]"
	}
}