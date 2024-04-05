-- ======================================
/*	
	Description: Creates the DBAdmins operator for alerting and job failures.
	Author: ScubaTron84
	Company: ScubaTron84
	Version: 1.0.0.0
	Creation Date: 2016-10-04 17:15 pm
*/
-- ======================================
USE [msdb]
GO
IF NOT EXISTS (SELECT [id] FROM msdb.dbo.sysoperators WHERE [name] = 'dbadmins')
BEGIN
	EXEC msdb.dbo.sp_add_operator @name=N'DBAdmins', @enabled=1, @email_address=N'DBAdmins@Dbas.com'
END
GO


