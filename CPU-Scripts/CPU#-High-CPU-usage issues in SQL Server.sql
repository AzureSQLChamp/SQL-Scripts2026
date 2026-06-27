/*
Step 1: Verify that SQL Server is causing high CPU usage
Use one of the following tools to check whether the SQL Server process is actually contributing to high CPU usage:

Task Manager: On the Process tab, check whether the CPU column value for SQL Server Windows NT-64 Bit is close to 100 percent.

Performance and Resource Monitor (perfmon)

Counter: Process/%User Time, % Privileged Time
Instance: sqlservr
You can use the following PowerShell script to collect the counter data over a 60-second span:
*/

$serverName = $env:COMPUTERNAME
$Counters = @(
    ("\\$serverName" + "\Process(sqlservr*)\% User Time"), ("\\$serverName" + "\Process(sqlservr*)\% Privileged Time")
)
Get-Counter -Counter $Counters -MaxSamples 30 | ForEach {
    $_.CounterSamples | ForEach {
        [pscustomobject]@{
            TimeStamp = $_.TimeStamp
            Path = $_.Path
            Value = ([Math]::Round($_.CookedValue, 3))
        }
        Start-Sleep -s 2
    }
}

/*
Database Level CPU utilization
*/

WITH DB_CPU AS
(SELECT	DatabaseID, 
		DB_Name(DatabaseID)AS [DatabaseName], 
		SUM(total_worker_time)AS [CPU_Time(Ms)] 
FROM	sys.dm_exec_query_stats AS qs 
CROSS APPLY(SELECT	CONVERT(int, value)AS [DatabaseID]  
			FROM	sys.dm_exec_plan_attributes(qs.plan_handle)  
			WHERE	attribute =N'dbid')AS epa GROUP BY DatabaseID) 
SELECT	ROW_NUMBER()OVER(ORDER BY [CPU_Time(Ms)] DESC)AS [SNO], 
	DatabaseName AS [DBName], [CPU_Time(Ms)], 
	CAST([CPU_Time(Ms)] * 1.0 /SUM([CPU_Time(Ms)]) OVER()* 100.0 AS DECIMAL(5, 2))AS [CPUPercent] 
FROM	DB_CPU 
WHERE	DatabaseID > 4 -- system databases 
	AND DatabaseID <> 32767 -- ResourceDB 
ORDER BY SNO OPTION(RECOMPILE); 


/*
To identify the queries that are responsible for high-CPU activity currently, run the following statement:
*/
SELECT TOP 10 s.session_id,
           r.status,
           r.cpu_time,
           r.logical_reads,
           r.reads,
           r.writes,
           r.total_elapsed_time / (1000 * 60) 'Elaps M',
           SUBSTRING(st.TEXT, (r.statement_start_offset / 2) + 1,
           ((CASE r.statement_end_offset
                WHEN -1 THEN DATALENGTH(st.TEXT)
                ELSE r.statement_end_offset
            END - r.statement_start_offset) / 2) + 1) AS statement_text,
           COALESCE(QUOTENAME(DB_NAME(st.dbid)) + N'.' + QUOTENAME(OBJECT_SCHEMA_NAME(st.objectid, st.dbid)) 
           + N'.' + QUOTENAME(OBJECT_NAME(st.objectid, st.dbid)), '') AS command_text,
           r.command,
           s.login_name,
           s.host_name,
           s.program_name,
           s.last_request_end_time,
           s.login_time,
           r.open_transaction_count
FROM sys.dm_exec_sessions AS s
JOIN sys.dm_exec_requests AS r ON r.session_id = s.session_id CROSS APPLY sys.Dm_exec_sql_text(r.sql_handle) AS st
WHERE r.session_id != @@SPID
ORDER BY r.cpu_time DESC

/*
If queries aren't driving the CPU at this moment, you can run the following statement to look for historical CPU-bound queries:
*/
SELECT TOP 10 st.text AS batch_text,
    SUBSTRING(st.TEXT, (qs.statement_start_offset / 2) + 1, ((CASE qs.statement_end_offset WHEN - 1 THEN DATALENGTH(st.TEXT) ELSE qs.statement_end_offset END - qs.statement_start_offset) / 2) + 1) AS statement_text,
    (qs.total_worker_time / 1000) / qs.execution_count AS avg_cpu_time_ms,
    (qs.total_elapsed_time / 1000) / qs.execution_count AS avg_elapsed_time_ms,
    qs.total_logical_reads / qs.execution_count AS avg_logical_reads,
    (qs.total_worker_time / 1000) AS cumulative_cpu_time_all_executions_ms,
    (qs.total_elapsed_time / 1000) AS cumulative_elapsed_time_all_executions_ms
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(sql_handle) st
ORDER BY(qs.total_worker_time / qs.execution_count) DESC

--SQL Server – Get CPU Usage History for last 2days
	
DECLARE​​ @ts_now​​ bigint​​ =​​ (SELECT​​ cpu_ticks/(cpu_ticks/ms_ticks)​​ FROM​​ sys.dm_os_sys_info​​ WITH​​ (NOLOCK));​​ 
SELECT​​ SQLProcessUtilization​​ AS​​ [SQL Server Process CPU Utilization],​​ 
 ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​​​ SystemIdle​​ AS​​ [System Idle Process],​​ 
  ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​​​ 100​​ -​​ SystemIdle​​ -​​ SQLProcessUtilization​​ AS​​ [Other Process CPU Utilization],​​ 
   ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​ ​​​​ DATEADD(ms,​​ -3 *​​ (@ts_now​​ -​​ [timestamp]),​​ GETDATE())​​ AS​​ [Event Time]​​ 
FROM​​ (​​ 
  ​​​​ SELECT​​ record.value('(./Record/@id)[1]',​​ 'int')​​ AS​​ record_id,​​ 
   record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]',​​ 'int')​​ 
   AS​​ [SystemIdle],​​ 
   record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]',​​ 
   'int')​​ 
   AS​​ [SQLProcessUtilization],​​ [timestamp]​​ 
  ​​​​ FROM​​ (​​ 
   SELECT​​ [timestamp],​​ CONVERT(xml,​​ record)​​ AS​​ [record]​​ 
   FROM​​ sys.dm_os_ring_buffers​​ WITH​​ (NOLOCK)
   WHERE​​ ring_buffer_type​​ =​​ N'RING_BUFFER_SCHEDULER_MONITOR'​​ 
   AND​​ record​​ LIKE​​ N'%<SystemHealth>%')​​ AS​​ x​​ 
  ​​​​ )​​ AS​​ y​​ 
ORDER​​ BY​​ record_id​​ DESC​​ OPTION​​ (RECOMPILE);

Ref:
https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/troubleshoot-high-cpu-usage-issues
