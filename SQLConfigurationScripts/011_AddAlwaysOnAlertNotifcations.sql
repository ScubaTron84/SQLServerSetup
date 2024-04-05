USE [msdb]
GO
EXEC msdb.dbo.sp_update_alert @name=N'AG Data Movement - Resumed', 
		@message_id=35265, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1, 
		@database_name=N'', 
		@notification_message=N'', 
		@event_description_keyword=N'', 
		@performance_condition=N'', 
		@wmi_namespace=N'', 
		@wmi_query=N'', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'AG Data Movement - Resumed', @operator_name=N'DBAdmins', @notification_method = 1
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_update_alert @name=N'AG Data Movement - Suspended', 
		@message_id=35264, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1, 
		@database_name=N'', 
		@notification_message=N'', 
		@event_description_keyword=N'', 
		@performance_condition=N'', 
		@wmi_namespace=N'', 
		@wmi_query=N'', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'AG Data Movement - Suspended', @operator_name=N'DBAdmins', @notification_method = 1
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_update_alert @name=N'AG Role Change', 
		@message_id=1480, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1, 
		@database_name=N'', 
		@notification_message=N'', 
		@event_description_keyword=N'', 
		@performance_condition=N'', 
		@wmi_namespace=N'', 
		@wmi_query=N'', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'AG Role Change', @operator_name=N'DBAdmins', @notification_method = 1
GO