# DAC 接続と拡張イベントによる追跡の確認

通常の接続で次の2項目を読み取る。DAC 接続を新たに開かず、sqlcmd の `-A` や `admin:` への切り替えも行わない。

## 現在の DAC 接続

- SQL: [check-dac-connections.sql](../assets/queries/check-dac-connections.sql)。選択名は `DAC connections`。
- 対象: `sys.endpoints.is_admin_endpoint = 1` の endpoint_id に対応する `sys.dm_exec_connections`。セッション情報は `sys.dm_exec_sessions` から補う。固定のポート番号や endpoint_id、セッション名を決め打ちしない。
- 判定: 観測時点で1接続以上なら「検出あり」、参照成功かつ管理用エンドポイントが見えていて0件なら「検出なし」。エンドポイントが見えない、権限不足、SQL エラーは「未判定」。正常／異常とは判定しない。
- 出力: 観測時刻（サーバーローカル）、エンドポイント数・接続数、全接続の connection_id・session_id・endpoint_id・エンドポイント名・接続開始日時・クライアントアドレス・ログイン名・ホスト名・プログラム名。終了との競合で情報が欠けた場合は未取得とする。
- 限界: 現在の接続の観測であり、過去の接続履歴や接続試行・失敗は分からない。ホスト名やプログラム名はクライアントから申告された値。

## DAC 接続を追跡する拡張イベント

- SQL: [check-dac-xe-tracking.sql](../assets/queries/check-dac-xe-tracking.sql)。選択名は `DAC XE tracking`。
- 対象: サーバースコープの拡張イベント定義と稼働状態。セッション名に DAC が含まれるだけでは検出としない。実機の XE メタデータで `sqlserver.login` に `is_dac` データ列があることを確認する。確認不能なら未判定。
- 判定条件: `sqlserver.login` でフィルターなし（DAC を含む全ログイン）、または単純な `is_dac = 1`／`1 = is_dac` の条件があり、セッションが稼働中でターゲットが定義されていれば「追跡設定あり・稼働中」。SQL は角括弧・空白・括弧を正規化し、これらの単純式だけを認識する。
- `is_dac = 0`／`0 = is_dac` は「対象外：DAC を除外」。AND・OR・NOT、ログイン名やアプリ名の条件、関数表記など、それ以外の述語は原文を出力し「未判定：フィルターの確認が必要」。部分一致によって監視ありとしない。
- 停止中は「定義あり・停止中」、ターゲットがなければ「定義あり・記録先なし」。認識できる稼働中の追跡設定がない場合は、その状況と未判定条件を報告する。login イベントがない／DAC 除外のみの場合は「対象の追跡設定なし」。別イベントによる独自の追跡まで存在しないと断定しない。
- 出力: 集計と候補の全行。セッション名、イベント名、述語全文、稼働状態、startup_state、全ターゲット名、判定根拠。startup_state は自動開始設定であり現在の稼働状態とは区別する。稼働中の候補があっても他の候補の未判定事項は省略しない。
- 限界: 監視設定の確認であり、実際に DAC 接続が記録されたこと・ターゲットの健全性・永続保存・保持期間・イベント欠落なしを保証しない。ring_buffer は永続記録ではない。イベントファイルやターゲットデータの読取、テスト用 DAC 接続は行わない。

## 必要権限・失敗・報告

DMV と XE カタログ参照に必要な VIEW SERVER STATE、または環境によって VIEW SERVER PERFORMANCE STATE 等が必要。エンドポイントの可視性には VIEW SERVER SECURITY STATE 等も関係する。バージョン番号で実行を禁止せず、実際の参照結果で判定し、不足時は未判定と理由を示す。権限の自動付与はしない。

各項目の SQL エラーは個別に未判定として出力する。接続失敗や全体のタイムアウトでは未取得項目を未判定とする。2項目とも一括入口の既定項目に含め、同一接続で実行する。

レポートには2項目の実行状況・取得値・判定根拠・全詳細行・未確認事項を記載する。接続の切断、remote admin connections の変更、拡張イベントの作成・変更・開始・停止は行わない。

参考: [sys.endpoints](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-endpoints-transact-sql)、[sys.dm_exec_connections](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-connections-transact-sql)、[XE イベント定義](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-event-session-events-transact-sql)、[XE 列メタデータ](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-xe-object-columns-transact-sql)。

## 表形式での出力必須

両チェックの集計値は「項目」「値」の表で掲載する。DAC connections の詳細は connection_id、session_id、endpoint_id、connect_time、client_net_address、login_name、host_name、program_name、endpoint_name の9列を持つ表で全行掲載する。0件でも列見出しと0件を示し、取得失敗を0件としない。

DAC XE tracking の詳細は session_name、event_id、event_name、predicate、is_running、startup_state、targets、result の8列の Markdown／HTML 表で全候補を掲載する。述語と記録先は省略・要約せず、表の特殊文字と改行をエスケープして全文を保持する。is_running と startup_state を区別し、NULL・停止中・複雑な条件の未判定理由も保持する。プレーンテキストやコードブロックだけで代用しない。0件と取得不能を区別し、全列・全行・取得値を元結果と照合する。
