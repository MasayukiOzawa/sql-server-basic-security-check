-- Read database metadata only. No database settings are changed.
SET NOCOUNT ON;
DECLARE @TrustworthyDatabases TABLE (database_id int, database_name sysname, is_trustworthy_on bit);
INSERT INTO @TrustworthyDatabases
SELECT database_id, name, is_trustworthy_on FROM sys.databases;

SELECT
    N'TRUSTWORTHY' AS check_name,
    COUNT_BIG(*) AS visible_database_count,
    COUNT(CASE WHEN is_trustworthy_on = 1 AND database_id <> 4 THEN 1 END) AS review_count,
    COUNT(CASE WHEN is_trustworthy_on = 1 AND database_id = 4 THEN 1 END) AS msdb_information_count,
    CASE
        WHEN COUNT_BIG(*) = 0 OR COUNT(CASE WHEN is_trustworthy_on IS NULL THEN 1 END) > 0 THEN N'未判定'
        WHEN COUNT(CASE WHEN is_trustworthy_on = 1 AND database_id <> 4 THEN 1 END) > 0 THEN N'要確認'
        ELSE N'要確認対象なし'
    END AS result,
    N'参照できた DB のみ。権限等で非表示の DB は未確認。' AS scope
FROM @TrustworthyDatabases;

SELECT database_name, is_trustworthy_on,
    CASE WHEN is_trustworthy_on IS NULL THEN N'未判定'
         WHEN database_id = 4 THEN N'情報'
         ELSE N'要確認' END AS result,
    CASE WHEN is_trustworthy_on IS NULL THEN N'設定値を取得できません。'
         WHEN database_id = 4 THEN N'msdb の TRUSTWORTHY は既定で ON です。既定の設定として情報を記載しています。'
         ELSE N'TRUSTWORTHY が有効です。利用目的を確認してください。' END AS note
FROM @TrustworthyDatabases
WHERE is_trustworthy_on = 1 OR is_trustworthy_on IS NULL
ORDER BY database_name;
