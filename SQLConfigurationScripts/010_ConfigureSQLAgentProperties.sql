-- ======================================
/*	
	Description: Configure SQL Agent.
	Author: ScubaTron84
	Company: ScubaTron84
	Version: 1.0.0.0
	Creation Date: 2016-10-04 17:15 pm
*/
-- ======================================
USE [msdb]
GO
EXEC master.dbo.sp_MSsetalertinfo @failsafeoperator=N'DBAdmins', 
		@notificationmethod=1
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1, 
		@databasemail_profile=N'DefaultDatabaseMailProfile', 
		@use_databasemail=1
GO
EXEC msdb.dbo.sp_purge_jobhistory  @oldest_date='2016-09-06T20:15:23'
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_set_sqlagent_properties @jobhistory_max_rows=-1, 
		@jobhistory_max_rows_per_job=-1, 
		@email_save_in_sent_folder=1, 
		@databasemail_profile=N'DefaultDatabaseMailProfile', 
		@use_databasemail=1
GO
EXEC msdb.dbo.sp_purge_jobhistory  @oldest_date='2017-04-12T16:43:37'
GO
EXEC msdb.dbo.sp_set_sqlagent_properties @jobhistory_max_rows_per_job=-1
GO
