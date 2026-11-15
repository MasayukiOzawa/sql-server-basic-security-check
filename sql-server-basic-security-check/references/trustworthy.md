# TRUSTWORTHY が有効な DB の確認

- 対象: 接続先インスタンスの `sys.databases`。各 DB に接続せず `is_trustworthy_on` を取得する。
- SQL: [check-trustworthy.sql](../assets/queries/check-trustworthy.sql)。セッション内の表変数に読み取り結果を保持して集計する。永続データや設定は変更しない。
- 判定: msdb 以外で 1（ON）なら「要確認」。msdb（database_id = 4）で ON なら「情報」とし、「msdb は既定で TRUSTWORTHY が ON」と注記する。msdb は結果から除外しない。
- 出力: 参照できた DB 数、msdb 以外の有効 DB 数、msdb の有効件数、有効 DB の名前・設定値・判定・注記。NULL の設定値は未判定として列挙する。
- 参照できた DB が 0 件、または取得失敗の場合は未判定。参照できた DB 内で要確認対象がなければ「要確認対象なし」。サーバー全体の安全性を保証する表現は使わない。
- 権限: sys.databases のメタデータ参照が必要。VIEW ANY DATABASE 等による可視性に依存し、オフライン DB などが非表示になる場合もある。非表示の DB は未確認と報告し、権限の自動付与は行わない。
- 有効な理由や所有者の権限は今回の判定対象外。msdb を含め設定の ON / OFF は変更しない。
- 実行: [一括入口](../scripts/Invoke-SecurityChecks.ps1) の既定項目に含む。単独では `-Checks 'trustworthy'` を指定する。

msdb の既定値は [Microsoft Learn: TRUSTWORTHY](https://learn.microsoft.com/en-us/sql/relational-databases/security/trustworthy-database-property)、可視性は [sys.databases](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-databases-transact-sql) を参照する。
