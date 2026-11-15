-- Read job metadata only. Never start, stop or modify jobs.
SET NOCOUNT ON;
DECLARE @JobUntil datetime2(7) = SYSDATETIME();
DECLARE @JobSince datetime2(7) = DATEADD(day, -7, @JobUntil);
DECLARE @Jobs TABLE (
    job_id uniqueidentifier, job_name sysname, enabled tinyint,
    date_created datetime, date_modified datetime
);
DECLARE @JobError nvarchar(4000) = NULL;
BEGIN TRY
    -- Lower execution scope lets TRY/CATCH handle unavailable msdb/sysjobs too.
    INSERT @Jobs
    EXEC sys.sp_executesql N'
        SELECT job_id, name, enabled, date_created, date_modified
        FROM msdb.dbo.sysjobs;';
END TRY
BEGIN CATCH
    SET @JobError = CONCAT(N'取得失敗 (', ERROR_NUMBER(), N'): ', ERROR_MESSAGE());
    DELETE FROM @Jobs;
END CATCH;

SELECT N'recent agent job changes' AS check_name,
    @JobSince AS period_start_server_local, @JobUntil AS period_end_server_local,
    CASE WHEN @JobError IS NULL THEN (SELECT COUNT_BIG(*) FROM @Jobs) END AS retrieved_job_count,
    CASE WHEN @JobError IS NULL THEN
        (SELECT COUNT_BIG(*) FROM @Jobs WHERE date_modified >= @JobSince AND date_modified <= @JobUntil)
    END AS matched_count,
    CASE WHEN @JobError IS NOT NULL OR EXISTS (SELECT 1 FROM @Jobs WHERE date_modified IS NULL) THEN N'未判定'
         WHEN EXISTS (SELECT 1 FROM @Jobs WHERE date_modified >= @JobSince AND date_modified <= @JobUntil) THEN N'検出あり'
         ELSE N'検出なし' END AS result,
    COALESCE(@JobError, N'msdb.dbo.sysjobs の最終変更日時を参照。NULL の日時は未判定。変更の有無を正常／異常とは判定しない。') AS note;

SELECT job_id, job_name, enabled, date_created, date_modified,
    CASE WHEN date_modified IS NULL THEN N'未判定' ELSE N'検出あり' END AS result
FROM @Jobs
WHERE (date_modified >= @JobSince AND date_modified <= @JobUntil) OR date_modified IS NULL
ORDER BY date_modified DESC, job_name, job_id;
