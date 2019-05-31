-- ======================================
/*	
	Description: Check for existing TCP endpoints that may already be configured on the SQL Instance.
	Author: ScubaTron84
	Company: 
	Version: 1.0.0.0
	Creation Date: 2016-10-04 17:15 pm
*/
-- ======================================

SELECT e.name,tcpe.port FROM sys.endpoints e 
INNER JOIN sys.tcp_endpoints  tcpe ON tcpe.endpoint_id = e.endpoint_id
WHERE e.type = 4