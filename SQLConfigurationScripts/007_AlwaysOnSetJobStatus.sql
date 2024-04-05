USE [msdb]
GO

/****** Object:  Job [AlwaysOnSetJobStatus]    Script Date: 12/5/2016 1:36:54 PM ******/
IF EXISTS (SELECT name from msdb.dbo.sysjobs where name = N'AlwaysOnSetJobStatus')
GOTO EndSave
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

/****** Object:  JobCategory [Database Maintenance]    Script Date: 12/5/2016 1:36:55 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'AlwaysOnSetJobStatus', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'DBAdmins', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [UpdateJobStatus]    Script Date: 12/5/2016 1:36:55 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'UpdateJobStatus', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--DOES NOT CURRENTLY HANDLE databases not in an ag group.
--Declare Variables
DECLARE @Jobname VARCHAR(max) = NULL
--Check if there are any databases currently acting as primary.
IF (
		(
		SELECT COUNT(adc.database_name)
		FROM sys.dm_hadr_availability_replica_states AS ars 
			INNER JOIN sys.dm_hadr_database_replica_states AS hdrs ON ars.group_id = hdrs.group_id
			INNER JOIN sys.availability_databases_cluster adc ON adc.group_database_id = hdrs.group_database_id
		WHERE (ars.is_local = 1) AND (ars.role_desc = ''PRIMARY'')
		) > 0
		OR
		(
			SELECT COUNT(name)
			FROM sys.databases 
			WHERE state = 0 
			AND database_id NOT IN (1,2,3,4) 
			AND name <> ''DBAdmin''
			AND database_id NOT IN 
			(
				SELECT database_id FROM sys.dm_hadr_database_replica_states 
			)

		) > 0
	)
BEGIN
	--If database is primary, get a list of disabled jobs that need to be turned on.
	SELECT name INTO #JobsCheckEnable FROM msdb.dbo.sysjobs WHERE Name NOT IN 
		(--SELECT Name FROM DBADmin.dbo.ExclusionsList WHERE ExclusionType = ''Job''
			''Polar_Metrix_DataLoad'',
			''Alert - Data drive Disk Space'',
			''DBAdmin-dbasysprocesses_stop'',
			''syspolicy_purge_history'',
			''DBAdmin-Maint-sp_purge_jobhistory'',
			''DBAdmin-Maint-sp_delete_backuphistory'',
			''DBAdmin-Maint-DatabaseBackup - CommandLog Cleanup'',
			''AlwaysOnSetJobStatus''
		)
		AND [enabled] = 0
	    
		--loop through the disabled jobs, and enable them.    
	    DECLARE JobCursor CURSOR READ_ONLY FOR 
		SELECT Name FROM #JobsCheckEnable  
	    OPEN JobCursor
	    FETCH NEXT FROM JobCursor INTO @Jobname
	    WHILE @@FETCH_STATUS = 0
	    BEGIN
	        EXEC msdb.dbo.sp_update_job @Job_Name = @Jobname, @enabled = 1
	        FETCH NEXT FROM JobCursor INTO @Jobname
	    END
	    CLOSE JobCursor
	    DEALLOCATE JobCursor
END
ELSE 
BEGIN
	--If no databases are primary in ag groups, get a list of disabled jobs that need to be turned on
	SELECT name INTO #JobsCheckDisable FROM msdb.dbo.sysjobs WHERE Name NOT IN 
		(--SELECT Name FROM DBADmin.dbo.ExclusionsList WHERE ExclusionType = ''Job''
			''Polar_Metrix_DataLoad'',
			''Alert - Data drive Disk Space'',
			''DBAdmin-dbasysprocesses_stop'',
			''syspolicy_purge_history'',
			''DBAdmin-Maint-sp_purge_jobhistory'',
			''DBAdmin-Maint-sp_delete_backuphistory'',
			''DBAdmin-Maint-DatabaseBackup - CommandLog Cleanup'',
			''AlwaysOnSetJobStatus''
		)
		AND [enabled] = 1
	    
		--loop through the disabled jobs, and enable them.    
	    DECLARE JobCursor CURSOR READ_ONLY FOR 
		SELECT Name FROM #JobsCheckDisable  
	    OPEN JobCursor
	    FETCH NEXT FROM JobCursor INTO @Jobname
	    WHILE @@FETCH_STATUS = 0
	    BEGIN
	        EXEC msdb.dbo.sp_update_job @Job_Name = @Jobname, @enabled = 0
	        FETCH NEXT FROM JobCursor INTO @Jobname
	    END
	    CLOSE JobCursor
	    DEALLOCATE JobCursor
END', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every30Seconds', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20161202, 
		@active_end_date=99991231, 
		@active_start_time=101, 
		@active_end_time=235959;
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO


