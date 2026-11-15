-- Inspect definitions and running state only. Do not read target data or change XE.
SET NOCOUNT ON;
BEGIN TRY
    EXEC sys.sp_executesql N'
    SET QUOTED_IDENTIFIER ON;
    DECLARE @HasDacField bit = CASE WHEN EXISTS (
        SELECT 1 FROM sys.dm_xe_object_columns AS c
        INNER JOIN sys.dm_xe_packages AS p ON p.guid = c.object_package_guid
        WHERE p.name = N''sqlserver'' AND c.object_name = N''login''
          AND c.name = N''is_dac'' AND c.column_type = N''data''
    ) THEN 1 ELSE 0 END;
    DECLARE @Tracking TABLE (session_name sysname, event_id int, event_name sysname,
        predicate nvarchar(3000), normalized_predicate nvarchar(3000),
        is_running bit, startup_state bit, targets nvarchar(max), result nvarchar(100));
    INSERT @Tracking (session_name, event_id, event_name, predicate, normalized_predicate, is_running, startup_state, targets)
    SELECT s.name, e.event_id, e.name, e.predicate,
        LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            COALESCE(e.predicate, N''''), N'' '', N''''), N''['', N''''), N'']'', N''''),
            N''('', N''''), N'')'', N''''), CHAR(9), N''''), CHAR(10), N''''), CHAR(13), N'''')),
        CASE WHEN r.address IS NULL THEN 0 ELSE 1 END, s.startup_state,
        STUFF((SELECT N'', '' + t.package + N''.'' + t.name
               FROM sys.server_event_session_targets AS t
               WHERE t.event_session_id = s.event_session_id
               ORDER BY t.package, t.name FOR XML PATH(''''), TYPE).value(''.'', ''nvarchar(max)''), 1, 2, N'''')
    FROM sys.server_event_sessions AS s
    INNER JOIN sys.server_event_session_events AS e ON e.event_session_id = s.event_session_id
    LEFT JOIN sys.dm_xe_sessions AS r ON r.name = s.name
    WHERE e.package = N''sqlserver'' AND e.name = N''login'';

    UPDATE @Tracking SET result = CASE
        WHEN @HasDacField = 0 THEN N''未判定：is_dac データ列を確認できない''
        WHEN normalized_predicate IN (N''is_dac=0'', N''0=is_dac'') THEN N''対象外：DAC を除外''
        WHEN normalized_predicate NOT IN (N'''', N''is_dac=1'', N''1=is_dac'') THEN N''未判定：フィルターの確認が必要''
        WHEN is_running = 0 THEN N''定義あり・停止中''
        WHEN targets IS NULL THEN N''定義あり・記録先なし''
        ELSE N''追跡設定あり・稼働中'' END;
    SELECT N''DAC XE tracking'' AS check_name, @HasDacField AS login_has_is_dac,
        COUNT(*) AS login_event_count,
        COUNT(CASE WHEN result = N''追跡設定あり・稼働中'' THEN 1 END) AS running_tracking_count,
        CASE WHEN @HasDacField = 0 THEN N''未判定''
             WHEN EXISTS (SELECT 1 FROM @Tracking WHERE result = N''追跡設定あり・稼働中'') THEN N''追跡設定あり・稼働中''
             WHEN EXISTS (SELECT 1 FROM @Tracking WHERE result LIKE N''未判定%'') THEN N''未判定''
             WHEN EXISTS (SELECT 1 FROM @Tracking WHERE result LIKE N''定義あり%'') THEN N''定義あり・稼働中の追跡設定なし''
             ELSE N''対象の追跡設定なし'' END AS result,
        N''sqlserver.login の定義を確認。記録の成功・保持期間は未確認。複雑な条件や別イベントによる追跡は断定しない。'' AS scope_note
    FROM @Tracking;
    SELECT session_name, event_id, event_name, predicate, is_running, startup_state, targets, result
    FROM @Tracking ORDER BY session_name, event_id;';
END TRY
BEGIN CATCH
    SELECT N'DAC XE tracking' AS check_name, N'未判定' AS result,
        ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS reason;
END CATCH;
