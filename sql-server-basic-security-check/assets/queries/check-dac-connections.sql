-- Observe existing connections through the ordinary connection. Never open a DAC.
SET NOCOUNT ON;
BEGIN TRY
    EXEC sys.sp_executesql N'
    DECLARE @Endpoints TABLE (endpoint_id int PRIMARY KEY, endpoint_name sysname);
    INSERT @Endpoints SELECT endpoint_id, name FROM sys.endpoints WHERE is_admin_endpoint = 1;
    DECLARE @Connections TABLE (connection_id uniqueidentifier, session_id int, endpoint_id int,
        connect_time datetime, client_net_address varchar(48), login_name nvarchar(128),
        host_name nvarchar(128), program_name nvarchar(128));
    INSERT @Connections
    SELECT c.connection_id, c.session_id, c.endpoint_id, c.connect_time, c.client_net_address,
        s.login_name, s.host_name, s.program_name
    FROM sys.dm_exec_connections AS c
    INNER JOIN @Endpoints AS e ON e.endpoint_id = c.endpoint_id
    LEFT JOIN sys.dm_exec_sessions AS s ON s.session_id = c.session_id;
    SELECT N''DAC connections'' AS check_name, SYSDATETIME() AS observed_at_server_local,
        (SELECT COUNT(*) FROM @Endpoints) AS visible_admin_endpoint_count,
        (SELECT COUNT(*) FROM @Connections) AS connection_count,
        CASE WHEN NOT EXISTS (SELECT 1 FROM @Endpoints) THEN N''未判定''
             WHEN EXISTS (SELECT 1 FROM @Connections) THEN N''検出あり'' ELSE N''検出なし'' END AS result,
        N''観測時点のみ。管理用エンドポイントが非表示の場合は未判定。過去の DAC 接続履歴は対象外。'' AS note;
    SELECT c.*, e.endpoint_name FROM @Connections AS c
    INNER JOIN @Endpoints AS e ON e.endpoint_id = c.endpoint_id ORDER BY c.session_id, c.connection_id;';
END TRY
BEGIN CATCH
    SELECT N'DAC connections' AS check_name, N'未判定' AS result,
        ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS reason;
END CATCH;
