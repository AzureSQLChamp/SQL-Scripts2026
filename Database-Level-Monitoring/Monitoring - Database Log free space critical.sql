USE [msdb]
GO

/****** Object:  Job [DBA Group - Monitoring - Database Log free space critical]    Script Date: 13/01/2023 08:35:15 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 13/01/2023 08:35:15 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Coeo Monitoring - Database Log free space critical', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Fails if there are any log files with less than 10% of free space', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Log Free Space check]    Script Date: 13/01/2023 08:35:15 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Log Free Space check', 
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

IF OBJECT_ID(''tempdb..#logfiles'') IS NOT NULL DROP TABLE #logfiles
IF OBJECT_ID(''tempdb..#dbccsqlperf'') IS NOT NULL DROP TABLE #dbccsqlperf
IF OBJECT_ID(''tempdb..#logsfillingup'') IS NOT NULL DROP TABLE #logsfillingup

DECLARE @msg varchar(max);

CREATE TABLE #dbccsqlperf
(
    DatabaseName sysname,
    [Log Size (MB)] float,
    [Log Space Used (%)] float,
    status tinyint
)
CREATE TABLE #logfiles (
	id INT identity(1, 1)
	,database_id INT
	,file_id INT
	,size INT
	,spaceused INT
	,[spaceused%] int
	,max_size INT
	,growth INT
	,disk_available_MB int
	)
INSERT INTO #dbccsqlperf
EXEC(''dbcc sqlperf(logspace)'')

INSERT INTO #logfiles
	(database_id, file_id, size, [spaceused%],spaceused, growth, max_size, disk_available_MB)
SELECT 
	db_id(db.DatabaseName),
	mf.file_id,
	size/128,
	[Log Space Used (%)],
	(size*([Log Space Used (%)]/100))/128,
	growth/128,
	max_size/128,
	oss.available_bytes/1024/1024
FROM #dbccsqlperf db
inner join sys.master_files mf
    on db_id(db.DatabaseName) = mf.database_id
	cross apply sys.dm_os_volume_stats(db_id(db.DatabaseName), mf.file_id) oss
where type_desc = ''log''
	and db.DatabaseName <> ''tempdb''
	and [Log Space Used (%)] >= 90


SELECT
	db_name(database_id) as [DBName],
	su.[SpaceUsed (%)]
into #logsfillingup
from #logfiles
	cross apply 
		( select case 
				when growth = 0 then [spaceused%]
				when growth > 0 and (max_size = 0 or max_size = 2097152) and (max_size > disk_available_MB) THEN spaceused / cast((size + disk_available_MB) as float)*100
				when growth > 0 and (max_size = 0) THEN spaceused / cast(2097152 as float)*100
				ELSE spaceused / cast(max_size as float)*100 end AS [SpaceUsed (%)]
		) su
Where su.[SpaceUsed (%)] > 90

IF @@ROWCOUNT > 0
BEGIN
	SET @msg = STUFF(
		(
			SELECT '', '' + ''The log for database '' + DBName + '' is '' + cast([SpaceUsed (%)] as varchar) + '' full''
		from #logsfillingup
		order by [SpaceUsed (%)] desc
		FOR XML PATH ('''')
			), 1, 2, '''');

	RAISERROR(@msg,16,1)
END

', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every 5 Minutes', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=5, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20230113, 
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
