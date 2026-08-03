---
name: tech-docs-writer
description: 社内向け技術ドキュメント (ADR / Design Doc / API 仕様 / README / Runbook / システム設計書) を日本語 Markdown で作成し docs/{adr,api,readme,runbook,design}/ に保存する。
when_to_use: ADR / Design Doc / API spec / README / Runbook を書く時。「ドキュメント書いて」「ADR 起票して」「runbook 作って」。
---

# 技術ドキュメント作成スキル

社内開発者向けの技術ドキュメントを日本語Markdownで作成する。
5種別のデファクトスタンダードに沿ってテンプレートを出し分ける。

| 種別 | 準拠規格 | 保存先 |
|------|---------|--------|
| ADR / Design Doc (単一の決定) | MADR v3 | `docs/adr/NNNN-<slug>.md` |
| API仕様 | OpenAPI 3.1 の考え方 | `docs/api/<resource>.md` |
| README / ガイド | Diataxis | `docs/readme/<topic>.md` or ルート `README.md` |
| Runbook | Google SRE Playbook | `docs/runbook/<alert-or-topic>.md` |
| システム設計書 | arc42 + C4 + MADR | `docs/design/<system-name>.md` |

## 1. 起動〜種別判定

ユーザー発話やコンテキストから種別を判定する。曖昧な時は作成前に必ず確認する(推測で作らない)。

| 入力シグナル | 種別 |
|------------|------|
| 「決定記録」「ADR」「なぜこの技術選定」「トレードオフ」(単一の決定) | ADR / Design Doc |
| 「API仕様」「エンドポイント」「OpenAPI」「REST/gRPC」「リクエスト/レスポンス」 | API仕様 |
| 「README」「セットアップ」「使い方」「クイックスタート」 | README / ガイド |
| 「Runbook」「Playbook」「障害対応」「オンコール」「アラート対応」 | Runbook |
| 「システム設計書」「アーキテクチャ設計」「arc42」「全体設計」「システム全体の設計」 | システム設計書 |

### ADRとシステム設計書の使い分け

| 対象 | 該当種別 |
|------|---------|
| 単一の意思決定 (「Xを採用する/しない」) | ADR |
| システム/サブシステム全体を俯瞰する設計 (目的/構成要素/動的振る舞い/NFR/デプロイ) | システム設計書 |

迷う場合は、「決定事項」中心か「全体像」中心かで判断する。

## 2. 必須ヒアリング項目

仕様が曖昧な状態では絶対に書き始めない。不足情報は `AskUserQuestion` で確認する。

共通: タイトル/対象読者の前提/関連PR・Issue/保存先ディレクトリの存在

種別ごとの確認項目は対応するreferenceファイルに記載:

- ADR / Design Doc → `references/adr.md`
- API仕様 → `references/api.md`
- README / ガイド → `references/readme.md`
- Runbook → `references/runbook.md`
- システム設計書 → `references/system-design.md`

種別が決まった段階で対応するreferenceファイルをReadすること。各referenceにはテンプレート本文と書き方のコツが入っている。

## 3. 入力ソース別の情報抽出

「コード/差分から自動生成」モードのときは以下を利用する。

### Git diff / PR
```bash
git log --oneline -20
git diff <base>..<head>
gh pr view <number> --json title,body,commits,files
```
コミット粒度で決定の経緯を追い、ADRの Context や Considered Options に反映する。

### Goコード (godoc/コメント)
- パッケージコメント・エクスポートシンボルのdocコメントを第一情報源とする
- インターフェース定義 → APIの契約 / 設計境界の抽出
- `//go:generate` ディレクティブは実装の意図を示すヒント

### Kubernetes マニフェスト / Helm
- `Deployment`/`StatefulSet`のリソース要件、probe設定 → Runbookの前提条件
- `values.yaml`の公開パラメータ → READMEの設定ガイド
- アラートルール(`PrometheusRule`) → RunbookのSymptom節の出発点

## 4. ドキュメント作成フロー

1. 種別判定 (§1) と必須項目ヒアリング (§2)
2. 対応する `references/<type>.md` をRead
3. コードソースが指定されている場合は §3 で情報抽出
4. テンプレートに沿って日本語でドラフト作成
5. **ADR / Design Doc / システム設計書 の場合は draft 完成時に `api-design-review` skill を必ず invoke** して 6 観点 (client 抽象 / ACL 両側 / forward-compat / edge case / SoT 整合 / memory 規約) で網羅性チェック。検出された考慮漏れは draft に反映してから保存。API 仕様 / README / Runbook は同 6 観点を軽量に通過するだけで OK (skill invoke は任意)
6. ファイル保存: `docs/<type>/<filename>.md` へ書き出し
   - ADRは連番 `0001-`, `0002-` … (既存の最大番号+1)
   - システム設計書は `docs/design/<system-name>.md`
   - ディレクトリが未作成なら作成する
7. 図が有用な箇所には Mermaid を積極的に使う (シーケンス図/フローチャート/C4)

## 5. 文体ルール

- リスト項目・表セル・概要行は体言止め優先 (動詞で閉じない)
  - 悪い例: 「P99レイテンシが100ms以下であること」「監視ダッシュボードを確認する」
  - 良い例: 「P99レイテンシ100ms以下」「監視ダッシュボードの確認」
- 文章で書く必要がある箇所 (Context/背景/解説) は通常の常体 (〜である/〜する) で可
- 体言止めと常体を同一箇条書き内で混在させない
- 箇条書きは短く (原則1項目1行・最大2行)
- **長さは題材相当に**: 実体をカバーしたら止める。filler section・重複要約・boilerplate で嵩上げしない

## 6. 品質チェック(書き終わったら自己レビュー)

- [ ] タイトルが一読で主旨を示す(「新機能の対応」のような曖昧な表題を避ける)
- [ ] 読み手(社内開発者)が前提知識なしで結論に辿り着ける
- [ ] リスト・表は体言止めで統一 (§5 文体ルール)
- [ ] 推測・未確認事項を「決定事項」のように書いていない (不明点は `TBD` と明記)
- [ ] 機微情報(個人情報/認証情報/内部URL以外の秘匿値)を誤って貼っていない
- [ ] ADR以外でも決めた事と決めていない事を明確に分離している
- [ ] ファイル末尾に更新履歴 or 関連リンクがある
- [ ] ADR / Design Doc / システム設計書 の場合、`api-design-review` skill を通過済(§4 step 5)、検出考慮漏れは反映済

## 7. やってはいけない(プロジェクト規範)

- 仕様が曖昧なまま書き始めない。不足情報は必ずユーザーに聞く。
- 推測で決めつけない。未確定事項は `TBD` と明記する。
- 秘密情報を出力しない。パスワード/トークン/個人情報が検出されたら、その箇所は `<REDACTED>` に置換する。

## 出力後のユーザー報告

作成後は以下を簡潔に報告する:
- 保存したファイルパス (`computer://` リンク)
- 選んだ種別とその根拠
- 残っている `TBD` の一覧 (あれば)
