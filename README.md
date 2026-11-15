# SQL Server Basic Security Skill

Microsoft SQL Server の基本セキュリティチェックを行う AI スキルです。
ローカルの PowerShell と ODBC 版 sqlcmd を使用し、設定情報やログを読み取ってレポートを作成します。

スキルの入口は [SKILL.md](SKILL.md) です。
実行環境・接続方法は [接続設定](references/connection.md)、実行方法は [クエリ実行手順](references/query-execution.md) を参照してください。

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

## スラッシュコマンド

Codex Desktop では `/` を入力し、`SQL Server Basic Security Check` または `sql-server-basic-security-check` で候補を絞り込んでスキルを選択します。公式仕様では有効なスキルがスラッシュ候補に表示されます。表示名や候補の形式はクライアントによるため、候補から選択してください。カスタムプロンプトの手動コピーは不要です。

`@` はプラグインの選択、`/` は有効なスキルの選択です。`@` に表示されるだけではスキル検出の確認になりません。更新後も `/` に表示されない場合は、新しいチャットのスキル一覧、プラグインの有効状態、キャッシュ内のバージョンと入口ファイルを確認してください。別端末の Desktop UI での表示確認は導入先で必要です。

選択後の依頼例:

```text
接続先 localhost、Windows 認証で全項目を実行し、HTML レポートを作成してください。
```

仕様: [Codex スラッシュコマンド](https://learn.chatgpt.com/docs/reference/slash-commands)、[プラグインの配布構成](https://developers.openai.com/plugins/build/plugins)。


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
