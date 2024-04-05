-- ======================================
/*	
	Description: Creates the default AlwaysOn Alerts.
	Author: ScubaTron84
	Company: ScubaTron84
	Version: 1.0.0.0
	Creation Date: 2016-10-04 17:15 pm
*/
-- ======================================
IF NOT EXISTS (SELECT NAME FROM msdb.dbo.sysalerts where name = N'AG Data Movement - Resumed')
BEGIN
	EXEC msdb.dbo.sp_add_alert @name=N'AG Data Movement - Resumed', 
		@message_id=35265, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
END
IF NOT EXISTS (SELECT NAME FROM msdb.dbo.sysalerts where name = N'AG Data Movement - Suspended')
BEGIN
	EXEC msdb.dbo.sp_add_alert @name=N'AG Data Movement - Suspended', 
		@message_id=35264, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
END
IF NOT EXISTS (SELECT NAME FROM msdb.dbo.sysalerts where name = N'AG Role Change')
BEGIN
/****** Object:  Alert [AG Role Change]    Script Date: 10/4/2016 5:33:22 PM ******/
	EXEC msdb.dbo.sp_add_alert @name=N'AG Role Change', 
		@message_id=1480, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
END


