-- Read current service metadata and current engine startup log independently.
SET NOCOUNT ON;
DECLARE @Services TABLE (servicename nvarchar(256), service_account nvarchar(256),
    status_desc nvarchar(256), startup_type_desc nvarchar(256), last_startup_time datetimeoffset(7));
DECLARE @ServiceError nvarchar(4000) = NULL;
BEGIN TRY
    INSERT @Services
    EXEC sys.sp_executesql N'SELECT servicename, service_account, status_desc,
        startup_type_desc, last_startup_time FROM sys.dm_server_services;';
END TRY
BEGIN CATCH
    SET @ServiceError = CONCAT(N'取得失敗 (', ERROR_NUMBER(), N'): ', ERROR_MESSAGE());
    DELETE FROM @Services;
END CATCH;
SELECT N'service accounts' AS check_name, N'DMV' AS source,
    CASE WHEN @ServiceError IS NULL THEN COUNT(*) END AS retrieved_service_count,
    CASE WHEN @ServiceError IS NOT NULL OR COUNT(*) = 0
              OR EXISTS (SELECT 1 FROM @Services WHERE NULLIF(LTRIM(RTRIM(service_account)), N'') IS NULL)
         THEN N'未判定' ELSE N'情報' END AS result,
    COALESCE(@ServiceError, N'アカウントの適否は判定しない。0行・アカウント未取得は未判定。') AS note
FROM @Services;
SELECT servicename, service_account, status_desc, startup_type_desc, last_startup_time,
    CASE WHEN NULLIF(LTRIM(RTRIM(service_account)), N'') IS NULL THEN N'未判定' ELSE N'情報' END AS result
FROM @Services ORDER BY servicename;

DECLARE @ServiceLog TABLE (LogDate datetime, ProcessInfo nvarchar(50), [Text] nvarchar(max));
DECLARE @ServiceLogError nvarchar(4000) = NULL;
BEGIN TRY
    INSERT @ServiceLog EXEC master.sys.sp_readerrorlog 0, 1, N'The service account is';
END TRY
BEGIN CATCH
    SET @ServiceLogError = CONCAT(N'取得失敗 (', ERROR_NUMBER(), N'): ', ERROR_MESSAGE());
    DELETE FROM @ServiceLog;
END CATCH;
SELECT N'service accounts' AS check_name, N'ERRORLOG (補助)' AS source, 0 AS log_number,
    CASE WHEN @ServiceLogError IS NULL THEN COUNT_BIG(*) END AS matched_count,
    CASE WHEN @ServiceLogError IS NOT NULL THEN N'未判定'
         WHEN COUNT_BIG(*) > 0 THEN N'検出あり' ELSE N'検出なし' END AS result,
    COALESCE(@ServiceLogError, N'現在の Database Engine ERRORLOG の英語メッセージのみ。起動時の情報であり、Agent のアカウントや現在の設定の証明には使わない。') AS note
FROM @ServiceLog;
SELECT LogDate AS log_date, ProcessInfo AS process_info, [Text] AS log_message
FROM @ServiceLog ORDER BY LogDate DESC, ProcessInfo, [Text];
