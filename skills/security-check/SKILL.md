---
name: sql-server-basic-security-check
description: SQL Server の基本セキュリティチェックを読み取り専用で実行し、結果をレポートにまとめる。Windows の PowerShell と ODBC 版 sqlcmd を使用する。
license: MIT
---

# SQL Server Basic Security Check

このファイルはマーケットプレイスからインストールしたスキルの入口。
実行前に、同梱の [診断手順](../../SKILL.md) と対象項目の参照先を読み、その手順に従う。
相対パスはこのファイルの配置場所を基準に解決する。診断手順内のパスはプラグインのルート（このディレクトリの2階層上）を基準にする。作業ディレクトリや特定ユーザーのキャッシュパスを前提にしない。

実行が依頼に含まれる場合のみ、共通入口の [Invoke-SecurityChecks.ps1](../../scripts/Invoke-SecurityChecks.ps1) で前提環境チェック・プレビュー後に `-Execute` を使う。SQL 作成のみ・プレビューのみの依頼では接続しない。
接続情報は依頼と会話から確認し、不足分だけ尋ねる。設定変更は行わない。
結果の保存は [レポート出力手順](../../references/report-output.md) に従い、ユーザー指定の形式・保存先・保存不要を優先する。
