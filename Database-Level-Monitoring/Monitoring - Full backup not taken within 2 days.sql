USE [msdb]
GO

/****** Object:  Job [Coeo Monitoring - Full backup not taken within 2 days]    Script Date: 03/03/2023 14:18:40 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 03/03/2023 14:18:40 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Monitoring - Full backup not taken within 2 days', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Monitoring job to alert us if a backup has not been taken within 2 days. (Weekly backups taken on primary server)', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check if backup taken within last 2 days]    Script Date: 03/03/2023 14:18:41 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check if backup taken within last 2 days', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @threshold int = 48 -- CHANGE TIME PERIOD (Hours) TO SUIT NEEDS. 48 hours default
DECLARE @db_exclusion_list varchar(max) = '''' --comma separated list of databases to exclude from backup check

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

--Databases with no full backups in last 2 days
SELECT 
	CONVERT(CHAR(100), SERVERPROPERTY(''Servername'')) AS SERVER
	,bs.database_name
	,MAX(bs.backup_finish_date) AS last_db_backup_date
	,DATEDIFF(hh, MAX(bs.backup_finish_date), GETDATE()) AS [Backup Age (Hours)]
FROM msdb.dbo.backupset bs
	inner join sys.databases d --join sys.databases to exclude backup sets for databases that no longer exist
	on bs.name = d.name
WHERE (bs.type = ''D'' or bs.type = ''I'')
	AND bs.database_name NOT IN (SELECT NAME FROM #Exclusions)
	--and bs.database_creation_date < DATEADD(hh, -@threshold, GETDATE()) --exclude newly created databases that have not had a full backup yet
GROUP BY bs.database_name
HAVING (MAX(bs.backup_finish_date) < DATEADD(hh, -@threshold, GETDATE()))

--Raise error if any found
IF (@@ROWCOUNT > 0)
BEGIN
	RAISERROR (
			''A DB with no backup in 2 days has been identified''
			,16
			,1
			)
END

DROP TABLE #Exclusions', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily @ 08:00', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20230109, 
		@active_end_date=99991231, 
		@active_start_time=80000, 
		@active_end_time=235959, 
		@schedule_uid=N'28bff843-a299-40fc-92b9-1730a6a99faa'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
