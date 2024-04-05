SELECT e.name,tcpe.port FROM sys.endpoints e 
INNER JOIN sys.tcp_endpoints  tcpe ON tcpe.endpoint_id = e.endpoint_id
WHERE e.type = 4