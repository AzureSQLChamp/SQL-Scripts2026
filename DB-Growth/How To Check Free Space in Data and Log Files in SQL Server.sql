-- Drop the temporary table if it exists
IF OBJECT_ID('tempdb..#DatabaseReport') IS NOT NULL
    DROP TABLE #DatabaseReport;

-- Create a temporary table to store the report results
CREATE TABLE #DatabaseReport
(
    [Database] NVARCHAR(128),
    [File Type] NVARCHAR(60),
    [File Name] NVARCHAR(128),
    [Filegroup] NVARCHAR(128),
    [File Location] NVARCHAR(260),
    [Total Size (MB)] DECIMAL(10, 2),
    [Used Space (MB)] DECIMAL(10, 2),
    [Free Space (MB)] DECIMAL(10, 2),
    [Free Space (%) ] DECIMAL(10, 2),
    [Autogrowth] NVARCHAR(400)
);

-- Cursor to iterate over databases
DECLARE @DatabaseName NVARCHAR(128);

DECLARE DatabaseCursor CURSOR FOR
    SELECT [name]
    FROM sys.databases
    WHERE [state] = 0 -- Exclude offline databases

OPEN DatabaseCursor;
FETCH NEXT FROM DatabaseCursor INTO @DatabaseName;

-- Loop through each database and execute the query dynamically
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @SqlQuery NVARCHAR(MAX);

    -- Generate the query to retrieve file information for each database
    SET @SqlQuery = 'USE [' + @DatabaseName + ']; ' +
        'INSERT INTO #DatabaseReport ' +
        '(' +
            '[Database], ' +
            '[File Type], ' +
            '[File Name], ' +
            '[Filegroup], ' +
            '[File Location], ' +
            '[Total Size (MB)], ' +
            '[Used Space (MB)], ' +
            '[Free Space (MB)], ' +
            '[Free Space (%)], ' +
            '[Autogrowth]' +
        ')' +
        'SELECT ' +
            '''' + @DatabaseName + ''', ' +
            'A.TYPE_DESC AS [File Type], ' +
            'fg.name AS [Filegroup], ' +
            'A.NAME AS [File Name], ' +
            'A.PHYSICAL_NAME AS [File Location], ' +
            'CONVERT(DECIMAL(10, 2), A.SIZE / 128.0) AS [Total Size (MB)], ' +
            'CONVERT(DECIMAL(10, 2), A.SIZE / 128.0 - CAST(FILEPROPERTY(A.NAME, ''SPACEUSED'') AS INT) / 128.0) AS [Used Space (MB)], ' +
            'CONVERT(DECIMAL(10, 2), A.SIZE / 128.0 - CAST(FILEPROPERTY(A.NAME, ''SPACEUSED'') AS INT) / 128.0) AS [Free Space (MB)], ' +
            'CONVERT(DECIMAL(10, 2), ((A.SIZE / 128.0 - CAST(FILEPROPERTY(A.NAME, ''SPACEUSED'') AS INT) / 128.0) / (A.SIZE / 128.0)) * 100) AS [Free Space (%)], ' +
            '''By '' + ' +
            'CASE ' +
                'WHEN is_percent_growth = 0 THEN CAST(growth / 128 AS VARCHAR(10)) + '' MB -'' ' +
                'WHEN is_percent_growth = 1 THEN CAST(growth AS VARCHAR(10)) + ''% -'' ' +
                'ELSE '''' ' +
            'END + ' +
            'CASE ' +
                'WHEN max_size = 0 THEN ''DISABLED'' ' +
                'WHEN max_size = -1 THEN '' Unrestricted'' ' +
                'ELSE '' Restricted to '' + CAST(max_size / (128 * 1024) AS VARCHAR(10)) + '' GB'' ' +
            'END + ' +
            'CASE ' +
                'WHEN is_percent_growth = 1 THEN '' [Autogrowth by percent, BAD setting!]'' ' +
                'ELSE '''' ' +
            'END AS [Autogrowth] ' +
        'FROM sys.database_files A ' +
        'LEFT JOIN sys.filegroups fg ON A.data_space_id = fg.data_space_id ' +
        'ORDER BY A.TYPE DESC, A.NAME;';

    -- Execute the dynamically generated query
    EXEC sp_executesql @SqlQuery;

    FETCH NEXT FROM DatabaseCursor INTO @DatabaseName;
END;

CLOSE DatabaseCursor;
DEALLOCATE DatabaseCursor;

-- Select the report results from the temporary table
SELECT
    [Database],
    [File Type],
    [File Name],
    [Filegroup],
    [File Location],
    [Total Size (MB)],
    [Used Space (MB)],
    [Free Space (MB)],
    [Free Space (%)],
    [Autogrowth]
FROM #DatabaseReport
ORDER BY [Database], [File Type], [File Name];

-- Drop the temporary table
DROP TABLE #DatabaseReport;
