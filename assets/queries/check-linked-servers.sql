-- Local catalog reads only. Never contact a linked server or read provider strings.
SET NOCOUNT ON;
DECLARE @LinkedServers TABLE (server_id int PRIMARY KEY, server_name sysname, product nvarchar(128),
    provider sysname NULL, data_source nvarchar(4000), catalog sysname NULL,
    is_data_access_enabled bit, is_remote_login_enabled bit, is_rpc_out_enabled bit,
    is_remote_proc_transaction_promotion_enabled bit, is_collation_compatible bit,
    uses_remote_collation bit, collation_name sysname NULL, lazy_schema_validation bit,
    connect_timeout int, query_timeout int, modify_date datetime);
DECLARE @LinkedMappings TABLE (server_id int, local_principal_id int, local_login_name sysname NULL,
    uses_self_credential bit, remote_name sysname NULL, modify_date datetime);
DECLARE @ServerError nvarchar(4000) = NULL, @MappingError nvarchar(4000) = NULL;
DECLARE @CanViewServers bit = CASE WHEN IS_SRVROLEMEMBER(N'sysadmin') = 1
    OR IS_SRVROLEMEMBER(N'setupadmin') = 1
    OR HAS_PERMS_BY_NAME(NULL, NULL, N'ALTER ANY LINKED SERVER') = 1
    OR HAS_PERMS_BY_NAME(NULL, NULL, N'ALTER ANY LOGIN') = 1 THEN 1 ELSE 0 END;
BEGIN TRY
    INSERT @LinkedServers
    EXEC sys.sp_executesql N'SELECT server_id, name, product, provider, data_source, catalog,
        is_data_access_enabled, is_remote_login_enabled, is_rpc_out_enabled,
        is_remote_proc_transaction_promotion_enabled, is_collation_compatible,
        uses_remote_collation, collation_name, lazy_schema_validation,
        connect_timeout, query_timeout, modify_date
        FROM sys.servers WHERE server_id <> 0 AND is_linked = 1;';
END TRY
BEGIN CATCH
    SET @ServerError = CONCAT(N'取得失敗 (', ERROR_NUMBER(), N'): ', ERROR_MESSAGE());
    DELETE FROM @LinkedServers;
END CATCH;
BEGIN TRY
    INSERT @LinkedMappings
    EXEC sys.sp_executesql N'SELECT m.server_id, m.local_principal_id, p.name,
        m.uses_self_credential, m.remote_name, m.modify_date
        FROM sys.linked_logins AS m
        INNER JOIN sys.servers AS s ON s.server_id = m.server_id
        LEFT JOIN sys.server_principals AS p ON p.principal_id = m.local_principal_id
        WHERE s.server_id <> 0 AND s.is_linked = 1;';
END TRY
BEGIN CATCH
    SET @MappingError = CONCAT(N'取得失敗 (', ERROR_NUMBER(), N'): ', ERROR_MESSAGE());
    DELETE FROM @LinkedMappings;
END CATCH;
SELECT N'linked servers' AS check_name, @CanViewServers AS can_view_all_servers,
    CASE WHEN @ServerError IS NULL THEN (SELECT COUNT(*) FROM @LinkedServers) END AS visible_server_count,
    CASE WHEN @MappingError IS NULL THEN (SELECT COUNT(*) FROM @LinkedMappings) END AS visible_mapping_count,
    CASE WHEN @ServerError IS NOT NULL OR @MappingError IS NOT NULL OR @CanViewServers = 0
              OR EXISTS (SELECT 1 FROM @LinkedMappings WHERE local_principal_id <> 0 AND local_login_name IS NULL)
         THEN N'未判定（取得範囲を参照）' ELSE N'情報' END AS result,
    @ServerError AS server_error, @MappingError AS mapping_error,
    N'設定の適否・接続可否は未判定。マッピングの可視性は別途制限され得る。非表示の行は未確認。' AS scope_note;
SELECT * FROM @LinkedServers ORDER BY server_name;
SELECT m.server_id, s.server_name, m.local_principal_id,
    CASE WHEN m.local_principal_id = 0 THEN N'既定マッピング（個別指定のないローカルログイン）'
         WHEN m.local_login_name IS NULL THEN N'未取得（非表示または変更済み）'
         ELSE m.local_login_name END AS local_login,
    m.uses_self_credential, m.remote_name, m.modify_date,
    CASE WHEN m.uses_self_credential = 1 THEN N'自身のセキュリティコンテキスト'
         WHEN m.uses_self_credential = 0 AND m.remote_name IS NULL THEN N'セキュリティコンテキストなし（接続可否は未確認）'
         WHEN m.uses_self_credential = 0 THEN N'指定されたリモートログイン'
         ELSE N'未判定' END AS mapping_mode
FROM @LinkedMappings AS m
LEFT JOIN @LinkedServers AS s ON s.server_id = m.server_id
ORDER BY m.server_id, m.local_principal_id;
