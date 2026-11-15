# サービスアカウントの確認

- 目的: SQL Server 関連サービスのアカウントと稼働情報を確認する。アカウント名や起動方式、停止状態から正常／異常を独自判定しない。
- 対象: 接続先インスタンスの `sys.dm_server_services` が返す全サービス（Database Engine、SQL Server Agent 等）。ホスト上の全 Windows サービスの一覧ではない。
- SQL: [check-service-accounts.sql](../assets/queries/check-service-accounts.sql)。選択名は `service accounts`。一括入口の既定項目に含み、同一接続で実行する。
- 主な取得値: サービス名、service_account、status_desc、startup_type_desc、last_startup_time。全行をレポートに記載する。起動日時のオフセットを保持し、NULL の日時は未取得とする。
- 判定: DMV の参照に成功してアカウントを取得できた行は「情報」。0 行、アカウントが NULL／空白、権限不足、SQL エラーは「未判定」。一部の行が未取得なら取得できた行も表示し、全体の未確認事項に記載する。
- 必要権限: DMV は SQL Server 2019 以前で VIEW SERVER STATE、2022 以降で VIEW SERVER SECURITY STATE。ERRORLOG は実行環境で sp_readerrorlog を呼び出すための権限が必要。バージョン番号で実行を禁止せず、実際の取得可否を確認する。権限は自動付与しない。

## ERRORLOG による補助確認

現在の Database Engine ERRORLOG を `sp_readerrorlog 0, 1, N'The service account is'` で検索する。検出した全ログ行の日時・プロセス・本文全文をコードブロックで出力する。主結果と別に「検出あり／検出なし／未判定」と報告する。

ログは起動時の過去情報であり、SQL Server Agent のサービスアカウントを示すものではない。ログの切り替え、保存期間、メッセージ言語などにより0件でもアカウント未設定とは判断しない。過去ログや Agent ログは自動で追加検索しない。必要な場合はユーザーの指示した範囲で別途確認する。

DMV と ERRORLOG の取得は独立して扱う。一方の権限不足で他方の成功を取り消さず、ERRORLOG だけ取得できても現在のアカウントを確認済みとしない。差異があれば両方の取得値・日時を記載し、原因や現在値を推測しない。

## 結果報告のひな形

- 実行状況／接続先／実行日時:
- DMV の取得サービス数／判定／未確認理由:
DMV の全サービスを次の列見出し付き表で掲載する。

| サービス名 | アカウント | 稼働状態 | 起動方式 | 最終起動日時 | 判定 |
| --- | --- | --- | --- | --- | --- |

- 補助ログ: 検出件数・判定と全行（日時・プロセス・本文全文）。
- 未確認事項: 未取得値、過去ログ、Agent ログ、アカウントの権限や適否。
- 変更: なし。サービスの開始・停止・再起動、アカウント・パスワード・権限の変更、ログのローテーションは行わない。パスワードや資格情報は取得しない。

参考: [sys.dm_server_services](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-server-services-transact-sql)、[sp_readerrorlog](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-readerrorlog-transact-sql)。

## 表形式での出力必須

DMV の結果は Markdown／HTML の表で全行出力する。プレーンテキストやコードブロックだけで代用しない。最終起動日時のオフセットを保持し、NULL は未取得と明示する。0行でも列見出しと未判定理由を示し、取得失敗を0件と扱わない。保存後に全6列・行数・取得値を元結果と照合する。補助 ERRORLOG は主結果と分け、従来どおり日時・プロセス・本文全文をコードブロック（HTML では pre）で全行掲載する。

サービス名やアカウントに含まれる空白を列区切りと誤認しない。SQL の6列と照合し、サービス名全体（インスタンス名を含む）とアカウントを個別に確認する。原文への再結合一致だけでは列分けの検証としない。
