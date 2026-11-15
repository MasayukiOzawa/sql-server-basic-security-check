-- Current ERRORLOG only. No certificate-store access, TLS test or log rotation.
SET NOCOUNT ON;
DECLARE @CertificateLog TABLE (LogDate datetime, ProcessInfo nvarchar(50), [Text] nvarchar(max), category nvarchar(100));
DECLARE @CertificateLogError nvarchar(4000) = NULL;
BEGIN TRY
    INSERT @CertificateLog (LogDate, ProcessInfo, [Text])
    EXEC master.sys.sp_readerrorlog 0, 1, N'certificate';
END TRY
BEGIN CATCH
    SET @CertificateLogError = CONCAT(N'取得失敗 (', ERROR_NUMBER(), N'): ', ERROR_MESSAGE());
    DELETE FROM @CertificateLog;
END CATCH;
UPDATE @CertificateLog SET category = CASE
    WHEN [Text] LIKE N'%self-generated certificate%successfully loaded for encryption%'
        THEN N'自動生成証明書の読み込み成功'
    WHEN [Text] LIKE N'%The certificate%successfully loaded for encryption%'
        THEN N'証明書の読み込み成功'
    WHEN [Text] LIKE N'%Unable to load user-specified certificate%'
        OR [Text] LIKE N'%could not load the certificate%SSL%'
        OR [Text] LIKE N'%Unable to initialize SSL encryption%certificate%'
        THEN N'証明書の読み込み・暗号化初期化失敗'
    ELSE N'その他の証明書関連ログ（内容確認）' END;
SELECT N'encryption certificate log' AS check_name, 0 AS log_number,
    CASE WHEN @CertificateLogError IS NULL THEN COUNT_BIG(*) END AS matched_count,
    CASE WHEN @CertificateLogError IS NOT NULL THEN N'未判定'
         WHEN COUNT_BIG(*) = 0 THEN N'未判定（該当ログなし）'
         ELSE N'情報（検出ログ参照）' END AS result,
    COALESCE(@CertificateLogError,
        N'現在の ERRORLOG 内の英語 certificate メッセージ。証明書の現在の有効性・信頼性・全接続の暗号化は未判定。') AS note
FROM @CertificateLog;
SELECT category, COUNT_BIG(*) AS matched_count FROM @CertificateLog GROUP BY category ORDER BY category;
SELECT LogDate AS log_date, ProcessInfo AS process_info, category, [Text] AS log_message
FROM @CertificateLog ORDER BY LogDate DESC, ProcessInfo, [Text];
