# セキュリティチェックのクエリ実行

## 実行対象の準備

実装済み項目では対応するチェック定義と SQL を利用する。実装済み項目は [xp_cmdshell](xp-cmdshell.md)、[Ole Automation Procedures](ole-automation-procedures.md)、[clr enabled](clr-enabled.md) の無効化確認、および [Configuration option ログの有無・内容の確認](configuration-option-log.md)。ログ検出時は判定と件数だけでなく、日時・プロセス・本文全文を含む全ログ行をコードブロックで報告する。
新しい項目はユーザーの指示を受けて [チェック定義テンプレート](check-template.md) に沿って定義し、読み取り SQL を用意する。
[SQL テンプレート](../assets/queries/security-check.template.sql) はコメントのみのひな形であり、そのまま実行しない。
未記入の定義、未実装の SQL、コメントのみのファイルは実行対象に含めない。
既存の実行スクリプトはチェック定義の完成度やコメントのみかどうかを検査しないため、準備段階で内容を確認する。

## プレビューと実行

スキルの実行には [Invoke-SecurityChecks.ps1](../scripts/Invoke-SecurityChecks.ps1) を使用する。接続確認だけを別途実行しない。
接続情報と選択したチェックを1つのバッチにまとめ、既存の実行処理を1回だけ呼び出す。既定では実装済み14項目を実行する。

以下は リポジトリルートをカレントディレクトリにした例。接続先とユーザー名を実際の対象に置き換える。

```powershell
$parameters = @{
    ServerInstance = 'tcp:YOUR-SERVER,1433'
    Database = 'master'
    Authentication = 'EntraMfa'
    UserName = 'user@example.com'
}
# ローカル前提・選択項目・BatchSql を確認。認証や接続は発生しない。
./scripts/Invoke-SecurityChecks.ps1 @parameters
# 接続先情報と全チェックを同じ接続で取得する。
./scripts/Invoke-SecurityChecks.ps1 @parameters -Execute
# 項目を限定する場合は、プレビューと実行の両方で同じ Checks を指定する。
# -Checks 'xp_cmdshell','clr enabled'
```

`Checks` は `xp_cmdshell`、`Ole Automation Procedures`、`clr enabled`、`Configuration option log`、`sa login`、`trustworthy`、`recent object changes`、`recent agent job changes`、`sysadmin logins`、`DAC connections`、`DAC XE tracking`、`service accounts`、`linked servers`、`encryption certificate log` から選ぶ。重複項目は1回だけ実行する。
既知の SQL Server 内部名がある場合は `-ExpectedServerName` を指定する。IP や DNS の別名を内部名と推測しない。
同じ接続内で DB 名と、指定されていれば内部サーバー名を照合し、不一致なら診断前に停止する。
接続先情報を最初の結果セットで報告し、各項目の結果と対応付ける。別接続による事前確認は行わない。

プレビューでは SourceFiles と BatchSql を確認する。QueryFile は処理終了時に削除される一時ファイルなので、再実行には同じパラメーターでスクリプトを呼ぶ。
一時 SQL は成功・失敗の両方で削除する。プレビューは T-SQL の構文検査や接続成功を保証しない。

実行は1回の sqlcmd 呼び出し・1接続とし、認証失敗時の自動再接続は行わない。
MFA の画面数や追加操作は認証サービスのポリシーに依存するため、画面が必ず1枚だけになることは保証しない。トークンの独自保存は行わない。
途中の SQL エラーは既存の `-b` で後続バッチを停止する。結果が得られなかった項目は未判定とする。

個別 SQL の開発・調査用には Invoke-SqlQuery.ps1 も利用できるが、スキルの一括診断で項目ごとに呼び分けない。

## SQL の作成

- 指定されたチェック項目に必要な情報だけを取得する。情報を省略する場合は判定に必要な根拠が欠けないようにする。
- テーブル名は原則として `schema.table` で記述する。対象外のデータベースへの `USE` やリンクサーバー参照を混ぜない。
- 入力ファイルは T-SQL と必要な `GO` 区切りで構成する。`GO n` はバッチを繰り返すため意図を確認する。
- `:connect`、`:r`、`:out` などの sqlcmd コマンドや `!!` はこの補助スクリプトでは受け付けない。行頭の `:` / `!!` を保守的に拒否するため、複数行文字列やコメント内の同じ表現も対象になる。
- `$(変数)` の sqlcmd 展開は無効。外部入力を文字列連結で SQL に挿入しない。入力値を受け付ける業務クエリが必要なら、パラメーターをバインドできるドライバーで実行経路を拡張する。

## エラーと未判定

セキュリティチェックは読み取りで行い、設定変更や自動修正は含めない。

`sqlcmd` の非ゼロ終了コードは PowerShell のエラーとして通知する。
Windows 認証で接続に失敗した場合は、[接続設定](connection.md#windows-認証の実行ユーザー確認) に従って、その試行のクライアント実行ユーザーを元のエラー・終了コードとともにチャットとレポートへ出力する。未取得のユーザー名は推測しない。
権限不足、タイムアウト、SQL エラーでは取得できた範囲と不足する情報を記録する。
チェック定義の「取得できない場合の扱い」に従って報告し、必要な根拠が不足する項目は未判定とする。
終了コードがゼロでも、空の結果や部分的な結果だけで正常と判断しない。

## 結果の扱い

実行結果は sqlcmd のテキスト出力。CSV / JSON や型付きのデータセットではない。
可変長の値は `-y 0` で切り詰めを無効にする。表示幅による折り返しがあっても、ログ本文の空白や改行を一括置換して変えない。
結果は各チェック定義に必要な全対象行を報告し、秘密情報は転記しない。
スキル実行後は [レポート出力手順](report-output.md) に従い、エージェントが取得済みの結果からレポートファイルを生成する。既定は作業ディレクトリの reports 配下に UTF-8 HTML。実行スクリプト単体ではファイル生成を行わない。

[結果報告のひな形](check-template.md#結果報告のひな形) を使い、未実行／プレビューのみ／実行済みの区別と、項目ごとの取得値・判定・根拠・未確認事項を記載する。
判定はユーザーが指定した基準に従う。未記入・未実装・未実行の項目を正常扱いしない。

`-b` によるエラー処理、`-X1` による起動スクリプト等の抑制、`-x` による変数展開の無効化の仕様は [Microsoft Learn: sqlcmd utility](https://learn.microsoft.com/sql/tools/sqlcmd/sqlcmd-utility) を参照する。
これらのオプションは T-SQL の権限制御や読み取り専用化の代わりにはならない。

## 追加項目の選択

`QueryFile` を対象項目のファイルに置き換え、同じプレビュー・実行手順を使う。

| 項目 | QueryFile（リポジトリルート基準） |
| --- | --- |
| Ole Automation Procedures | `./assets/queries/check-ole-automation-procedures.sql` |
| clr enabled | `./assets/queries/check-clr-enabled.sql` |
| sa ログインの有効状態 | `./assets/queries/check-sa-login.sql` |
| Configuration option ログ | `./assets/queries/check-configuration-option-log.sql` |

各項目を独立して判定・報告する。通常のスキル実行では上記の一括入口と Checks を使い、同じ接続で処理する。

[sa ログインのチェック定義](sa-login.md) に従い、is_disabled は 1 が無効、0 が有効として判定する。

[TRUSTWORTHY](trustworthy.md) は有効な DB を列挙し、msdb の ON は既定値として情報を注記する。

[直近7日間のオブジェクト変更](recent-object-changes.md) は全 DB を同じ接続で参照し、検出した全行と DB ごとの未確認事項を報告する。

[直近7日間のエージェントジョブ変更](recent-agent-job-changes.md) は msdb のジョブ最終変更日時を確認し、検出した全行を報告する。

[sysadmin 所属ログイン](sysadmin-logins.md) は付与経路・無効状態を含めて全行を報告し、グループ内ユーザーや非表示メタデータは未確認とする。

[DAC の2項目](dac-checks.md) は現在の接続と拡張イベントの追跡設定を別々に報告する。通常接続を利用し、DAC 接続や監視設定の変更を行わない。

[サービスアカウント](service-accounts.md) は DMV を主結果、現在の ERRORLOG を補助として別々に報告する。サービスやアカウントは変更しない。

[リンクサーバー設定](linked-servers.md) はローカルカタログの設定とログインマッピングを全行報告し、リンク先への接続は行わない。

[暗号化接続用証明書のログ](encryption-certificate-log.md) は現在の ERRORLOG を分類して全行出力する。ログの読み込み成功を証明書の信頼性確認と扱わない。
