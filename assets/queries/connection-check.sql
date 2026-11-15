-- Read-only connection context check. No application tables are accessed.
SET NOCOUNT ON;

SELECT
    CONVERT(nvarchar(128), SERVERPROPERTY('ServerName')) AS server_name,
    CONVERT(nvarchar(128), SERVERPROPERTY('ProductVersion')) AS product_version,
    DB_NAME() AS database_name,
    ORIGINAL_LOGIN() AS original_login,
    SUSER_SNAME() AS execution_login,
    SYSUTCDATETIME() AS checked_at_utc;
