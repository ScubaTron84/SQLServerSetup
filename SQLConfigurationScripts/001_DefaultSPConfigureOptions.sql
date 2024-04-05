-- ======================================
/*	
	Description: Configure Server (sp_configure) values.
	Author: ScubaTron84
	Company: ScubaTron84
	Version: 1.0.0.0
	Creation Date: 2016-10-04 17:15 pm
*/
-- ======================================
USE master 
EXEC sp_configure N'Show advanced options', 1
RECONFIGURE WITH OVERRIDE
GO
EXEC sp_configure N'fill factor (%)', N'90'
GO
--USE 80% of avaiable server memory ROUNDED to the nearest 1000 megabytes. UNLESS OS is left with less than 4 GB, then 75% of memory is used
-- want a little buffer to grow to 85% but do not want to starve the OS of s tiny sql server.
DECLARE @MaxServerMemoryMB INT = (SELECT 
	CASE
		WHEN ROUND((total_physical_memory_kb /1024),-3) - round(total_physical_memory_kb/1024 * .80, -3) < 4000 THEN round(total_physical_memory_kb/1024 * .75, -3)
		ELSE round(total_physical_memory_kb/1024 * .80, -3)
	END 
	FROM sys.dm_os_sys_memory)
EXEC sp_configure N'max server memory (MB)', @MaxServerMemoryMB
GO
--Login Audit, Audit None =0, Failures only = 1, Successful only = 2, Both = 3
--EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'AuditLevel', REG_DWORD, 1
--GO
--Enable remote connections to SQL server
EXEC sp_configure N'remote access', N'1'
GO
--Enable DAC for the DBA team.
EXEC sp_configure 'remote admin connections', 1
GO
--Remove query timeout at server level
EXEC sp_configure N'remote query timeout (s)', 0
GO
--Set file stream access to trans-act SQL = 1, None = 0,  Full = 2
--EXEC sp_configure N'filestream access level', N'1'
--GO
--Enable optimization for ad hoc work loads
EXEC sp_configure N'optimize for ad hoc workloads', 1
GO
--Enable ad hoc distributed queries.
EXEC sp_configure 'Ad Hoc Distributed Queries', 1
GO
--Enable Database Mail XPs
EXEC sp_Configure 'Database Mail XPs', 1
GO
-- Set Max degrees of parallelism based on number of logical processors and MS recommendations https://support.microsoft.com/en-us/kb/2806535
-- exec xp_msver alternative way to get server info, including memory and processor info.
--DECLARE @NumberOfLogicalProcessors INT = (SELECT cpu_count from sys.dm_os_sys_info)
--EXEC sp_configure 'max degree of parallelism', @NumberOfLogicalProcessors
--GO
--Enable OLE procedures.
EXEC sp_configure 'Ole Automation Procedures', 1
GO
RECONFIGURE WITH OVERRIDE
GO
--Change maximum count of SQL Server error logs to 99
USE [master]
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'NumErrorLogs', REG_DWORD, 99
GO
