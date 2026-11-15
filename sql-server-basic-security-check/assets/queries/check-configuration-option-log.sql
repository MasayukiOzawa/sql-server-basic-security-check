-- Read current SQL Server error log only; no configuration or log rotation.
-- The table variable stores this session's read results, not persistent data.
SET NOCOUNT ON;
DECLARE @ConfigurationLog TABLE (
    LogDate datetime,
    ProcessInfo nvarchar(50),
    [Text] nvarchar(max)
);

BEGIN TRY
    INSERT INTO @ConfigurationLog (LogDate, ProcessInfo, [Text])
    EXEC master.sys.sp_readerrorlog 0, 1, N'Configuration option';
END TRY
BEGIN CATCH
    -- Do not report an empty result as "not detected" after a read failure.
    THROW;
END CATCH;

SELECT
    N'Configuration option log' AS check_name,
    0 AS log_number,
    COUNT_BIG(*) AS matched_count,
    CASE WHEN COUNT_BIG(*) > 0 THEN N'検出あり' ELSE N'検出なし' END AS result,
    MIN(LogDate) AS first_matched_at,
    MAX(LogDate) AS last_matched_at,
    N'現在の SQL Server エラーログのみ。過去ログは未確認。' AS scope
FROM @ConfigurationLog;

-- Return every matching log row with its complete message.
SELECT
    LogDate AS log_date,
    ProcessInfo AS process_info,
    [Text] AS log_message
FROM @ConfigurationLog
ORDER BY LogDate DESC, ProcessInfo, [Text];
