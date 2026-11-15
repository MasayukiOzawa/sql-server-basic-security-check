-- Check definition: references/clr-enabled.md
-- Read configuration only. Do not invoke the feature or change any setting.
-- Assess the effective value, not a potentially pending configured value.
;WITH configuration AS (
    SELECT
        CAST(value AS int) AS configured_value,
        CAST(value_in_use AS int) AS value_in_use
    FROM sys.configurations
    WHERE name = N'clr enabled'
)
SELECT
    N'clr enabled' AS check_name,
    c.configured_value,
    c.value_in_use,
    CASE c.value_in_use
        WHEN 0 THEN N'正常'
        WHEN 1 THEN N'要確認'
        ELSE N'未判定'
    END AS result,
    CASE c.value_in_use
        WHEN 0 THEN N'実効値が 0 のため、clr enabled は無効です。'
        WHEN 1 THEN N'実効値が 1 のため、clr enabled は有効です。'
        ELSE N'実効値を取得できないか、0 / 1 以外の値です。'
    END AS evidence,
    CASE
        WHEN c.configured_value <> c.value_in_use
            THEN N'設定値と実効値が異なります。設定変更は行っていません。'
        ELSE N''
    END AS notes
FROM (SELECT 1 AS expected_row) AS expected
LEFT JOIN configuration AS c ON 1 = 1;
