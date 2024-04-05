-- ======================================
/*	
	Description: Creates the default HADR mirroring endpoint on SQL, using AES encryption, with Kerberos auth.
	Author: ScubaTron84
	Company: ScubaTron84
	Version: 1.0.0.0
	Creation Date: 2016-10-04 17:15 pm
*/
-- ======================================
IF NOT EXISTS (SELECT 1 FROM sys.endpoints WHERE name = 'Hadr_Endpoint')
BEGIN 
	CREATE ENDPOINT [Hadr_endpoint] 
		STATE=STARTED
		AS TCP (LISTENER_PORT = 5022, LISTENER_IP = ALL)
		FOR DATA_MIRRORING (ROLE = ALL, AUTHENTICATION = WINDOWS NEGOTIATE
	, ENCRYPTION = REQUIRED ALGORITHM AES)

	PRINT 'Mirroring Endpoint (Hadr_Endpoint) Created'
	ALTER AUTHORIZATION ON ENDPOINT::HADR_endpoint TO sa;     
END
ELSE 
BEGIN
	PRINT 'Mirroring Endpoint (Hadr_Endpoint) already exists'
END
--Permission the endpoint ASSUMES HADR_ENDPOINT as name!
DECLARE @DBEngineLogin       VARCHAR(100)
DECLARE @SQL Nvarchar(200)
SELECT @DBEngineLogin = service_account FROM sys.dm_server_services WHERE servicename = 'SQL Server (MSSQLSERVER)'

IF NOT EXISTS (SELECT NAme from sys.server_principals where name = @DBEngineLogin)
BEGIN
	SET @SQL = 'CREATE LOGIN '+ QuoteName(@DBEngineLogin) + ' FROM WINDOWS'
	EXEC (@SQL)
END

SET @SQL = 'GRANT CONNECT ON ENDPOINT::HADR_Endpoint TO ' + QuoteName(@DBEngineLogin)
EXEC (@SQL)
GO