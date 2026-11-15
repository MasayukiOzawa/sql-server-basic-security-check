# 接続設定

## 初期実装の前提

- Windows 上の PowerShell 7 と ODBC 版 `sqlcmd` を使用する。
- 既定は Windows 統合認証（`-E`）。`Authentication` で SQL 認証または Entra MFA を選択できる。
- `sqlcmd -?` で使用する実装とオプションを確認する。Go 版は暗号化オプションが異なるため、このスクリプトの対象外。
- ユーザー指定により、すべての認証方式で `-N -C` を指定する。暗号化を要求し、サーバー証明書の信頼チェーン・名前の検証をスキップする。暗号化された接続先の正当性は証明書で検証されない。
- プレビューでは `EncryptConnection = True`、`TrustServerCertificate = True` と実際の引数を表示する。OS の証明書ストアや SQL Server の設定は変更しない。

## 実行時に指定する情報

| PowerShell パラメーター | 用途 | 初期値 |
| --- | --- | --- |
| `ServerInstance` | サーバー名、`server\instance` または `tcp:server,port` | 必須 |
| `Database` | 対象データベース | 必須 |
| `QueryFile` | UTF-8 の SQL ファイル | 必須 |
| `Authentication` | `Windows` / `Sql` / `EntraMfa` | `Windows` |
| `UserName` | SQL ログイン名または Entra UPN。Windows 認証では指定不可 | Sql / EntraMfa で必須 |
| `LoginTimeoutSeconds` | 接続タイムアウト（秒）。明示指定を優先 | 15（EntraMfa は 120） |
| `QueryTimeoutSeconds` | クエリタイムアウト（秒） | 30 |
| `SqlcmdPath` | ODBC 版 sqlcmd のコマンド名または実行ファイルのパス | `sqlcmd` |
| `Execute` | 実際の接続と SQL 実行を有効にするスイッチ | 無効 |

サーバー・データベースに加えて、本番／検証などの環境区分を会話または運用設定で把握する。
接続情報はこのスキルに埋め込まず、実行時の引数として渡す。
調査用アカウントの権限不足が判明した場合は、不足する対象と権限を報告する。

## Windows 認証の実行ユーザー確認

Windows 統合認証（`-E`）は sqlcmd を起動するプロセスの Windows 資格情報を使用する。Desktop にサインインしているユーザーと実行プロセスのユーザーが同じとは限らない。

Windows 認証で実行する前に、sqlcmd と同じ実行環境・権限コンテキストの PowerShell で `[System.Security.Principal.WindowsIdentity]::GetCurrent().Name`（または `whoami`）を取得して報告する。これはエージェントが行う接続前の確認であり、既存の自動前提チェックの `Passed` だけで確認済みとしない。

- `codexsandboxoffline`、`codexsandboxonline` などのサンドボックス用アカウント、またはユーザーが指定した接続用 Windows アカウントと異なる場合、そのコンテキストで `-Execute` を実行しない。実行ユーザーを取得できない場合も停止する。アカウント名だけで、その他の実行制限がないと判断しない。
- 実行ツールにサンドボックス外実行の正式な承認機能がある場合は、Windows 認証に必要なユーザーの資格情報で実行するためであることを説明し、その機能と環境のポリシーに従う。承認された環境でも実行ユーザーを再確認する。サンドボックス外実行だけで目的のユーザーになったとは判断しない。
- 承認機能が利用できない、許可されない、または目的の実行ユーザーにならない場合は停止し、ユーザー自身の PowerShell で実行できる共通入口のプレビュー／実行コマンドを提示する。接続先・選択項目・Windows 認証・`-N -C` は維持する。管理者実行を一律に要求しない。
- `runas`、別プロセスやタスクの作成、資格情報の保存などで実行制限を迂回しない。サンドボックス用アカウントへの SQL ログイン作成・権限付与、認証方式の自動切り替え、暗号化の無効化は行わない。

未実行時は実行ユーザーと停止理由を報告し、診断項目は未判定とする。ユーザーのターミナルで実行する場合も接続確認だけを別実行せず、共通入口で全選択項目を1接続で処理する。

## SQL 認証 / Entra MFA の使用例

PowerShell 7 の対話ターミナルで実行する。以下の接続先とユーザー名を置き換える。

```powershell
$parameters = @{
    ServerInstance = 'tcp:YOUR-SERVER,1433'
    Database = 'master'
    Checks = @('xp_cmdshell')
}
# リポジトリルートから実行。まずはプレビュー（入力や接続は発生しない）。
./scripts/Invoke-SecurityChecks.ps1 @parameters -Authentication Sql -UserName 'audit_login'
# sqlcmd の非表示パスワードプロンプトに入力する。
./scripts/Invoke-SecurityChecks.ps1 @parameters -Authentication Sql -UserName 'audit_login' -Execute
# Entra のサインイン画面で認証を完了する。
./scripts/Invoke-SecurityChecks.ps1 @parameters -Authentication EntraMfa -UserName 'user@example.com' -Execute
```

SQL 認証は `-U` のみを渡し、パスワードは sqlcmd のプロンプトで入力する。パスワード引数や保存機能は提供しない。
Entra MFA は `-G -U` の順序で対話認証を要求し、パスワードは渡さない。MFA の要求はテナントのポリシーと既存セッションに従うため、毎回の追加認証を強制するものではない。
親プロセスの `SQLCMDPASSWORD` は実行中のみ取り除き、成功・失敗にかかわらず復元する。

実行には Windows、PowerShell、ODBC 版 sqlcmd と対応する ODBC Driver が必要。バージョン番号では実行を制限しない。Entra MFA には対話可能なデスクトップも必要。
接続先でも選択した認証方式とユーザーのアクセスが構成されている必要がある。クライアント側の指定だけでは有効にならない。
Entra 対応接続先であっても、xp_cmdshell のチェック対象は SQL Server。Azure SQL Database 等で設定を取得できない場合は正常扱いしない。

AI からの実行で入力画面を操作できない場合は、上記のコマンドをユーザーのターミナルで実行する。チャットにパスワードや MFA コードを貼り付けない。
認証失敗やキャンセル時は別方式への自動切り替えをせず、未判定として報告する。設定変更は行わない。

仕様は [Microsoft Learn: sqlcmd authentication](https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-authentication) と [sqlcmd utility](https://learn.microsoft.com/sql/tools/sqlcmd/sqlcmd-utility) を参照する。

## 自動の前提環境チェック

プレビュー時と `-Execute` 時に [SqlPrerequisites.ps1](../scripts/SqlPrerequisites.ps1) を自動実行する。DB 接続やソフトウェアの自動インストールは行わない。

- Windows と、指定した実行ファイルが ODBC 版 sqlcmd と識別できることを確認する。
- 実行ファイルが参照する ODBC ドライバー系列の登録・DLL・CPU アーキテクチャを確認する。識別できない場合も停止する。
- SQL 認証は対話セッションと標準入力、Entra MFA は対話セッションを確認する。MFA 画面の表示・操作が実際に可能かまでは保証しない。
- 不足があれば対応案と導入先をエラーに表示し、SQL を実行せず停止する。必要な対応後に再実行する。


プレビュー成功はローカル前提の充足を示す。通信、接続先の認証設定、TLS の対応状況、ユーザーのアクセス、必要権限は接続・SQL 実行時に確認される。サーバー証明書の検証は行わない。
これらの失敗時は未判定として停止し、元のエラーと対応案を報告する。認証の自動切り替えや権限付与は行わない。

バージョンの下限チェックや更新要求は行わない。機能の非対応が実行時に判明した場合は、そのエラーと必要な対応を報告する。

通常のスキル実行は [一括入口](../scripts/Invoke-SecurityChecks.ps1) を使う。接続先情報と選択した診断を1回の sqlcmd 接続で取得し、別途接続確認を行わない。下位の QueryFile は内部で組み立てる。
