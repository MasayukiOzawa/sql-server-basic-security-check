# SQL Server Basic Security Skill

Microsoft SQL Server の基本セキュリティチェックを行う AI スキルです。
ローカルの PowerShell と ODBC 版 sqlcmd を使用し、設定情報やログを読み取ってレポートを作成します。

スキルの入口は [SKILL.md](SKILL.md) です。
実行環境・接続方法は [接続設定](references/connection.md)、実行方法は [クエリ実行手順](references/query-execution.md) を参照してください。

## 実行環境の前提

| 項目 | 前提 |
| --- | --- |
| 実行環境 | 対象 SQL Server に接続できる Windows 上のローカル実行環境。Desktop を操作する端末と、コマンドの実行先が一致するか確認してください。 |
| PowerShell | PowerShell 7 を使用します。 |
| SQL クライアント | ODBC 版 sqlcmd と、その実行ファイルに対応する ODBC Driver・DLL・CPU アーキテクチャが必要です。Go 版 sqlcmd は対象外です。 |
| 接続情報と権限 | 実際のサーバー名・インスタンス名または TCP ポート、認証方式、各チェックに必要な参照権限を確認してください。 |
| Windows 認証 | sqlcmd の実行ユーザーの資格情報を使います。`codexsandboxoffline` 等の場合は接続を停止し、正式な承認手段またはユーザー自身の PowerShell で実行します。 |
| SQL 認証 | パスワードを入力できる対話ターミナルが必要です。 |
| Microsoft Entra MFA | 対応する接続先と、ユーザーがサインイン画面を操作できる対話デスクトップが必要です。 |

バージョン番号による下限チェックや更新の強制は行わず、実行に必要な機能を前提チェックで確認します。プレビュー成功は接続・認証・診断の成功を意味しません。
すべての認証方式で `-N -C` を使用し、暗号化を要求しつつサーバー証明書の信頼チェーン・名前の検証を省略します。診断は読み取りのみで、設定変更は行いません。

## ライセンス

このリポジトリのスキル定義、スクリプト、SQL、テストおよび独自ドキュメントは **MIT License** で提供します。
SPDX 識別子は `MIT` です。条件と免責事項の全文は [LICENSE](LICENSE) を参照してください。
再配布時は著作権表示とライセンス本文を含めてください。

参照先の Microsoft ドキュメントや外部ソフトウェアには、それぞれの権利・ライセンスが適用されます。
診断先から取得したログやレポート内のデータについて、このライセンスは公開・再配布の権限を付与するものではありません。

## プラグインとマーケットプレイス

`plugin.json` に標準プラグイン定義、`.codex-plugin/plugin.json` に Codex 互換定義、`.claude-plugin/` に Claude 互換定義とマーケットプレイスを配置しています。プラグインのルートはリポジトリ直下です。検出用の入口は `skills/security-check/SKILL.md` で、ルートの `SKILL.md` と既存の診断処理を参照します。スキル識別子は `sql-server-basic-security-check` です。

マーケットプレイスの Git URL:

```text
https://github.com/MasayukiOzawa/sql-server-basic-security-check.git
```

Claude Code での登録・インストール:

```text
/plugin marketplace add https://github.com/MasayukiOzawa/sql-server-basic-security-check.git
/plugin install sql-server-basic-security-check@sql-server-security-marketplace
```

Codex Desktop では、この Git URL をマーケットプレイスとして登録し、`sql-server-basic-security-check` をインストール・有効化してください。CLI から登録する場合:

```powershell
codex plugin marketplace add https://github.com/MasayukiOzawa/sql-server-basic-security-check.git
```

1.1.0 から更新する場合はマーケットプレイスを更新し、プラグインを更新（更新操作がなければ再インストール）してください。CLI でマーケットプレイスを更新する場合は `codex plugin marketplace upgrade sql-server-security-marketplace` を使用します。キャッシュのマニフェストが **1.2.0** になり、`skills/security-check/SKILL.md` が存在することを確認してください。マーケットプレイスの更新だけでインストール済みコピーが更新されたと判断しないでください。

更新後は Desktop を再起動し、新しいチャットを開始してください。既存チャットのスキル一覧には反映されない場合があります。

インストール後も Windows、PowerShell、ODBC 版 sqlcmd と対応 ODBC Driver が必要です。インストール時に SQL 接続やチェックの実行は行いません。

仕様: [プラグイン定義](https://code.claude.com/docs/en/plugins-reference)、[マーケットプレイス](https://code.claude.com/docs/en/plugin-marketplaces)。

## `/` と `@` での選択方法

### `/` からスキルを選択する

1. インストール・有効化後、新しいチャットの入力欄に `/` を入力します。
2. `SQL Server Basic Security Check` または `sql-server-basic-security-check` で候補を絞り込み、対象スキルを選択します。
3. 続けて、下記のサンプルプロンプトを入力して送信します。

### Work で `@` からプラグインを選択する

1. Work の入力欄に `@` を入力します。
2. `sql-server-basic-security-check` を検索し、対象プラグインを候補から選択します。
3. 続けて、下記のサンプルプロンプトを入力して送信します。

どちらも UI の候補から選択してください。`/sql-server-basic-security-check` などの文字列を入力するだけで選択が成立するとは限りません。`@` の候補にはプラグイン内のスキルが表示される場合もあります。


Codex Desktop では `/` を入力し、`SQL Server Basic Security Check` または `sql-server-basic-security-check` で候補を絞り込んでスキルを選択します。公式仕様では有効なスキルがスラッシュ候補に表示されます。表示名や候補の形式はクライアントによるため、候補から選択してください。カスタムプロンプトの手動コピーは不要です。

`@` はプラグインの選択、`/` は有効なスキルの選択です。`@` に表示されるだけではスキル検出の確認になりません。更新後も `/` に表示されない場合は、新しいチャットのスキル一覧、プラグインの有効状態、キャッシュ内のバージョンと入口ファイルを確認してください。別端末の Desktop UI での表示確認は導入先で必要です。

### 導入先の Desktop／Work での受け入れ確認

ローカルマーケットプレイス経由のインストールと app-server の `skills/list` による有効なスキルの検出は確認済みです。別端末の Desktop／Work でのスラッシュ候補表示は未確認です。API の検出成功だけで UI の確認を完了したとは扱いません。

1. 上記の手順で導入先を 1.2.0 に更新し、キャッシュ内のバージョンと入口ファイルを確認する。
2. Desktop を再起動し、Work で新しいチャットを開始する。
3. `/` を入力し、`SQL Server Basic Security Check` または `sql-server-basic-security-check` を検索して候補から選択する。
4. 選択したスキルに「SQL Server には接続せず、読み込んだ SKILL.md の配置パスとスキル名だけを報告してください」と依頼する。1.2.0 のキャッシュ内の `skills/security-check/SKILL.md` が読み込まれることを確認する。

合格条件は、`/` の候補から選択でき、対象のスキル本文を読み込めることです。`@` での選択や絶対パスの直接指定だけでは合格としません。SQL Server の接続・診断は、この確認には不要です。

確認時は Desktop のバージョン、利用モード、プラグインのバージョン、新規チャットかどうか、候補表示・選択・読み込みの各結果を記録してください。候補が出ない場合は未確認のままとし、その記録を添えて報告してください。

## サンプルプロンプト

上記の `/` または `@` で対象を選択した後に入力します。サーバー名、ポート、ユーザー名は実環境に置き換えてください。`1433` は例であり、実際の待ち受けポートを確認します。パスワードやトークンはプロンプトに含めません。

### ローカルの既定インスタンスを全項目チェック

```text
このサーバーの SQL Server 既定インスタンスを、Windows 認証で全項目チェックしてください。
実行前に Windows の実行ユーザーを確認し、スキルの前提環境チェックとプレビューを行ってください。
設定変更は行わず、結果を目次付き HTML レポートにまとめてください。
```

### 接続先とチェック項目を指定

```text
接続先 tcp:SQLSERVER01,1433、データベース master、Windows 認証で、
xp_cmdshell、Ole Automation Procedures、clr enabled をチェックしてください。
設定変更は行わず、取得値と判定根拠を報告してください。
```

### SQL 認証で実行

```text
接続先 tcp:SQLSERVER01,1433、データベース master に、
SQL 認証のユーザー audit_login で接続し、全項目をチェックしてください。
パスワードは対話入力します。
結果を目次付き HTML レポートにまとめてください。
```

### Microsoft Entra MFA で実行

```text
接続先 tcp:SQLSERVER01,1433、データベース master に、
Microsoft Entra MFA のユーザー user@example.com で接続し、全項目をチェックしてください。
サインイン操作はこちらで行います。
接続先確認と全チェックは1接続で実行し、HTML レポートを作成してください。
```

### 接続せずにプレビューだけ確認

```text
接続先 tcp:SQLSERVER01,1433、データベース master、Windows 認証で全項目をチェックするための
前提環境チェックとプレビューだけを行ってください。
SQL Server への接続と診断 SQL の実行は行わないでください。
```

### ファイルを保存せず、チャットで報告

```text
接続先 tcp:SQLSERVER01,1433、データベース master、Windows 認証で全項目をチェックしてください。
レポートファイルは保存せず、結果をチャット内の表で報告してください。
検出したログは省略せず、本文も表示してください。
```

仕様: [Codex スラッシュコマンド](https://learn.chatgpt.com/docs/reference/slash-commands)、[プラグインの配布構成](https://developers.openai.com/plugins/build/plugins)。


## その他の呼び出し方法

Claude Code のプラグインコマンド（プラグイン更新後）:

```text
/sql-server-basic-security-check:check 全項目をチェックして HTML レポートを作成してください。
```

Codex CLI／IDE のカスタムプロンプト（非推奨の互換方式）:

```powershell
New-Item -ItemType Directory -Path "$HOME/.codex/prompts" -Force
Copy-Item ./prompts/sql-server-basic-security-check.md "$HOME/.codex/prompts/"
```

既存の同名ファイルがある場合は内容を確認してから更新してください。新しいセッションで次のコマンドを使用します。

```text
/prompts:sql-server-basic-security-check 全項目をチェックして HTML レポートを作成してください。
```

Codex のカスタムプロンプトはローカル登録であり、プラグインのインストールだけでは登録されません。Desktop での表示・実行は未検証です。通常は `$sql-server-basic-security-check` を使用してください。パスワードやトークンを引数に含めないでください。

仕様: [Codex Custom Prompts](https://learn.chatgpt.com/docs/custom-prompts)、[Claude コマンド定義](https://code.claude.com/docs/en/plugins-reference#commands)。
