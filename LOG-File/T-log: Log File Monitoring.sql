create table #log_file_logical_usage
(database_name sysname primary key clustered,
log_file_used_size int)

create table #log_file_physical_usage
(database_name sysname primary key clustered,
log_file_physical_size int)

insert into #log_file_logical_usage
SELECT  instance_name as database_name, cntr_value as log_file_used_size
FROM sys.dm_os_performance_counters
where counter_name = 'Log File(s) Used Size (KB)'
and instance_name not in
('master', '_Total' , 'mssqlsystemresource' , 'model' , 'DBA_Admin' , 'msdb') 

insert into #log_file_physical_usage
SELECT instance_name as database_name, cntr_value as log_file_physical_size
FROM sys.dm_os_performance_counters
where
counter_name = 'Log File(s) Size (KB)'
and
instance_name not in
('master', '_Total' , 'mssqlsystemresource' , 'model' , 'DBA_Admin' , 'msdb')

use tempdb
checkpoint
go
use master
insert into DBA_Admin.dbo.tlog_usage_monitor
SELECT 
getdate() [date_time]
 ,DB_NAME(tdt.[database_id]) [database_name]
,d.[recovery_model_desc] [recovery_model]
,d.[log_reuse_wait_desc] [log_reuse_wait_desc]
,es.[original_login_name] [login_name]
,es.[program_name] [program_name]
,es.[host_name] [host_name]
,es.[session_id] [session_id]
,er.[blocking_session_id] [blocking_session_id]
,er.[wait_type] [wait_type]
,er.[last_wait_type] [last_wait_type]
,er.[status] [status]
,tat.[transaction_id] [transaction_id]
,tat.[transaction_begin_time] [transaction_begin_time]
,tdt.[database_transaction_begin_time] [database_transaction_begin_time]
--,tst.[open_transaction_count] [OpenTransactionCount] --Not present in SQL 2005
,
--CASE tdt.[database_transaction_state]
-- WHEN 1 THEN 'The transaction has not been initialized.'
-- WHEN 3 THEN 'The transaction has been initialized but has not generated any log records.'
-- WHEN 4 THEN 'The transaction has generated log records.'
-- WHEN 5 THEN 'The transaction has been prepared.'
-- WHEN 10 THEN 'The transaction has been committed.'
-- WHEN 11 THEN 'The transaction has been rolled back.'
-- WHEN 12 THEN 'The transaction is being committed. In this state the log record is being generated, but it has not been materialized or persisted.'
-- ELSE NULL --http://msdn.microsoft.com/en-us/library/ms186957.aspx
-- END
 tdt.[database_transaction_state]
--,est.[text] [input_buffer]
,SUBSTRING(est.text, (er.statement_start_offset/2)+1,
        ((CASE er.statement_end_offset
          WHEN -1 THEN DATALENGTH(est.text)
         ELSE er.statement_end_offset
         END - er.statement_start_offset)/2) + 1) AS [statement_text]
,tdt.[database_transaction_log_record_count] [database_transaction_log_record_count]
,cast(tdt.[database_transaction_log_bytes_used]/(1024*1024.0) as decimal(10,2)) [database_transaction_log_MB_used]
,cast(tdt.[database_transaction_log_bytes_reserved]/(1024*1024.0) as decimal(10,2))[database_transaction_log_MB_reserved]
,cast(tdt.[database_transaction_log_bytes_used_system]/(1024*1024.0) as decimal(10,2)) [database_transaction_log_MB_used_system]
,cast(tdt.[database_transaction_log_bytes_reserved_system]/(1024*1024.0) as decimal(10,2))[database_transaction_log_MB_reserved_system]
--,tdt.[database_transaction_begin_lsn] [database_transaction_begin_lsn]
--,tdt.[database_transaction_last_lsn] [database_transaction_last_lsn]
,cast(tlog.log_file_used_size/(1024.0)as decimal(10,2)) log_file_used_size_MB
,cast(tlog.log_file_physical_size/(1024.0) as decimal(10,2))  log_file_physical_size_MB
,tlog.log_file_percent_used
--INTO DBA_Admin.dbo.tlog_usage_monitor
FROM sys.dm_exec_requests er
INNER JOIN sys.dm_tran_session_transactions tst ON er.[session_id] = tst.[session_id]
INNER JOIN sys.dm_tran_database_transactions tdt ON tst.[transaction_id] = tdt.[transaction_id]
INNER JOIN sys.dm_tran_active_transactions tat ON tat.[transaction_id] = tdt.[transaction_id]
INNER JOIN sys.databases d ON d.[database_id] = tdt.[database_id]
INNER JOIN
(select
lu.database_name, lu.log_file_used_size, pu.log_file_physical_size,
cast((lu.log_file_used_size* 100.0)/ pu.log_file_physical_size as decimal(8,6))
as log_file_percent_used
FROM
#log_file_logical_usage lu
inner join
#log_file_physical_usage pu
on lu.database_name = pu.database_name) tlog
on tdt.[database_id] = db_id(tlog.database_name)
inner JOIN sys.dm_exec_sessions es ON es.[session_id] = er.[session_id]
inner JOIN sys.dm_exec_connections ec ON ec.[session_id] = es.[session_id]
--AND ec.[most_recent_sql_handle] <> 0x
cross APPLY sys.dm_exec_sql_text(er.sql_handle) est
--WHERE tdt.[database_transaction_state] >= 4
where es.session_id <> @@SPID
ORDER BY tdt.[database_transaction_begin_lsn]

drop table #log_file_logical_usage
drop table #log_file_physical_usage
