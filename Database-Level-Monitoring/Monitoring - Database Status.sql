USE [msdb]
GO

/****** Object:  Job [Coeo Monitoring - Database Status]    Script Date: 03/03/2023 14:17:43 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 03/03/2023 14:17:43 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Monitoring - Database Status', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Coeo - This monitor checks the database status as reported by Microsoft SQL Server. Status check is done by running a query against the master database of the SQL instance that returns the database state. If you receive an alert from this monitor, an action is required in order to bring the database back to an operational state.', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check Database Status]    Script Date: 03/03/2023 14:17:43 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check Database Status', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE 
	@db_exclusion_list varchar(max) = '''' --comma separated list of databases to exclude from backup check
	,@error_msg varchar(max)

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
	
SELECT 
	name
	,state_desc
INTO #Databases
FROM sys.databases
WHERE state <> 0
	and name not in (SELECT * FROM #Exclusions)

if @@ROWCOUNT > 0
begin
	 set @error_msg = ''The below database are in an unhealthy state. Please investigate: '' + char(13)+ STUFF(
	(
		SELECT '', '' + name + '' is ''+ state_desc AS [text()]
		FROM #databases
		ORDER BY name
		FOR XML PATH ('''')
	), 1, 2, '''');

	RAISERROR (@error_msg, 16, 1)
end

DROP TABLE #Exclusions
DROP TABLE #Databases', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every 10 minutes', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=10, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20221219, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'00ac999c-99a5-4a66-9d4e-53c1d7f38449'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

