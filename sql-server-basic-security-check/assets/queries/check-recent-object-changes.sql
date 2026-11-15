-- Read metadata only; table variables hold results for this session.
SET NOCOUNT ON;
DECLARE @Until datetime2(7) = SYSDATETIME();
DECLARE @Since datetime2(7) = DATEADD(day, -7, @Until);
DECLARE @Databases TABLE (database_id int PRIMARY KEY, database_name sysname, state_desc nvarchar(60), result nvarchar(30), note nvarchar(4000), matched_count int);
DECLARE @Rows TABLE (database_name sysname, schema_name sysname, object_name sysname, type_desc nvarchar(60), create_date datetime, modify_date datetime);
INSERT @Databases (database_id, database_name, state_desc)
SELECT database_id, name, state_desc FROM sys.databases;
DECLARE @Id int, @Name sysname, @State nvarchar(60), @Sql nvarchar(max), @ViewDefinition int, @Count int;
WHILE EXISTS (SELECT 1 FROM @Databases WHERE result IS NULL)
BEGIN
    SELECT TOP (1) @Id = database_id, @Name = database_name, @State = state_desc
    FROM @Databases WHERE result IS NULL ORDER BY database_id;
    IF @State <> N'ONLINE' OR ISNULL(HAS_DBACCESS(@Name), 0) <> 1
        UPDATE @Databases SET result = N'未確認', note = N'オンラインでないか DB にアクセスできません。' WHERE database_id = @Id;
    ELSE
    BEGIN
        BEGIN TRY
            SET @ViewDefinition = NULL;
            SET @Sql = N'USE ' + QUOTENAME(@Name) + N';
                SET @Permission = HAS_PERMS_BY_NAME(DB_NAME(), ''DATABASE'', ''VIEW DEFINITION'');
                SELECT DB_NAME(), s.name, o.name, o.type_desc, o.create_date, o.modify_date
                FROM sys.objects AS o
                INNER JOIN sys.schemas AS s ON s.schema_id = o.schema_id
                WHERE o.is_ms_shipped = 0 AND o.modify_date >= @StartTime AND o.modify_date <= @EndTime
                  AND NOT (DB_NAME() = N''tempdb'' AND (
                      o.name LIKE N''#%''
                      OR EXISTS (SELECT 1 FROM sys.objects AS parent_object
                          WHERE parent_object.object_id = o.parent_object_id
                            AND parent_object.name LIKE N''#%'')));';
            INSERT @Rows
            EXEC sys.sp_executesql @Sql,
                N'@StartTime datetime2(7), @EndTime datetime2(7), @Permission int OUTPUT',
                @StartTime = @Since, @EndTime = @Until, @Permission = @ViewDefinition OUTPUT;
            SET @Count = @@ROWCOUNT;
            UPDATE @Databases
            SET matched_count = @Count,
                result = CASE WHEN ISNULL(@ViewDefinition, 0) <> 1 THEN N'未確認（部分取得）'
                              WHEN @Count > 0 THEN N'検出あり' ELSE N'検出なし（可視範囲）' END,
                note = CASE WHEN ISNULL(@ViewDefinition, 0) <> 1 THEN N'VIEW DEFINITION を確認できないため、非表示オブジェクトは未確認。'
                            ELSE N'参照可能なオブジェクトの結果。個別の DENY 等で非表示のオブジェクトは未確認。' END
            WHERE database_id = @Id;
        END TRY
        BEGIN CATCH
            DELETE FROM @Rows WHERE database_name = @Name;
            UPDATE @Databases SET result = N'未確認', matched_count = NULL,
                note = CONCAT(N'取得失敗 (', ERROR_NUMBER(), N'): ', ERROR_MESSAGE()) WHERE database_id = @Id;
        END CATCH;
    END;
END;
SELECT N'recent object changes' AS check_name, @Since AS period_start_server_local,
    @Until AS period_end_server_local, COUNT(*) AS visible_database_count,
    N'非表示 DB は未確認。変更の有無を正常／異常とは判定しない。' AS scope_note
FROM @Databases;
SELECT database_name, state_desc, matched_count, result, note FROM @Databases ORDER BY database_name;
SELECT database_name, schema_name, object_name, type_desc, create_date, modify_date
FROM @Rows ORDER BY database_name, modify_date DESC, schema_name, object_name;
