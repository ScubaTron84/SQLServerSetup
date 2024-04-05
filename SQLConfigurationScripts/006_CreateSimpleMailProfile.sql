-- ============================================
/*
	Description: Setup of database mail.
	Author: ScubaTron84
	Company: ScubaTron84
	Version: 1.0.0.0
	Creation Date: 2016-10-04 17:15 pm
*/
-- ============================================

--Enable Database Mail XPs
exec sp_configure 'Database Mail XPs', 1
RECONFIGURE WITH OVERRIDE

--Configure database mail
DECLARE @profile_name sysname,
        @account_name sysname,
        @SMTP_servername sysname,
        @email_address NVARCHAR(128),
	    @display_name NVARCHAR(128),
		@replyto_address NVARCHAR(128),
		@ServerName SYSNAME,
		@DescriptionProfile NVARCHAR(128),
		@DescriptionAccount NVARCHAR(128);
		
		SET @ServerName = @@SERVERNAME
-- Profile name. Replace with the name for your profile
        SET @profile_name = 'DefaultDatabaseMailProfile';
		SET @DescriptionProfile = 'Public Profile for database mail on '+ @ServerName
-- Account information. Replace with the information for your account.
		SET @account_name = @ServerName + 'PublicDatabaseMailAccount';
		SET @SMTP_servername = 'exchange.*****.com';
		SET @email_address = @ServerName+'@*****.com';
        SET @display_name = @ServerName;
		SET @replyto_address = 'DONOT_REPLY_'+@ServerName+'@*****.com'
		SET @DescriptionAccount = 'Public mail account on '+ @ServerName


-- Verify the specified account and profile do not already exist.
IF EXISTS (SELECT * FROM msdb.dbo.sysmail_profile WHERE name = @profile_name)
BEGIN
  PRINT 'The specified Database Mail profile (DefaultDatabaseMailProfile) already exists.'
  GOTO done;
END;

IF EXISTS (SELECT * FROM msdb.dbo.sysmail_account WHERE name = @account_name )
BEGIN
 RAISERROR('The specified Database Mail account already exists.', 16, 1) ;
 GOTO done;
END;

-- Start a transaction before adding the account and the profile
BEGIN TRANSACTION ;

DECLARE @rv INT;

-- Add the account
EXECUTE @rv=msdb.dbo.sysmail_add_account_sp
    @account_name = @account_name,
    @email_address = @email_address,
    @display_name = @display_name,
    @mailserver_name = @SMTP_servername,
	@replyto_address = @replyto_address,
	@Description = @DescriptionAccount;

IF @rv<>0
BEGIN
    RAISERROR('Failed to create the specified Database Mail account.', 16, 1) ;
    GOTO done;
END

-- Add the profile
EXECUTE @rv=msdb.dbo.sysmail_add_profile_sp
    @profile_name = @profile_name,
	@description = @DescriptionProfile ;

IF @rv<>0
BEGIN
    RAISERROR('Failed to create the specified Database Mail profile (DefaultDatabaseMailProfile).', 16, 1);
	ROLLBACK TRANSACTION;
    GOTO done;
END;

-- Associate the account with the profile.
EXECUTE @rv=msdb.dbo.sysmail_add_profileaccount_sp
    @profile_name = @profile_name,
    @account_name = @account_name,
    @sequence_number = 1 ;

IF @rv<>0
BEGIN
    RAISERROR('Failed to associate the speficied profile with the specified account.', 16, 1) ;
	ROLLBACK TRANSACTION;
    GOTO done;
END;

EXECUTE @rv= msdb.dbo.sysmail_add_principalprofile_sp  
    @profile_name = @profile_name,  
    @principal_name = 'public',  
    @is_default = 1 ;  

IF @rv<>0
BEGIN
    RAISERROR('Failed to make Database Mail profile (DefaultDatabaseMailProfile) public.', 16, 1);
	ROLLBACK TRANSACTION;
    GOTO done;
END;

COMMIT TRANSACTION;

done:

GO