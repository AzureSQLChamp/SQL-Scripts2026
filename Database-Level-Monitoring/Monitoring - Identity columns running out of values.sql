USE [msdb]
GO

/****** Object:  Job [DBA Group - Monitoring - Identity columns running out of values]    Script Date: 09/01/2023 10:22:19 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 09/01/2023 10:22:19 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Monitoring - Identity columns running out of values', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Monitoring job to check identity values', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check if AG primary]    Script Date: 09/01/2023 10:22:19 ******/
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
		@command=N'DECLARE @ServerName NVARCHAR(256) = @@SERVERNAME
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
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [check Identity columns running out of values]    Script Date: 09/01/2023 10:22:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'check Identity columns running out of values', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
SET NOCOUNT ON

DECLARE @identity varchar(max)

DECLARE @exclusions table (dbname sysname, schemaname sysname, objname sysname)

-- Add any exclusions here, e.g.:
-- INSERT @exclusions (dbname, schemaname, objname) VALUES (''mydb'', ''myschema'', ''mytable'')

IF OBJECT_ID(''tempdb..#ident'') IS NOT NULL
	DROP TABLE #ident

CREATE TABLE #ident
(
	type varchar(20),
	dbname sysname,
	schemaname sysname,
	objname sysname,
	percentused decimal(5,2)
)

INSERT #ident
EXEC sp_msforeachdb ''USE [?];
	WITH maxvals AS
	(
		SELECT ''''tinyint'''' AS typ, 255 AS maxval
		UNION ALL SELECT ''''smallint'''', 32767
		UNION ALL SELECT ''''int'''', 2147483647
		UNION ALL SELECT ''''bigint'''', 9223372036854775807
	)
	SELECT ''''IDENTITY'''' AS type,
		''''?'''' AS dbname,
		s.name,
		t.name,
		CONVERT(decimal(5,2), (1.0 * CONVERT(bigint, id.last_value) / mv.maxval) * 100) AS percentused
	FROM sys.identity_columns id
		JOIN sys.types ty ON id.user_type_id = ty.user_type_id
		JOIN sys.tables t ON id.object_id = t.object_id
		JOIN sys.schemas s ON t.schema_id = s.schema_id
		LEFT JOIN maxvals mv ON ty.name = mv.typ
	WHERE (1.0 * CONVERT(bigint, id.last_value) / mv.maxval) * 100 > 80
	UNION ALL
	SELECT ''''SEQUENCE'''' AS type,
		''''?'''' AS dbname,
		sch.name,
		s.name,
		CONVERT(decimal(5,2), (1.0 * (CONVERT(decimal(38,0), s.current_value) - CONVERT(decimal(38,0), s.start_value)) / (CONVERT(decimal(38,0), s.maximum_value) - CONVERT(decimal(38,0), s.start_value))) * 100) AS percentused
	FROM sys.sequences s
		JOIN sys.types ty ON s.user_type_id = ty.user_type_id
		JOIN sys.schemas sch ON s.schema_id = sch.schema_id
	WHERE (1.0 * CONVERT(bigint, s.current_value) / CONVERT(bigint, s.maximum_value)) * 100 > 80
		AND is_cycling = 0''

SET @identity = STUFF(
	(
		SELECT '', '' + dbname + ''.''
			+ schemaname + ''.''
			+ objname + '': ''
			+ CONVERT(varchar(6), percentused) + ''%'' AS [text()]
		FROM #ident i
		WHERE NOT EXISTS (SELECT * FROM @exclusions e WHERE e.dbname = i.dbname AND e.schemaname = i.schemaname AND e.objname = i.objname)
		ORDER BY dbname
		FOR XML PATH ('''')
	), 1, 2, '''');

IF @identity IS NOT NULL
	RAISERROR(''The following identity columns or sequences are within 20%% of the max value: %s'', 16, 1, @identity)
ELSE
	PRINT ''No issues found''
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily @ 07:00AM', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20230109, 
		@active_end_date=99991231, 
		@active_start_time=70000, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
