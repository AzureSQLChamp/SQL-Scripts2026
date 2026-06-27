
DECLARE @name NVARCHAR(256) -- database name  
DECLARE @path NVARCHAR(512) -- path for backup files  
DECLARE @fileName NVARCHAR(512) -- filename for backup  
DECLARE @fileDate NVARCHAR(40) -- used for file name
 
-- specify database backup directory
SET @path = 'C:\'  
 
-- specify filename format
SELECT @fileDate = CONVERT(NVARCHAR(20),GETDATE(),112) 
 
DECLARE db_cursor CURSOR READ_ONLY FOR  
SELECT name 
FROM master.sys.databases 
WHERE name NOT IN ('master','model','msdb','tempdb')  -- exclude these databases
AND state = 0 -- database is online
AND is_in_standby = 0 -- database is not read only for log shipping
 
OPEN db_cursor   
FETCH NEXT FROM db_cursor INTO @name   
 
WHILE @@FETCH_STATUS = 0   
BEGIN   
   SET @fileName = @path + @name + '_' + @fileDate + '.BAK'  
   BACKUP DATABASE @name TO DISK = @fileName  
 
   FETCH NEXT FROM db_cursor INTO @name   
END   
 
CLOSE db_cursor   
DEALLOCATE db_cursor

============================ SCRIPT 2 ========================
DECLARE @DatabaseName sysname
DECLARE @BackupPath nvarchar(500)
DECLARE @SQL nvarchar(max)

-- Set the backup path
SET @BackupPath = 'C:\SQL_DATA\Backup\' -- Replace with your desired backup path

-- Create a cursor to loop through all user databases
DECLARE db_cursor CURSOR FOR
SELECT name
FROM sys.databases
WHERE database_id > 4 -- Exclude system databases

OPEN db_cursor

FETCH NEXT FROM db_cursor INTO @DatabaseName

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Generate the dynamic SQL statement for each database
    DECLARE @BackupFileName nvarchar(500)
    SET @BackupFileName = @BackupPath + @DatabaseName + '_' + REPLACE(CONVERT(nvarchar(16), GETDATE(), 120), ':', '_') + '.bak'
    SET @SQL = 'BACKUP DATABASE ' + QUOTENAME(@DatabaseName) + ' TO DISK = ''' + @BackupFileName + ''' WITH COMPRESSION'

    -- Execute the backup command
    EXEC sp_executesql @SQL

    FETCH NEXT FROM db_cursor INTO @DatabaseName
END

CLOSE db_cursor
DEALLOCATE db_cursor
