$ErrorActionPreference = "Stop"

## Import necessary modules ##
Import-Module .\AAWHSQLDatabaseMigrations -Force

##Steps to migrate a database
#Get the list of databases to migrate
#Copy all logins from Source Instance to new instance related to the database (mapped to the db or in server roles that would grant access)
#Copy all linked servers from Source instance to New instance
#Copy all linked server users from Source instance to New instance
#Copy Server level permissions for the logins involved
#Backup the Databases on the source instance
#REstore the databases on the target instance  (NO RECOVERY)
#Establish database logshipping between the source and target instance (NO RECOVERY)
#Take last log backup
#Offline source database
#Restore last log backup to target instance (RECOVERY)
#Have users connect and verify they can access the new system. 

