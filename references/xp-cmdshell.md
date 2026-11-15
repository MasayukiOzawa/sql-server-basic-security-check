# xp_cmdshell の無効化確認

## チェック定義

| 記入欄 | 内容 |
| --- | --- |
| 項目名 | xp_cmdshell の無効化 |
| 目的 | 現在の SQL Server インスタンスで xp_cmdshell が無効になっていることを確認する |
| 対象 | 接続先 SQL Server のインスタンス全体。データベース単位の設定ではない |
| 必要権限 | 接続先へのアクセスと `sys.configurations` の参照権限。SQL Server 2019 以前は public ロール、2022 以降はサーバーの `VIEW SERVER PERFORMANCE STATE` 権限が必要 |
| 使用する SQL | [check-xp-cmdshell.sql](../assets/queries/check-xp-cmdshell.sql) |
| 判定基準 | `value_in_use = 0` は「正常」、`value_in_use = 1` は「要確認」 |
| 取得できない場合の扱い | 行を取得できない場合、実効値が NULL または 0 / 1 以外の場合、権限不足・接続失敗・SQL エラーの場合は「未判定」として理由を報告する |

## 取得と判定

`sys.configurations` の `name = N'xp_cmdshell'` の行を読む。
現在有効な設定を示す `value_in_use` を判定に使い、設定値 `value` は `configured_value` として補足する。
両者が異なる場合は判定を実効値に基づいて行い、不一致を必ず補足する。反映操作は行わない。

SQL は `check_name`、`configured_value`、`value_in_use`、`result`、`evidence`、`notes` を返す。
対象行がなくても、LEFT JOIN により実効値 NULL・判定「未判定」の行を返す。
権限不足等でクエリ自体が失敗した場合は結果を作らず、実行エラーの内容を根拠に未判定と報告する。

設定変更用のプロシージャや再構成処理は呼び出さない。`xp_cmdshell` 自体も実行しない。
有効だった場合も「要確認」と報告するだけで、無効化処理や権限付与は行わない。

取得列の意味とバージョン別の必要権限は [Microsoft Learn: sys.configurations](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-configurations-transact-sql) に従う。

## 実行と報告

[クエリ実行手順](query-execution.md) に従い、`QueryFile` に `./assets/queries/check-xp-cmdshell.sql` を指定する。
実行スクリプトや接続設定は既存のものを利用する。

[結果報告のひな形](check-template.md#結果報告のひな形) の項目欄に「xp_cmdshell の無効化」、取得値欄に `value_in_use` と `configured_value`、判定欄に `result`、根拠欄に `evidence` を記載する。
`notes` に不一致が出た場合はその内容も記載し、取得できなかった情報があれば未確認事項に理由を記録する。
チェック対象、実行状況とともに「設定変更なし」を報告する。プレビューだけの場合は判定せず「未実行・未判定」とする。
