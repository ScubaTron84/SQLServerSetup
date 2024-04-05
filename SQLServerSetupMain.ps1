$ErrorActionPreference::Stop

##Import our config file data
Function ImportConfigData
{
    try
    {
		$Global:RunForceFormatDrives = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE{$_.Entity -eq "RUN" -and $_.Key -eq "ForceFormatDrives"} | Select-Object -Property Value).Value
		$Global:RunDriveConfig = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE{$_.Entity -eq "RUN" -and $_.Key -eq "DriveConfig"} | Select-Object -Property Value).Value
		$Global:RunSetOsSettings = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE{$_.Entity -eq "RUN" -and $_.Key -eq "SetOsSettings"} | Select-Object -Property Value).Value
		$Global:RunInstallOSFeatures = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE{$_.Entity -eq "RUN" -and $_.Key -eq "InstallOsFeatures"} | Select-Object -Property Value).Value
		$Global:RunInitCluster = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE{$_.Entity -eq "RUN" -and $_.Key -eq "InitializeCluster"} | Select-Object -Property Value).Value
		$Global:RunCopySQLInstall = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE{$_.Entity -eq "RUN" -and $_.Key -eq "CopySQLInstallFiles"} | Select-Object -Property Value).Value
		$Global:RunInstallSQLRemotely = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE{$_.Entity -eq "RUN" -and $_.Key -eq "InstallSQLServerRemotely"} | Select-Object -Property Value).Value
		$Global:RunNewSQLServerConfig = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE{$_.Entity -eq "RUN" -and $_.Key -eq "NewSQLServerConfiguration"} | Select-Object -Property Value).Value
        $Global:OSSourcePath = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE{$_.Entity -eq "OSFiles" -and $_.Key -eq "OSISOSource"} | Select-Object -Property Value).Value
        $Global:OSDestinationPath = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE{$_.Entity -eq "OSFiles" -and $_.Key -eq "OSISODestinationFolder"} | Select-Object -Property Value).Value
        $Global:SQLDiskConfigurationData = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE{$_.Entity -like "DISK*"})
        $Global:SQLServerConfig = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE {$_.Entity -eq "SQLCONFIG"})
        $Global:SQLVersion = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE {$_.Entity -eq "SQLCONFIG" -and $_.Key -eq "Version"} |Select-object -Property Value).Value
		$Global:Engine = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE {$_.Entity -eq "SQLCONFIG" -and $_.Key -eq "Engine"} |Select-object -Property Value).Value
        $Global:WindowsFeatures = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE {$_.Entity -eq "OSFEATURES" -and $_.Key -eq "FeatureName"} | Select-object -Property Value).Value
		$Global:ClusterName = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE {$_.Entity -eq "CLUSTERRESOURCE" -and $_.Key -eq "ClusterName"} | Select-object -Property Value).Value
		$Global:OUPath = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE {$_.Entity -eq "CLUSTERConfig" -and $_.Key -eq "OU"} | Select-object -Property Value).Value
		$Global:ClusterIpAddressPD = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE {$_.Entity -eq "CLUSTERRESOURCE" -and $_.Key -eq "ClusterIPPD"} | Select-object -Property Value).Value
		$Global:ClusterIpAddressDR = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE {$_.Entity -eq "CLUSTERRESOURCE" -and $_.Key -eq "ClusterIPDR"} | Select-object -Property Value).Value
		$Global:SQLServiceLogin = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE {$_.Entity -eq "SQLCONFIG" -and $_.Key -eq "ServiceAccount"} | Select-object -Property Value).Value
		$Global:LocalUserAccess = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE {$_.Entity -eq "LOCALUSERACCESS"} |Select-object -Property Key,Value )
		$Global:SQLSecPolicies = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE {$_.Entity -eq "SECURITYPOLICY" -and $_.Key -eq "SQLServer"} | Select-object -Property Value).Value
		$Global:FileShareWitnessPath = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE {$_.Entity -eq "CLUSTERRESOURCE" -and $_.Key -eq "FileShareWitnessPath"} |Select-Object -Property Value).Value
		$Global:SQLTraceFlags = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE {$_.Entity -eq "SQLCONFIG" -and $_.Key -eq "Traceflags"} |Select-Object -Property Value).Value
		$Global:SQLfiles = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE {$_.Entity -eq "SQLFILES" -and $_.Key -eq $Global:SQLVersion} |Select-Object -Property Value).Value
		$Global:SQLpatches = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE {$_.Entity -eq "SQLPATCHES" -and $_.Key -eq $Global:SQLVersion} |Select-Object -Property Value).Value
		$Global:DataCenter = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE {$_.Entity -eq "DATACENTER" -and $_.Key -eq "Location"} |Select-Object -Property Value).Value
		$Global:SetDTCConfiguration = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE {$_.Entity -eq "OSCONFIG" -and $_.Key -eq "MSDTC"} |Select-Object -Property Value).Value
		$Global:ListenerGroup = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE {$_.Entity -eq "SQLCONFIG" -and $_.Key -eq "ListenerGroup"} |Select-Object -Property Value).Value
		#Separate Drive Letters
        $DiskEnt = ($Global:SQLDiskConfigurationData | WHERE {$_.value -eq "SystemDB" -and $_.Key -eq "Type"} | Select-Object -Property Entity).Entity
		$Global:SQLSystemDisk =  ($Global:SQLDiskConfigurationData | WHERE {$_.Entity -eq $DiskEnt -and $_.Key -eq "DiskLetter"} | Select-Object -Property "Value").Value
        $DiskEnt = ($Global:SQLDiskConfigurationData | WHERE {$_.value -eq "DATA" -and $_.Key -eq "Type"} | Select-Object -Property Entity -First 1).Entity
		$Global:UserDataDisk =  ($Global:SQLDiskConfigurationData | WHERE {$_.Entity -eq $DiskEnt -and $_.Key -eq "DiskLetter"} | Select-Object -Property "Value").Value
        $DiskEnt = ($Global:SQLDiskConfigurationData | WHERE {$_.value -eq "LOG" -and $_.Key -eq "Type"} | Select-Object -Property "Entity" -First 1).Entity
		$Global:UserLogDisk =   ($Global:SQLDiskConfigurationData | WHERE {$_.Entity -eq $DiskEnt -and $_.Key -eq "DiskLetter"} | Select-Object -Property "Value").Value
        $DiskEnt = ($Global:SQLDiskConfigurationData | WHERE {$_.value -eq "TEMPDB" -and $_.Key -eq "Type"} | Select-Object -Property "Entity" -First 1).Entity
		$Global:TempDBDisk  =   ($Global:SQLDiskConfigurationData | WHERE {$_.Entity -eq $DiskEnt -and $_.Key -eq "DiskLetter"} | Select-Object -Property "Value").Value
        $DiskEnt = ($Global:SQLDiskConfigurationData | WHERE {$_.value -eq "BACKUP" -and $_.Key -eq "Type"} | Select-Object -Property "Entity").Entity
		$Global:SQLBackupDisk  = ($Global:SQLDiskConfigurationData | WHERE {$_.Entity -eq $DiskEnt -and $_.Key -eq "DiskLetter"} | Select-Object -Property "Value").Value 

		#Get File Paths for install
		$Global:SQLSystemPath =  ($Global:SQLDiskConfigurationData | WHERE {$_.Entity -eq (($Global:SQLDiskConfigurationData | WHERE {$_.value -eq "SystemDB" -and $_.Key -eq "Type"} | Select-Object -Property "Entity" -First 1).Entity) -and $_.Key -eq "Path"} | Select-Object -Property "Value").Value
		$Global:UserDataPath =  ($Global:SQLDiskConfigurationData | WHERE {$_.Entity -eq (($Global:SQLDiskConfigurationData | WHERE {$_.value -eq "DATA" -and $_.Key -eq "Type"} | Select-Object -Property "Entity" -First 1).Entity) -and $_.Key -eq "Path"} | Select-Object -Property "Value").Value 
		$Global:UserLogPath =  ($Global:SQLDiskConfigurationData | WHERE {$_.Entity -eq (($Global:SQLDiskConfigurationData | WHERE {$_.value -eq "LOG" -and $_.Key -eq "Type"} | Select-Object -Property "Entity" -First 1).Entity) -and $_.Key -eq "Path"} | Select-Object -Property "Value").Value
		$Global:TempDBPath  = ($Global:SQLDiskConfigurationData | WHERE {$_.Entity -eq (($Global:SQLDiskConfigurationData | WHERE {$_.value -eq "TEMPDB" -and $_.Key -eq "Type"} | Select-Object -Property "Entity" -First 1).Entity) -and $_.Key -eq "Path"} | Select-Object -Property "Value").Value 
		$Global:SQLBackupPath  = ($Global:SQLDiskConfigurationData | WHERE {$_.Entity -eq (($Global:SQLDiskConfigurationData | WHERE {$_.value -eq "BACKUP" -and $_.Key -eq "Type"} | Select-Object -Property "Entity" -First 1).Entity) -and $_.Key -eq "Path"} | Select-Object -Property "Value").Value
    }
    catch
    {
        Write-Log -Level ERROR -Message "Unable to find/open Configuration File..."
    }
}

#Disk Setup
##TODO add failed initialized disk detection and call Clear-Disk command.  (disk partition was set to GPT, no letter assigned, and/or not extend over all free space).
function DiskSetup
{
	Write-Log -Level INFO -Message "Starting disk configuration on host: $Global:HostName"

	#update the target hosts disk information, to make sure we have the right sizes
    Write-Log -Level INFO -Message "Scanning disks on $Global:HostName"
    Update-HostStorageCache -CimSession $Global:HostName

		##check is sql already installed? If not FDisk the HECK out of those drives
	if(!(Confirm-IsSQLAlreadyInstalled -HostName $Global:HostName) -and ([System.Convert]::ToBoolean($Global:RunForceFormatDrives)))
	{
		Write-Log -LEVEL WARN -MESSAGE "Force Format drives selected on host: $Global:HostName, Skipping drive re-format"
		[int[]] $diskNumbers = (Get-Disk -CimSession $Global:HostName | WHERE {$_.IsSystem -eq $false} | Select-Object -Property Number).Number
		Foreach($dn in $diskNumbers)
		{
			Clear-Disk -Number $dn -CimSession $Global:HostName -RemoveData -Confirm:$false
		}
	}

    #get a list of all disks on the target host that are RAW unformatted
    $disks = Get-Disk -CimSession $Global:HostName | WHERE { $_.PartitionStyle -eq 'RAW' -and $_.IsSystem -eq $false}
    If($disks -eq $null)
    {
        try
        {
            Write-Log -Level INFO -Message "All disks on $Global:HostName appear to be formatted. Listing current disks"
            $disksFormatted = Get-Disk -CimSession $Global:HostName | WHERE { $_.PartitionStyle -ne 'RAW' -and $_.IsSystem -eq $false}
            Write-Log -Level INFO -Message "Disk Letter `t Disk Size `t Partition Style"
            Write-Log -Level INFO -Message "----------- `t --------- `t ---------------"
            Foreach( $line in $disksFormatted)
            {
                $currentDisk = Get-Partition -CimSession $Global:Hostname -DiskNumber $line.Number | Where {$_.PartitionNumber -eq 2}
                Write-Log -Level INFO -Message "$($currentDisk.DriveLetter) `t`t $([math]::round($currentDisk.Size /1024/1024/1024)) `t `t $($line.PartitionStyle)"
            }
        }
        catch
        {
            Write-Log -Level ERROR -Message "Could not output disk configuration.  Stopping script..."
        }
    }
    Else
    {
        try
        {
            Write-Log -Level INFO -Message "All RAW disks on $Global:HostName that need to be formatted. Listing current disks"
            Write-Log -Level INFO -Message "Disk Number `t Disk Size `t Partition Style"
            Write-Log -Level INFO -Message "----------- `t --------- `t ---------------"
            Foreach( $line in $disks)
            {
                $currentDisk = Get-Disk -CimSession $Global:HostName -Number $line.Number 
                Write-Log -Level INFO -Message "$($currentDisk.Number) `t`t $([math]::round($currentDisk.Size /1024/1024/1024)) `t `t $($line.PartitionStyle)"
            }
        }
        catch
        {
            Write-Log -Level ERROR -Message "Could not output raw disk configuration.  Stopping script..."
        }
    }
    
    ##If this is an interactive install, verify the disk sizes.
    If($Global:InteractionLevel -eq 1)
    {
        #ask for confirmation  
        $TitleDiskConfirm = "Disk Confirm"
        $MessageDiskConfirm ="Do the number or disks found and sizes look correct to you?"
        $YesDiskConfirm = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
        "Formatting of Disks will continue."
        $NoDiskConfirm = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
        "Installation will be stopped."
        $OptionsDiskConfirm = [System.Management.Automation.Host.ChoiceDescription[]]($YesDiskConfirm, $NoDiskConfirm)
        $ResultDiskConfirm = $host.ui.PromptForChoice($TitleDiskConfirm, $MessageDiskConfirm, $OptionsDiskConfirm, 0) 
    
        #check confirmation
        switch($ResultDiskConfirm)
        {
           0{Write-Log -Level INFO -Message "Disks look correct per operator."}
           1{Write-Log -Level ERROR -Message "Disks are incorrect, Aborting"}
        }
    }
    ##Loop through the disks found and format them.
    if($disks -ne $null)
    {
        write-log -Level INFO -Message "Formatting RAW disks on $Global:HostName"
        try
        {
			$DoneDisksTypes = @()
            Foreach($d in $disks)
            {
                $diskSize= $d.Size/1024/1024/1024
                $diskTypes = ($Global:SQLDiskConfigurationData | WHERE {$_.Value -eq $diskSize -and $_.Key -eq "DiskSize"} | Select-Object -Property "entity").Entity
				Foreach ($dT in $diskTypes){
					if($dT -notin $DoneDisksTypes)
					{
						$dConfig = $Global:SQLDiskConfigurationData | WHERE {$_.Entity -eq $dT}
							If($dT -eq $null)
							{
							  Write-Log -Level ERROR -Message "A matching disk type was not found for disk number $($d.Number) with size $diskSize GB on $Global:HostName. Stopping Script."
							}
						$Label = ($dConfig | WHERE{$_.key -eq "DiskLabel"} | Select-object -property value ).Value
						$Letter = ($dConfig | WHERE{$_.key -eq "DiskLetter"} | Select-object -property value ).Value
						Format-SQLDisk -DriveLetter $Letter -DriveLabel $Label -DiskNumber $d.Number -HostName $Global:HostName
						Sleep 3
						$DoneDisksTypes+=$dT
						Break;
					}
				}
            }
		
			#Output disks after formating so we can see what we have.
			Write-Log -Level INFO -Message "All disks on $Global:HostName after formatting operation:"
			$disksFormatted = Get-Disk -CimSession $Global:HostName | WHERE { $_.PartitionStyle -ne 'RAW' -and $_.IsSystem -eq $false}
			Write-Log -Level INFO -Message "Disk Letter `t Disk Size `t Partition Style"
			Write-Log -Level INFO -Message "----------- `t --------- `t ---------------"
			Foreach( $line in $disksFormatted)
			{
				$currentDisk = Get-Partition -DiskNumber $line.Number -CimSession $Global:HostName | Where {$_.PartitionNumber -eq 2}
				Write-Log -Level INFO -Message "$($currentDisk.DriveLetter) `t`t $([math]::round($currentDisk.Size /1024/1024/1024)) `t `t $($line.PartitionStyle)"
			}
        }
        catch
        {
			$Exception = $_.Exception.Message
            Write-Log -Level ERROR -Message "Something went wrong with Disk formatting on $Global:HostName.  Stopping Script. Exception: $Exception"
        }
		#success
        Write-Log -Level INFO -Message " All RAW disks Formatted on $Global:HostName Successfully"
    }
	#TODO,  get all drive letters, check if admin share exists.  
	#Check if Drive Admin Shares exist 
	$AdminShareCheckSQLSystemDisk = "\\$Global:HostName\$Global:SQLSystemDisk$"
	$AdminShareCheckUserDataDisk = "\\$Global:HostName\$Global:UserDataDisk$"
	$AdminShareCheckUserLogDisk = "\\$Global:HostName\$Global:UserLogDisk$"
	$AdminShareCheckTempDBDisk = "\\$Global:HostName\$Global:TempDBDisk$"
	$AdminShareCheckSQLBackupDisk = "\\$Global:HostName\$Global:SQLBackupDisk$"

	Write-Log -Level WARN -Message "Checking if Adminshare paths exists on Host $Global:HostName"
	If(!(Test-Path -Path $AdminShareCheckSQLSystemDisk) -or !(Test-Path -Path $AdminShareCheckUserDataDisk) -or !(Test-Path -Path $AdminShareCheckUserLogDisk) -or !(Test-Path -Path $AdminShareCheckTempDBDisk) -or !(Test-Path -Path $AdminShareCheckSQLBackupDisk))
	{
		Write-Log -Level WARN -Message "Not all Admin share paths not found on Host: $Global:HostName.  Determining next steps..."
		try
		{
			If($Global:HostName -ne $env:COMPUTERNAME)
			{
				Write-Log -Level WARN -Message "Target Server: $Global:HostName is remote.  Restarting server to create admin shares"
				Restart-Computer -ComputerName $Global:HostName -Force -Wait
				Write-Log -Level INFO -Message "Restart of Server: $Global:HostName is complete."
			}
			Else
			{
				Write-Log -Level WARN -Message "Target server is local host.  Restarting Server Service to create admin shares."
				$LocalService = Get-Service -ComputerName $Global:HostName -DisplayName Server
				Restart-Service -InputObject $LocalService
				sleep 10
				Write-Log -Level INFO -Message "Restart of Server Service Complete"
			}
		}
		catch
		{
			$Exception = $_.Exception.Message
            Write-Log -Level ERROR -Message "Something enabling admin shares on host: $Global:HostName.  Stopping Script. Exception: $Exception"
		}
	}
	else
		{
			Write-Log -Level INFO -Message "All AdminShares exists on Host $Global:HostName"
		}
	Write-Log -Level INFO -Message "Creating Default SQL Server Folders on host: $Global:HostName."
	try
	{
		#Creating folder structure for SQL server
		##TODO switch this to use global Variables that already exist.  
		New-SQLFolders -HostName $Global:HostName `
		-systemDBDriveLetter  $Global:SQLSystemDisk `
		-DataDriveLetter $Global:UserDataDisk `
		-LogDriveLetter $Global:UserLogDisk `
		-TempDBDriveLetter $Global:TempDBDisk `
		-DataPath $Global:UserDataPath `
		-SystemPath $Global:SQLSystemPath `
		-LogPath $Global:UserLogPath `
		-TempDBPath $Global:TempDBPath `
		-BackupDriveLetter $Global:SQLBackupDisk `
		-BackupPath $Global:SQLBackupPath
	}
	catch
	{
		$Exception = $_.Exception.Message
		Write-Log -level ERROR -Message "Unable to create sql folders on host: $Global:HostName, Exception $Exception"
	}
	Write-Log -Level INFO -Message "Folders created Successfully on host: $Global:HostName"
	Write-Log -Level INFO -Message "Disk Setup Complete on host: $Global:HostName"
}
function InstallOSFeatures
{
    try
    {
       If($Global:WindowsFeatures.Count -gt 0)
       {
			Write-Log -Level INFO -Message "Beginning Install of necessary Windows Features on Host: $Global:HostName"
            #Check if any necessary features need to be installed.  If so ensure the windows iso is avaiable/mounted.
			##Set iso source Location to $null 
		    ##If all features installed,  do nothing
            ##Else check for OS files in SourceLoc,  if not there copy media iso to host and mount as disk.
			$SourceLoc = $null
		    [bool]$NeedInstall = $false
			$mountResult = $null
            Foreach($feature in $Global:WindowsFeatures)
            {
                $NeedInstall = Get-RequiredWindowsFeature -HostName $Global:HostName -WindowsFeatureName $feature
                if($NeedInstall -and $SourceLoc -eq $Null)
                {
                    Write-Log -level INFO -message "Need to install Feature: $feature"
                    $OsFile = Get-OSMedia -HostName $Global:HostName -WindowsOSMediaPath $Global:OSSourcePath -DestinationPath $Global:OSDestinationPath
					Write-Log -level INFO -Message "Mounting Windows ISO on $Global:HostName from $OsFile."
					If($osFile -ne "D:\Sources\sxs")
					{
						$mountResult = Mount-DiskImage -ImagePath $OsFile -CimSession $Global:HostName -StorageType ISO -PassThru
						$SourceLoc = (($mountResult|Get-Volume).DriveLetter +":\sources\sxs")
						Write-Log -Level INFO -Message "ISO was mount on $Global:HostName to location: $SourceLoc"
					}
					else
					{
						$SourceLoc = $OsFile
					}
					Install-RequiredWindowsFeature -HostName $Global:HostName -WindowsFeatureName $feature -WindowsOSMediaPath $SourceLoc
                }
				elseif($NeedInstall -and $SourceLoc -ne $null)
				{
					Install-RequiredWindowsFeature -HostName $Global:HostName -WindowsFeatureName $feature -WindowsOSMediaPath $SourceLoc
				}
            }
            If($mountResult -ne $null)
            {
                Write-Log -Level INFO -Message "DisMounting Windows iso, path: $OSFile on host: $Global:HostName"
                Dismount-IsoFile -HostName $HostName -IsoName "Windows"
				if($OsFile -ne "D:\Sources\Sxs")
				{
					Write-Log -Level INFO -Message "Cleaning up windows iso file on Host: $hostname, from path: $OsFile"
					Remove-Item $(Join-path -path "\\$Global:HostName\" -childpath $OSFile.Replace("C:","C$"))
				}
            }
        }
        Write-Log -Level INFO -Message "All Required Windows Components installed on $Global:HostName"
    }
    catch
    {
        $ExecptionMessage = $_.Exception.Message
        $ExceptionItem = $_.Excepetion.ItemName
        If($mountResult -ne $null)
        {
            Dismount-IsoFile -HostName $HostName -IsoName "Windows"
        }
        Write-Log -Level ERROR -Message "Windows OS setup Had a problem. Exception: $ExecptionMessage. ExceptionItem: $ExceptionItem"
    }
}

function SetOSSettings
{
	Write-Log -Level INFO -Message "Starting Configuration of OS Setting on Host: $Global:HostName"

	#Confirming correct OU for the SQL server
	Write-Log -Level INFO -Message "Validating $Global:HostName OU Path."
	$DistinguishedHostName = Get-DistinguishedName -ComputerName $Global:HostName
	IF ($DistinguishedHostName -eq "CN=$Global:HostName,OU=SQL,OU=Computer Resources,DC=aawh,DC=******,DC=com")
	{
		Write-Log -Level INFO -Message "OU Path for host: $Global:HostName is correct.  OU Path: $DistinguishedHostName"
	}
	Else
	{
		Write-Log -Level INFO -Message "OU Path for host: $Global:HostName is incorrect.  Moving from OU Path: $DistinguishedHostName to correct OU Path: CN=$Global:HostName,OU=SQL,OU=Computer Resources,DC=aawh,DC=******,DC=com"
		$DestinationOU = "CN=$Global:HostName,OU=SQL,OU=Computer Resources,DC=aawh,DC=******,DC=com"
		try
		{
			Move-ADObject -Identity $DistinguishedHostName -TargetPath $DestinationOU
		}
		catch
		{
			$ExecptionMessage = $_.Exception.Message
			$ExceptionItem = $_.Excepetion.ItemName
			Write-Log -Level WARN -Message "Unable to move OU Paths for $Global:HostName.  You will have to move this manually in AD."
		}
		Write-Log -LEVEL INFO -Message "Successfully moved host: $Global:HostName to OU Path $DestinationOU"
	}
	#Grant OS Security Policy rights to as needed to SQL service account
	If($Global:SQLSecPolicies.Count -ne 0)
	{
		Write-Log -Level INFO -Message "Updating Local Security Policies for SQL Server Service Account on host : $Global:HostName."
		Foreach ($SecPol in $Global:SQLSecPolicies)
		{
			Grant-CarbonSecurityPolicy -Identity $Global:SQLServiceLogin -privilege $SecPol -HostName $Global:HostName  ##Allow SQL to lock pages in memory
		}
		Write-Log -Level INFO -Message "Successfully enabled Security Policies for SQL Service account: $Global:SQLServiceLogin, on Host: $Global:HostName"
	}
	#Grant OS Security Policy rights  as needed to Cluster service account
	If($Global:ClusterSecPolicies.Count -ne 0)
	{
		Write-Log -Level INFO -Message "Updating Local Security Policies for CLustering on host : $Global:HostName."
		Foreach ($SecPol in $Global:ClusterSecPolicies)
		{
			Grant-CarbonSecurityPolicy -Identity $Global:ClusterServiceLogin -privilege $SecPol -HostName $Global:HostName  ##Allow SQL to lock pages in memory
		}
		Write-Log -Level INFO -Message "Successfully enabled Security Policies for SQL Service account: $Global:ClusterServiceLogin, on Host: $Global:HostName"
	}
	#Add local group access for AD groups
	If($Global:LocalUserAccess.Count -ne 0)
	{
		Write-Log -Level INFO -Message "Adding users/Groups to local groups on Host: $Global:HostName"
		Foreach($ident in $Global:LocalUserAccess)
		{
			Add-LocalGroupMember -identity $ident.Value -LocalGroup $ident.key -HostName $Global:HostName
		}
		Write-Log -Level INFO -Message "Successfully added all users/Groups to local groups on Host: $Global:HostName"
	}
	#Setting powerplan to High Performance
	Write-Log -Level INFO -Message "Ensuring Power Plan is set to High Performance on host: $Global:HostName"
	Try
	{
		$PowerPlan = Get-CimInstance -Name root\cimv2\power -Class win32_PowerPlan -Filter "ElementName = 'High performance'" -CimSession $Global:HostName 
		If($PowerPlan.isActive -ne "true")
		{
			Write-Log -LEVEL INFO -Message "Change power plan to High performance...."
			Set-OSPowerPlan -HostName $Global:HostName -PowerPlan "High performance"
		}
		$PowerPlan = Get-CimInstance -Name root\cimv2\power -Class win32_PowerPlan -Filter "ElementName = 'High performance'" -CimSession $Global:HostName 
		If($PowerPlan.isActive -ne "true")
		{
			Write-Log -Level WARN -Message "Power Plan failed to activate on host: $Global:HostName"
		}
		Else
		{
			Write-Log -Level INFO -Message "Power Plan Updated to High Performance on host: $Global:HostName"
		}
	}
	Catch
	{
		$ExecptionMessage = $_.Exception.Message
        $ExceptionItem = $_.Excepetion.ItemName
		Write-Log -Level WARN -Message "Problem setting power plan to high performance on host:$Global:HostName. Exception: $ExecptionMessage. ExceptionItem: $ExceptionItem"	
	}
	#enable RDP access to the server
	Write-Log -Level INFO -Message "Enabling RDP on host: $Global:HostName"
	try
	{
		Enable-RDPAccess -HostName $Global:HostName
		Write-Log -Level INFO -Message "Successfully Enabled RDP on host: $Global:HostName"
	}
	catch
	{
		$ExecptionMessage = $_.Exception.Message
        $ExceptionItem = $_.Excepetion.ItemName
		Write-Log -Level WARN -Message "Failed to enable RDP access.  Please set manually!!! Exception: $ExecptionMessage. ExceptionItem: $ExceptionItem"
	}
	#Configuring DTC settings
	If ($Global:SetDTCConfiguration -eq "Enable")
	{
		Write-Log -Level WARN -Message "Enabling DTC on host: $Global:HostName, will cause DTC service to restart!!!"
		try
		{
			$DtcService = Get-WmiObject Win32_service  -Filter "Name='MSDTC'"
			$Password = (Convert-SecureStringToPlainText -SecureString $Global:SQLServiceLoginPassword)
			$StopStatus = $DtcService.StopService()
			if($StopStatus.ReturnValue -eq 0)
			{
				Write-Log -Level INFO -Message "Stopped MSDTC Service on host: $Global:HostName"
			
				$ChangeStatus = $DtcService.Change($null,$null,$null,$null,$null,$null,$Global:SQLServiceLogin,$Password,$null,$null,$null)
				Remove-Variable Password
				if($ChangeStatus.ReturnValue -eq 0)
				{
					Write-Log -Level INFO -Message "Updated MSDTC service to run as login: $Global:SQLServiceLogin on host: $Global:HostName"
					Write-Log -Level INFO -Message "Changing settings for MSDTC on host: $Global:HostName"
					Set-DefaultDTCConfiguration -HostName $Global:HostName
					Write-Log -Level INFO -Message "Starting MSDTC Service on host: $Global:HostName"
					$StartStatus = $DtcService.StartService()
					if($StartStatus.ReturnValue -ne 0)
					{
						Write-Log -Level WARN -Message "Unable to start MSDTC service after login change on host: $Global:HostName"
					}
				}
				Else
				{
					Write-Log -Level WARN -Message "Unable to change login for MSDTC service to: $Global:SQLServiceLogin on host: $Global:HostName"
				}
			}
			Write-Log -Level INFO -Message "Successfully Enabled DTC on host: $Global:HostName"
		}
		catch
		{
			$ExecptionMessage = $_.Exception.Message
			$ExceptionItem = $_.Excepetion.ItemName
			Write-Log -Level WARN -Message "Failed to enable DTC access.  Please set manually!!! Exception: $ExecptionMessage. ExceptionItem: $ExceptionItem"
		}
	}
	Write-Log -Level INFO -Message "Successfully Configured OS Setting on Host: $Global:HostName"
}
function CleanupPostInstall
{
		Write-Log -Level INFO -Message "Cleaning up install media and windows media on host: $Hostname"
		#Ensure the windows and SQL iso files are dismounted
		Dismount-IsoFile -HostName $Global:HostName -IsoName "SQL"
		Dismount-IsoFile -HostName $Global:HostName -IsoName "Windows"

		#Check for and cleanup the windows iso.
		if(Test-path "\\$Global:Hostname\C$\windows.iso")
		{
			Remove-Item -Path "\\$Global:Hostname\C$\windows.iso"
		}
		#check for and cleanup the SQLInstall path
		if(Test-Path "\\$Global:HostName\S$\SQLInstall")
		{
			Remove-Item -Path "\\$Global:HostName\S$\SQLInstall" -Recurse
		}
		Write-Log -Level INFO -Message "Finished cleanup on host: $Hostname"
}

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
Import-Module .\DBAOSConfiguration -Force
Import-Module .\DBAClusterInstall -Force
Import-Module .\DBASQLServerInstall -Force
Import-Module .\DBASQLServerConfiguration -Force
#Import Microsoft Modules
Import-Module BitsTransfer -Force |out-null #Microsoft Windows Module, not loaded by default
Import-Module ActiveDirectory -Force | Out-Null #Active directory module, used to move the computer from one ou to another.


#Declare Globals for later use use
$Global:RunDriveConfig = $false
$Global:RunSetOsSettings = $false
$Global:RunInstallOSFeatures = $false
$Global:RunInitCluster = $false
$Global:RunCopySQLInstall = $false
$Global:RunInstallSQLRemotely = $false
$Global:RunNewSQLServerConfig = $false
$Global:InteractionLevel = $null
$Global:OSSourcePath = $null
$Global:OSDestinationPath = $null
$Global:HostName = $null
$Global:SQLVersion = $null
$Global:Engine = $null
$Global:SQLDiskConfigurationData = $null
$Global:SQLServerConfig = $null
$Global:ConfigurationAndInstallFile = $null
$Global:WindowsFeatures = @()
$Global:ClusterName = $null
$Global:OUPath = @()
$Global:ClusterIpAddressPD = $null
$Global:ClusterIpAddressDR = $null
$Global:SQLServiceLogin = $null
$Global:SQLServiceLoginPassword = $null
$Global:LocalUserAccess = @()
$Global:SQLSecPolicies = @()
$Global:FileShareWitnessPath = $null
$Global:SQLSystemDisk = $null
$Global:UserDataDisk = $null
$Global:UserLogDisk = $null
$Global:TempDBDisk = $null
$Global:SQLBackupDisk = $null
$Global:SQLSystemPath = $null
$Global:UserDataPath = $null
$Global:UserLogPath = $null
$Global:TempDBPath = $null
$Global:SQLBackupPath = $null
$Global:SQLTraceFlags = @()
$Global:SQLfiles = $null
$Global:SQLpatches = $null
$Global:DataCenter = $null
$Global:SetDTCConfiguration = $null
$Global:ListenerGroup = $null
$Global:RunForceFormatDrives = $null

#Interactive install prompt, see if the user wants to run an unattended install or not.
$TitleInteractiveMode ="Interactive Mode"
$MessageInteractiveMode = "Do you want to run the script in Interactive mode or Unattended? Unattended will continue without verification."
$Unattended = New-Object System.Management.Automation.Host.ChoiceDescription "&Unattended", `
    "Install will run in AutoPilot mode after you supply the password for SQL Server's Service account"
$Interactive = New-Object System.Management.Automation.Host.ChoiceDescription "&Interactive", `
    "User will be prompted for input and confirmation throughout the install."
$OptionsInteractiveMode = [System.Management.Automation.Host.ChoiceDescription[]]($Unattended, $Interactive)
$Global:InteractionLevel = $host.ui.PromptForChoice($titleInteractiveMode, $messageInteractiveMode, $OptionsInteractiveMode, 0) 

#Password Prompt: Collect the necessary passwords as a secure string. 
$Global:SQLServiceLoginPassword = Read-Host -Prompt "Please supply the password for the SQL Server Service account" -AsSecureString

#Based on user selection, tell the user what iwll happen next.
switch ($Global:InteractionLevel)
    {
        0 {Write-Log -Level INFO -Message "You selected Unattended."}
        1 {Write-Log -Level INFO -Message "You selected Interactive."}
    }
##Interactive Install selected.  Prompt for the ServerName and config file location.  
### TODO: Needs to include prompts between steps of code.  Prompt for everything. 
If($Global:InteractionLevel -eq 1){
    $Global:HostName = read-host -Prompt "Server Name:" 
    Write-Log -Level INFO -Message "Server Selected: $Global:HostName"
    $Global:ConfigurationAndInstallFile = Read-Host -Prompt "Where is the config file?"  
	$host.UI.RawUI.WindowTitle = "SQL Server Install: $Global:HostName"
    Write-Log -Level INFO -Message "Configuration File Location: $Global:ConfigurationAndInstallFile"
}
else
{
    $Global:ConfigurationAndInstallFile = ".\SQLConfig.csv"
    Write-Log -Level INFO -Message "DEFAULT Configuration File Location selected: $Global:ConfigurationAndInstallFile"
    $Global:HostName = (Import-InstallConfiguration $Global:ConfigurationAndInstallFile | WHERE{$_.Entity -eq "HOST" -and $_.Key -eq "HostName"} | Select-Object -Property Value).Value
	$host.UI.RawUI.WindowTitle = "SQL Server Install: $Global:HostName"
    Write-Log -Level INFO -Message "Server Selected: $Global:HostName"
}
	#append host name to log file for easier identification.
	$LogFileWithServerName = $Global:HostName+"_LogFile_$LogStamp.txt"
	Rename-Item "$Global:LogFile" "$LogFileWithServerName"
	$Global:LogFile = ".\$LogFileWithServerName"

#Import our install configuration data
	ImportConfigData
##Format Disks to SQL server needs
	If([System.Convert]::ToBoolean($Global:RunDriveConfig)){DiskSetup} else {write-Log -Level INFO -Message "Drive Configuration step disabled, skipping for host: $Global:hostName"}
#Manipulate OS settings for SQL server
	If([System.Convert]::ToBoolean($Global:RunSetOsSettings)){SetOSSettings} else {write-Log -Level INFO -Message "Set OS Settings step disabled, skipping for host: $Global:hostName"}
#Install Required OS features for SQL server install
	if([System.Convert]::ToBoolean($Global:RunInstallOSFeatures)){InstallOSFeatures} else {write-Log -Level INFO -Message "OS feature install step disabled, skipping for host: $Global:hostName"}
#Attempt to create cluster or add node to existing cluster
	If([System.Convert]::ToBoolean($Global:RunInitCluster))
	{
		switch ($Global:DataCenter)
		{
			"Primary"  {Initialize-NewCluster -HostName $Global:HostName -ClusterName $Global:ClusterName -SQLOU $Global:OUPath -ClusterIPAddress $Global:ClusterIpAddressPD -FileShareWitnessPath $Global:FileShareWitnessPath -DataCenter $Global:DataCenter -ListenerGroup $Global:ListenerGroup}
			"Secondary"{Initialize-NewCluster -HostName $Global:HostName -ClusterName $Global:ClusterName -SQLOU $Global:OUPath -ClusterIPAddress $Global:ClusterIpAddressDR -FileShareWitnessPath $Global:FileShareWitnessPath -DataCenter $Global:DataCenter -ListenerGroup $Global:ListenerGroup}
			"HDQ"      {Initialize-NewCluster -HostName $Global:HostName -ClusterName $Global:ClusterName -SQLOU $Global:OUPath -ClusterIPAddress $Global:ClusterIpAddressPD -FileShareWitnessPath $Global:FileShareWitnessPath -DataCenter $Global:DataCenter -ListenerGroup $Global:ListenerGroup}
			default    {Initialize-NewCluster -HostName $Global:HostName -ClusterName $Global:ClusterName -SQLOU $Global:OUPath -ClusterIPAddress $Global:ClusterIpAddressPD -FileShareWitnessPath $Global:FileShareWitnessPath -DataCenter $Global:DataCenter -ListenerGroup $Global:ListenerGroup}
		}
	} else {write-Log -Level INFO -Message "Cluster Initialization step disabled, skipping for host: $Global:hostName"}
#Copy SQL server install files to local host target
	If([System.Convert]::ToBoolean($Global:RunCopySQLInstall))
	{
		Copy-SQLInstallFiles -HostName $Global:HostName -SQLVersion $Global:SQLVersion -Engine $Global:Engine -LocalDriveLetter $SQLSystemDisk `
			-SQLfiles $Global:SQLfiles -SQLPatches $Global:SQLpatches
	}
	else {write-Log -Level INFO -Message "Copy SQL install files step disabled, skipping for host: $Global:hostName"}
#Install SQL Server Remotely
	If([System.Convert]::ToBoolean($Global:RunInstallSQLRemotely))
	{
		Install-SQLServerRemotely -HostName $Global:HostName -SQLServiceAccount $Global:SQLServiceLogin -Password $Global:SQLServiceLoginPassword `
			-InstanceDirectory "$($Global:SQLSystemDisk):$($Global:SQLSystemPath)" -SQLBackupDirectory "$($Global:SQLBackupDisk):$($Global:SQLBackupPath)"`
			-SQLUserDBDirectory	"$($Global:UserDataDisk):$($Global:UserDataPath)" -SQLUserLogDirectory "$($Global:UserLogDisk):$($Global:UserLogPath)"`
			-SQLTempDBDirectory	"$($Global:TempDBDisk):$($Global:TempDBPath)"` -SQLSysAdminAccounts "AAWH\DBAdmins" -SQLVersion $Global:SQLVersion
	} else {write-Log -Level INFO -Message "Install SQL Remotely step disabled, skipping for host: $Global:hostName"}
#Configure SQL server on new target
	If([System.Convert]::ToBoolean($Global:RunNewSQLServerConfig)) {New-SQLServerConfiguration -InstanceName $Global:HostName -TraceFlagDefaults $Global:SQLTraceFlags} else {write-Log -Level INFO -Message "New SQL server Configuration step disabled, skipping for host: $Global:hostName"}
##Post install cleanup
	CleanupPostInstall
Write-Log -Level INFO -Message "Setup of SQL Server Complete for $Global:HostName"
