USE [msdb]
GO

/****** Object:  Job [Coeo Monitoring - DBCC not completed within 8 days]    Script Date: 03/03/2023 14:18:09 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 03/03/2023 14:18:09 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Monitoring - DBCC not completed within 8 days', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Alerts if any databases have not had a good integrity check taken in the last 8 days', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check if DBCC completed in 8 days]    Script Date: 03/03/2023 14:18:09 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check if DBCC completed in 8 days', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET NOCOUNT ON

IF OBJECT_ID(N''tempdb..#DBDBCCInfo'') IS NOT NULL DROP TABLE #DBDBCCInfo
IF OBJECT_ID(N''tempdb..#DBCCValue'') IS NOT NULL DROP TABLE #DBCCValue
IF OBJECT_ID(N''tempdb..#databases'') IS NOT NULL DROP TABLE #databases
IF OBJECT_ID(N''tempdb..#Exclusions'') IS NOT NULL DROP TABLE #Exclusions

DECLARE 
	@DB_NAME SYSNAME, 
	@CMD VARCHAR(MAX),
	@db_exclusion_list varchar(max) = '''' --comma separated list of databases to exclude from backup check
	,@threshold int = 192 --Hours since last check DB threshold. Adjust based on needs. Default 8 days
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

--Create temp tables to store DBCC info in
CREATE TABLE #DBDBCCInfo (
	ParentObject VARCHAR(255)
	,[Object] VARCHAR(255)
	,Field VARCHAR(255)
	,[Value] VARCHAR(255)
	)

CREATE TABLE #DBCCValue (
	DatabaseName VARCHAR(255)
	,LastDBCC DATETIME
	)


SELECT DATABASE_ID, NAME
	into #databases
FROM SYS.databases
WHERE name <> ''tempdb''
	AND name not in (SELECT name from #Exclusions)
	and create_date < dateadd(HOUR,@threshold,CURRENT_TIMESTAMP)
	and state = 0


SELECT @DB_NAME = MIN(name)
FROM #databases

WHILE(@DB_NAME IS NOT NULL)
BEGIN
	SET @CMD = ''DBCC DBINFO ( [''+ @DB_NAME + '']) WITH TABLERESULTS, NO_INFOMSGS''
	INSERT INTO #DBDBCCInfo 
		EXECUTE (@CMD)
	INSERT INTO #DBCCValue (DatabaseName, LastDBCC) 
		SELECT 
			@DB_NAME
			, [Value] 
		FROM #DBDBCCInfo 
		WHERE Field = ''dbi_dbccLastKnownGood''
			AND Value < dateadd(HOUR,-@threshold,CURRENT_TIMESTAMP)
	-- EXCLUDE READ ONLY DBS WHERE DBCC INFO IS NOT UPDATED AND ALSO NEW DBs WHICH HAVE NOT BEEN CHECKED YET
	and Value <> ''1900-01-01 00:00:00.000''
	
	TRUNCATE TABLE #DBDBCCInfo

	SELECT @DB_NAME = MIN(name)
	FROM #databases
	WHERE name > @DB_NAME
END


SELECT *
FROM #DBCCValue


--Raise error if any found
if @@ROWCOUNT > 0
begin
	 set @error_msg = ''The below database with a DBCC check older than 8 days have been found. Please investigate: '' + char(13)+ STUFF(
	(
		SELECT '', '' + DatabaseName + '': ''+ convert(varchar,LastDBCC) AS [text()]
		FROM #DBCCValue
		ORDER BY DatabaseName
		FOR XML PATH ('''')
	), 1, 2, '''');

	RAISERROR (@error_msg, 16, 1)
end
ELSE
PRINT ''All good''


drop table #DBCCValue
drop table #DBDBCCInfo
DROP TABLE #databases
DROP TABLE #Exclusions
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily @ 08:00AM', 
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
		@active_end_time=235959, 
		@schedule_uid=N'bbcf9ee4-9401-45fe-a2b1-976f8fbd4582'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

