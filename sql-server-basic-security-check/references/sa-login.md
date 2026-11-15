# sa ログインの有効状態確認

| 記入欄 | 内容 |
| --- | --- |
| 項目名 | sa ログインの有効状態 |
| 目的 | 組み込み sa ログインが有効化されているか確認する |
| 対象 | SQL Server インスタンスの SID 0x01 の SQL ログイン。名前が変更されていても対象とする |
| 必要権限 | 接続と sys.server_principals 内の対象ログインを参照できる権限。システムログインは通常参照できるが、メタデータの可視性制限に注意する。対象行が見えなければ未判定とし、自動で権限を付与しない |
| 使用する SQL | [check-sa-login.sql](../assets/queries/check-sa-login.sql) |
| 判定基準 | is_disabled = 1（無効）なら正常、0（有効）なら要確認 |
| 取得できない場合の扱い | 行なし、NULL、想定外の値、権限・接続・SQL エラーは未判定。行なしを「sa が無効」と判断しない |

`sys.server_principals` の SID と種類を使い、名前による検索は行わない。
`is_disabled` は既存の設定チェックの `value_in_use` と逆で、1 が無効、0 が有効を表す。
現在のログイン名、is_disabled、有効／無効の状態、判定、根拠を報告する。改名されていた場合も取得した名前をそのまま記載する。

このチェックはログインの無効化フラグだけを判定する。認証モード、パスワード、ロック状態、接続権限等を検査せず、実際に sa で接続できることを意味しない。
パスワード・ハッシュを取得せず、sa でのログイン試行、有効化・無効化・改名などの変更は行わない。

[一括実行手順](query-execution.md) の既定項目に含める。単独の場合は `-Checks 'sa login'` を指定する。
未実行・プレビューのみでは未判定と報告する。

列の意味と可視性は [Microsoft Learn: sys.server_principals](https://learn.microsoft.com/sql/relational-databases/system-catalog-views/sys-server-principals-transact-sql) を参照する。
