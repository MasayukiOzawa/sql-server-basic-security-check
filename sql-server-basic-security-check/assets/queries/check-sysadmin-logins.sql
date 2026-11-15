-- Read catalog membership only; do not expand directory groups or change roles.
SET NOCOUNT ON;
DECLARE @SysadminId int = (SELECT principal_id FROM sys.server_principals WHERE name = N'sysadmin' AND type = 'R' AND is_fixed_role = 1);
DECLARE @CanViewMembership bit = CASE WHEN IS_SRVROLEMEMBER(N'sysadmin') = 1
    OR IS_SRVROLEMEMBER(N'securityadmin') = 1
    OR HAS_PERMS_BY_NAME(NULL, NULL, N'VIEW ANY DEFINITION') = 1 THEN 1 ELSE 0 END;
DECLARE @AdminMembers TABLE (principal_id int, parent_role_id int, depth int, id_path varchar(max));
;WITH Membership AS (
    SELECT m.member_principal_id AS principal_id, m.role_principal_id AS parent_role_id,
        1 AS depth,
        CAST('/' + CONVERT(varchar(11), @SysadminId) + '/' + CONVERT(varchar(11), m.member_principal_id) + '/' AS varchar(max)) AS id_path
    FROM sys.server_role_members AS m WHERE m.role_principal_id = @SysadminId
    UNION ALL
    SELECT m.member_principal_id, m.role_principal_id, t.depth + 1,
        CAST(t.id_path + CONVERT(varchar(11), m.member_principal_id) + '/' AS varchar(max))
    FROM Membership AS t
    INNER JOIN sys.server_role_members AS m ON m.role_principal_id = t.principal_id
    WHERE CHARINDEX('/' + CONVERT(varchar(11), m.member_principal_id) + '/', t.id_path) = 0
)
INSERT @AdminMembers SELECT principal_id, parent_role_id, depth, id_path FROM Membership
OPTION (MAXRECURSION 32767);

SELECT N'sysadmin logins' AS check_name, @CanViewMembership AS can_view_membership,
    COUNT(DISTINCT CASE WHEN p.type <> 'R' THEN m.principal_id END) AS visible_login_count,
    CASE WHEN @SysadminId IS NULL OR @CanViewMembership = 0
                   OR EXISTS (SELECT 1 FROM @AdminMembers AS a LEFT JOIN sys.server_principals AS b ON b.principal_id = a.principal_id WHERE b.principal_id IS NULL)
         THEN N'未判定（可視範囲のみ）' ELSE N'情報' END AS result,
    N'無効ログインも含む。非表示の所属・ログインと Windows/Entra グループ内のユーザーは未確認。CONTROL SERVER 等の個別権限は対象外。' AS scope_note
FROM @AdminMembers AS m
LEFT JOIN sys.server_principals AS p ON p.principal_id = m.principal_id;

SELECT m.principal_id, p.name AS login_or_role_name, p.type_desc, p.is_disabled,
    CASE WHEN p.type = 'R' THEN N'対象外（ロール）' WHEN p.is_disabled = 1 THEN N'無効' WHEN p.is_disabled = 0 THEN N'有効' ELSE N'不明' END AS login_state,
    parent.name AS granting_role, m.parent_role_id, m.depth, m.id_path AS membership_path_ids,
    CASE WHEN p.principal_id IS NULL THEN N'未判定：メンバーの詳細が非表示'
         WHEN p.type = 'R' THEN N'情報：経由するサーバーロール（ログインではない）'
         WHEN p.type IN ('G', 'X') THEN N'情報：グループ内の個々のユーザーは未確認'
         ELSE N'情報' END AS note
FROM @AdminMembers AS m
LEFT JOIN sys.server_principals AS p ON p.principal_id = m.principal_id
LEFT JOIN sys.server_principals AS parent ON parent.principal_id = m.parent_role_id
ORDER BY m.depth, p.name, m.id_path;
