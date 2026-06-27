-- Find your most expensive queries in the Plan Cache
-- This script lists the top 100 statements from the Plan Cache in descending order of computed Gross Cost (SubTreeCost * UseCounts).

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

WITH XMLNAMESPACES
(
    DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
)
, core
AS (SELECT DB_NAME(q.dbid) AS [Database],
           OBJECT_NAME(q.objectid, q.dbid) AS [Object],
           eqp.query_plan AS [QueryPlan],
           ecp.plan_handle [PlanHandle],
           q.[text] AS [Statement],
           n.value('(@StatementOptmLevel)[1]', 'VARCHAR(25)') AS OptimizationLevel,
           ISNULL(CAST(n.value('(@StatementSubTreeCost)[1]', 'VARCHAR(128)') AS FLOAT), 0) AS SubTreeCost,
           ecp.usecounts [UseCounts],
           ecp.size_in_bytes [SizeInBytes]
    FROM sys.dm_exec_cached_plans AS ecp
        CROSS APPLY sys.dm_exec_query_plan(ecp.plan_handle) AS eqp
        CROSS APPLY sys.dm_exec_sql_text(ecp.plan_handle) AS q
        CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') AS qn(n) )
SELECT TOP (100)
       [Database],
       [Object],
       QueryPlan,
       PlanHandle,
       [Statement],
       OptimizationLevel,
       SubTreeCost,
       UseCounts,
       SubTreeCost * UseCounts [GrossCost],
       SizeInBytes
FROM core
WHERE core.Statement NOT LIKE '%SoSSE%'
ORDER BY GrossCost DESC;
