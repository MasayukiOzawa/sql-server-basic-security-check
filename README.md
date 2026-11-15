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

`.claude-plugin/plugin.json` にプラグイン定義、`.claude-plugin/marketplace.json` にマーケットプレイス定義を配置しています。プラグインとスキルのルートはリポジトリ直下です。`skills: ["."]` で直下の `SKILL.md` を参照します。

マーケットプレイスの Git URL:

```text
https://github.com/MasayukiOzawa/sql-server-basic-security-check.git
```

Claude Code での登録・インストール:

```text
/plugin marketplace add https://github.com/MasayukiOzawa/sql-server-basic-security-check.git
/plugin install sql-server-basic-security-check@sql-server-security-marketplace
```

Codex での URL 登録・スキル検出は実機インストール未検証です。上記は Claude 互換マニフェストであり、Codex 固有の定義を検証済みとするものではありません。

インストール後も Windows、PowerShell、ODBC 版 sqlcmd と対応 ODBC Driver が必要です。インストール時に SQL 接続やチェックの実行は行いません。

仕様: [プラグイン定義](https://code.claude.com/docs/en/plugins-reference)、[マーケットプレイス](https://code.claude.com/docs/en/plugin-marketplaces)。
