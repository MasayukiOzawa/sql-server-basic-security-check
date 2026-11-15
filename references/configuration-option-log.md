# Configuration option ログの確認

| 記入欄 | 内容 |
| --- | --- |
| 項目名 | Configuration option ログの有無・内容の確認 |
| 目的 | エラーログに指定の文字列を含む記録があるか確認し、検出されたログの内容を出力する |
| 対象 | 現在の SQL Server エラーログ（番号 0、種類 1）の全期間。アーカイブログと SQL Server Agent ログは対象外 |
| 必要権限 | SQL Server 2019 以前は VIEW SERVER STATE または securityadmin。2022 以降は VIEW ANY ERROR LOG、VIEW SERVER STATE、securityadmin のいずれか。権限の自動付与は行わない |
| 使用する SQL | [check-configuration-option-log.sql](../assets/queries/check-configuration-option-log.sql) |
| 判定基準 | 読み取り成功かつ一致件数が 1 件以上なら「検出あり」、0 件なら「検出なし」 |
| 必須の出力 | 判定・一致件数・対象範囲に加え、検出時は全ログ行の日時・プロセス・本文全文をコードブロックで出力する。「検出あり」と件数だけで報告を終えない。0 件の場合は「検出なし（0 件）」と記載する |
| 取得できない場合の扱い | 接続・権限・読み取りエラー、タイムアウト、サマリーが返らない場合は「未判定」。失敗を検出なしとしない |

`master.sys.sp_readerrorlog 0, 1, N'Configuration option'` を実行する。
結果をセッション内の表変数に受け取り集計する。永続テーブル、サーバー設定、ログを変更せず、ログのローテーションも行わない。
例外は再送出し、読み取りに失敗した場合は集計結果を返さない。

第1結果セットには対象ログ番号、一致件数、判定、最古・最新の一致日時、対象範囲を返す。
第2結果セットは一致した全件の日時（log_date）・プロセス（process_info）・本文全文（log_message）を新しい順に返す。件数上限や本文の切り詰めは行わない。
件数は全一致件数。ログ日時はサーバーの記録値として扱い、タイムゾーンを推測しない。

これは文字列の存在確認であり、正常／異常や現在の設定値を判定しない。検出ありでも不正な変更と断定しない。
検出なしは対象ログ内の当該文字列がないことだけを意味する。過去に変更がなかったこと、監査が十分なこと、別言語の記録がないことは保証しない。
ログの保存・切り替えにより過去の記録は別ファイルになるため、アーカイブログは未確認と明記する。

実行は [共通手順](query-execution.md) に従い、QueryFile に `./assets/queries/check-configuration-option-log.sql` を指定する。
[報告ひな形](check-template.md#結果報告のひな形) には判定、一致件数、対象範囲、最古・最新日時、検出された全ログ行を記載する。各行は日時・プロセス・本文を含むコードブロックで出力し、要約だけで置き換えない。秘密情報が含まれる場合は該当部分のみ伏せ、マスクした旨を明記する。大量で回答に収まらない場合は分割し、無断で省略しない。
未実行・プレビューのみの場合は未判定とする。

仕様と必要権限は [Microsoft Learn: sys.sp_readerrorlog](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-readerrorlog-transact-sql) を参照する。
