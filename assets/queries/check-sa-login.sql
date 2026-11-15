-- Read metadata only. Identify the built-in sa by SID, even after renaming.
SELECT
    N'sa login' AS check_name,
    p.name AS login_name,
    p.is_disabled,
    CASE p.is_disabled
        WHEN 1 THEN N'無効'
        WHEN 0 THEN N'有効'
        ELSE N'不明'
    END AS login_state,
    CASE p.is_disabled
        WHEN 1 THEN N'正常'
        WHEN 0 THEN N'要確認'
        ELSE N'未判定'
    END AS result,
    CASE p.is_disabled
        WHEN 1 THEN N'組み込み sa ログインは無効です。'
        WHEN 0 THEN N'組み込み sa ログインは有効です。'
        ELSE N'sa の状態を取得できません。メタデータの可視性と対象を確認してください。'
    END AS evidence
FROM (SELECT 1 AS expected_row) AS expected
LEFT JOIN sys.server_principals AS p ON p.sid = 0x01 AND p.type = 'S';
