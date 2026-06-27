SELECT TranSession.[session_id], SessionS.[login_name] AS [Login Name], TranDB.[database_transaction_begin_time] AS [Start_Time],
CASE TranActive.transaction_type
WHEN 1 THEN 'Read/write transaction'
WHEN 2 THEN 'Read-only transaction'
WHEN 3 THEN 'System transaction'
END AS [Transaction_Type],
CASE TranActive.transaction_state
WHEN 1 THEN 'The transaction has not been initialized'
WHEN 2 THEN 'The transaction is active'
WHEN 3 THEN 'The transaction has ended. This is used for read-only transactions'
WHEN 5 THEN 'The transaction is in a prepared state and waiting resolution.'
WHEN 6 THEN 'The transaction has been committed'
WHEN 7 THEN 'The transaction is being rolled back'
WHEN 8 THEN 'The transaction has been rolled back'
END AS [Transaction_State],
TranDB.[database_transaction_log_record_count] AS [Log_Records],
TranDB.[database_transaction_log_bytes_used] AS [Log_Bytes_Used],
SQlText.text  AS [Last_Transaction_Text],
SQLQP.[query_plan] AS [Last_Query_Plan]
FROM sys.dm_tran_database_transactions TranDB
INNER JOIN sys.dm_tran_session_transactions TranSession
ON TranSession.[transaction_id] = TranDB.[transaction_id]
INNER JOIN sys.dm_tran_active_transactions TranActive
ON TranSession.[transaction_id] = TranActive.[transaction_id]
INNER JOIN sys.dm_exec_sessions SessionS
ON SessionS.[session_id] = TranSession.[session_id]
INNER JOIN sys.dm_exec_connections Connections
ON Connections.[session_id] = TranSession.[session_id]
LEFT JOIN sys.dm_exec_requests Request
ON Request.[session_id] = TranSession.[session_id]
CROSS APPLY sys.dm_exec_sql_text (Connections.[most_recent_sql_handle]) AS SQlText
OUTER APPLY sys.dm_exec_query_plan (Request.[plan_handle]) AS SQLQP
