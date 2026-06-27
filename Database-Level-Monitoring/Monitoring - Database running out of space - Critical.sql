USE [msdb]
GO

/****** Object:  Job [Coeo Monitoring - Database running out of space - Critical]    Script Date: 03/03/2023 14:15:51 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 03/03/2023 14:15:51 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Monitoring - Database running out of space - Critical', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Alert for database running out of space', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check if AG primary]    Script Date: 03/03/2023 14:15:51 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check if AG primary', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=1, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--Old versions of SQL (2012 -)

DECLARE @ServerName NVARCHAR(256)  = @@SERVERNAME 
DECLARE @RoleDesc NVARCHAR(60)
SELECT @RoleDesc = a.role_desc
    FROM sys.dm_hadr_availability_replica_states AS a
    JOIN sys.availability_replicas AS b
        ON b.replica_id = a.replica_id
WHERE b.replica_server_name = @ServerName
IF @RoleDesc = ''SECONDARY''
RAISERROR (''Stop - this is the secondary'', 16, -1)
ELSE
PRINT ''Proceed - this is the primary''


IF ((SELECT ISNULL(sys.fn_hadr_is_primary_replica(''ReportServer_Native''), 1)) <> 1)
    BEGIN
           -- If this is not the primary replica, force step to fail
           RAISERROR(''Not Primary'', 11, 1);
    END
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check DB free space %]    Script Date: 03/03/2023 14:15:51 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check DB free space %', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'IF OBJECT_ID(''tempdb..#masterfiles'') IS NOT NULL
	DROP TABLE #masterfiles

DECLARE @threshold float = 0.9 --Used space threshold: default 90%
DECLARE @db_exclusion_list varchar(max) = '''' --comma separated list of databases to exclude from DB space check

DECLARE @rowcount INT
DECLARE @i INT = 1
DECLARE @databaseid INT
DECLARE @fileid INT
DECLARE @size INT
DECLARE @maxsize INT
DECLARE @growth INT
DECLARE @sql NVARCHAR(max)
DECLARE @usedspace INT
DECLARE @diskspace BIGINT
DECLARE @error_msg VARCHAR(max)


CREATE TABLE #Exclusions  
(  
name SYSNAME  
)  
  
  
DECLARE   
@xml as xml,  
@str as varchar(100)  
SET @xml = cast((''<X>''+replace(@db_exclusion_list,'','' ,''</X><X>'')+''</X>'') as xml)  
INSERT INTO #Exclusions  
SELECT N.value(''.'', ''SYSNAME'') as value   
FROM @xml.nodes(''X'') as T(N)  
  
DELETE FROM #Exclusions  
WHERE NAME NOT IN (SELECT NAME FROM SYS.DATABASES)  


CREATE TABLE #masterfiles (
	id INT identity(1, 1)
	,database_id INT
	,file_id INT
	,size INT
	,max_size INT
	,growth INT
	)

INSERT INTO #masterfiles
SELECT mf.database_id
	,file_id
	,size*8
	,max_size
	,growth
FROM sys.master_files mf
	inner join sys.databases d
	on mf.database_id = d.database_id
WHERE type = 0
	and d.state = 0
	and d.name not in (select name from #Exclusions)

--select *
--from #masterfiles
--where database_id = db_id('''')

SELECT @rowcount = COUNT(0)
FROM #masterfiles

SET @error_msg = ''A DB data file has less than '' + convert(varchar,@threshold) + '' Percent free space, please investigate''

WHILE @i < @rowcount
BEGIN
	SELECT @databaseid = database_id
		,@fileid = file_id
		,@size = size
		,@maxsize = max_size
		,@growth = growth
	FROM #masterfiles
	WHERE id = @i

	SET @sql = N''use '' +  QUOTENAME(DB_NAME(@databaseid)) + N''
			select @usedspace = FILEPROPERTY (FILE_NAME(@fileid), ''''spaceused'''')''

	EXEC sp_executesql @sql
		,N''@usedspace int output, @fileid int''
		,@fileid = @fileid
		,@usedspace = @usedspace OUTPUT

	SET @usedspace = @usedspace*8
	--case 1: when no growth on DB file allowed, check available space / total space * 100
	--Is growth allowed? growth = 0
	IF @growth = 0
	BEGIN
		IF (cast(@usedspace AS FLOAT) / cast(@size AS FLOAT)) > @threshold
		BEGIN
			PRINT ''Case 1 '' + db_name(@databaseid) + char(13) + ''Size (KB):'' + convert(varchar,@size) + char(13) + ''Space Used (KB):'' + convert(varchar,@usedspace)

			RAISERROR (
					@error_msg
					,16
					,1
					)
		END
	END

	--case 2: when file growth on DB file allowed, add free space on disk to DB available space / total space * 100
	--growth > 0
	IF @growth > 1
		AND @maxsize = - 1
	BEGIN
		SELECT @diskspace = available_bytes/1024
		FROM sys.dm_os_volume_stats(@databaseid, @fileid)

		IF (cast(@usedspace AS FLOAT) / (cast(@diskspace AS FLOAT) + cast(@size AS FLOAT))) > @threshold
		BEGIN
			PRINT ''Case 2 '' + db_name(@databaseid) + char(13) + ''Size (KB):'' + convert(varchar,@size) + char(13) + ''Space Used (KB):'' + convert(varchar,@usedspace) + char(13) + ''Disk Space (KB):'' + convert(varchar,@diskspace) + char(13) 
			SELECT @usedspace ,@diskspace ,@size, @fileid
			RAISERROR (
					@error_msg
					,16
					,1
					)
		END
	END

	--case 3: when file growth on DB file limited, check max size / total space * 100
	--growth >0
	IF @growth > 1
		AND @maxsize <> 1
		set @maxsize = @maxsize *8
		IF cast(@usedspace AS FLOAT) / cast(@maxsize AS FLOAT) > @threshold
		BEGIN
			PRINT ''Case 3 '' + db_name(@databaseid) + char(13) + ''Space Used (KB):'' + convert(varchar,@usedspace) + char(13) + ''Max Size (KB):'' + convert(varchar,@maxsize) + char(13) 

			RAISERROR (
					@error_msg
					,16
					,1
					)
		END

	SET @i = @i + 1
	SET @SQL = ''''
END

DROP TABLE #masterfiles
DROP TABLE #Exclusions', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every 15 Minutes', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=15, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20230106, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'95e3e37d-0254-4b35-b165-8627bce99199'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

