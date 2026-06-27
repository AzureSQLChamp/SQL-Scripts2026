USE [msdb]
GO

/****** Object:  Job [Coeo Monitoring - Log backup not taken with 4 hours]    Script Date: 03/03/2023 14:19:56 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 03/03/2023 14:19:56 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Monitoring - Log backup not taken with 4 hours', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'This job alerts if log backups not taken in over 4 hours', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check if log backup taken within 4 hours]    Script Date: 03/03/2023 14:19:56 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check if log backup taken within 4 hours', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET QUOTED_IDENTIFIER ON;

-- DBs with no log backup taken within 4 hours
DECLARE @threshold int = 4 -- CHANGE TIME PERIOD (Hours) TO SUIT NEEDS. 4 hours default
DECLARE @db_exclusion_list varchar(max) = '''' --comma separated list of databases to exclude from backup check
DECLARE @dbs varchar(max)

IF OBJECT_ID(''tempdb.dbo.#Exclusions'') IS NOT NULL
	DROP TABLE #Exclusions;

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

INSERT INTO #Exclusions (name)
SELECT d.database_name
FROM sys.availability_databases_cluster d
JOIN sys.availability_groups ag ON d.group_id = ag.group_id
JOIN sys.dm_hadr_availability_group_states ags ON ag.group_id = ags.group_id
WHERE (ag.automated_backup_preference_desc = ''primary'' AND ags.primary_replica <> @@SERVERNAME)
	OR (ag.automated_backup_preference_desc = ''secondary'' AND ags.primary_replica = @@SERVERNAME)

SET @dbs = STUFF(
	(
		SELECT '', '' + name AS [text()]
		FROM sys.databases d
		WHERE name <> ''model''
			AND recovery_model_desc <> ''SIMPLE''
			AND state_desc = ''ONLINE''
			AND source_database_id IS NULL
			AND NOT EXISTS
			(
				SELECT *
				FROM msdb.dbo.backupset bs
				WHERE bs.database_name = d.name
					AND bs.type = ''L''
					AND bs.backup_finish_date >= DATEADD(hh, -@threshold, GETDATE())
			)
			AND NOT EXISTS
			(
				SELECT *
				FROM #Exclusions e
				WHERE e.name = d.name
			)
		ORDER BY name
		FOR XML PATH ('''')
	), 1, 2, '''');


--Raise error if any found
IF @dbs IS NOT NULL
	RAISERROR(''The following databases have not had a log backup in the last %d hrs: %s'', 16, 1, @threshold, @dbs);
ELSE
	PRINT ''No issues found''
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every 4 hours', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=4, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20230109, 
		@active_end_date=99991231, 
		@active_start_time=0, 
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
