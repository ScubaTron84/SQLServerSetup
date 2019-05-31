-- ======================================
/*	
	Description: Get the fully qualified domain name forlater user.
	Author: ScubaTron84
	Company: 
	Version: 1.0.0.0
	Creation Date: 2016-10-04 17:15 pm
*/
-- ======================================

DECLARE @Domain NVARCHAR(100)
EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', 'SYSTEM\CurrentControlSet\services\Tcpip\Parameters', N'Domain', @Domain OUTPUT
SELECT Cast(SERVERPROPERTY('MachineName') as nvarchar) + '.' + @Domain AS FQDN