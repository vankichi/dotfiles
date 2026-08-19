---
name: plan-implementation
description: 確定 spec を実装計画に落とす。層配置の判断 → PR 分割 (依存順 / 行数目安) → junior が追える手順 + ハマりどころ + 手元確認手段。working tree のみ読む。「実装計画にして」「PR 分割して」等で使う。
---

# plan-implementation

確定済みの spec を、実装者が迷わず着手できる計画に落とす。

**実装はしない。** spec の設計判断も変えない (矛盾を見つけたら報告して止まる)。

## 発火条件

default-on。skip する場合は理由を出力する。

- 「実装計画にして」「PR 分割して」「着手手順を出して」等の要求
- 人間が受け入れを表明済みの spec が入力にある

未確定の spec が来た場合は本 skill を回さず、`harden-spec` を先に通すよう促す (兼務しない)。

## 前提

- **working tree しか読まない。** `git` / `gh` に依存しない
- 層配置の判断基準は repo 側の `.claude/rules/layering.md`、PR 規模の目安と docs 同居の規約は `.claude/rules/review-checklist.md`。**先にこれらを読む**
- 無い repo の場合: `references/portable-planning.md` の汎用版に落として続行し、「repo 固有の層規約なしで実施」と明示する

## 手順

1. **実装配置** — 変更を層に割り当てる。層ごとに **既存の実例 file を 1 つ挙げ、grep で実在を確認する**
2. **依存順に並べる** — 参照される側を先に。循環したら分割の切り方を変える
3. **PR 分割** — 依存順 / 行数目安 / docs 同居の規約で切る。1 PR = 1 責務
4. **各 PR の着手手順** — 触る file、追加する test、ハマりどころ、手元確認コマンド
5. **検証手段の実在確認** — 挙げた task / test コマンドを repo の task 定義 file で grep する。**実在しないコマンドは書かない**

## 出力

- PR 一覧: 順序 / 目的 / 触る file / 想定行数
- PR ごと: 着手手順 (junior が追える粒度) / ハマりどころ / 手元確認コマンド
- 計画に落とせなかった spec 項目を要確認事項として明示 (黙って落とさない)

## やらないこと

- 実装 / commit / push
- spec の設計判断の変更 (矛盾は報告して停止)
- 進行中 PR / branch との衝突検出 (Claude Code の `/spec-check` 側)
- 実在確認していないコマンド・file path を計画に書くこと
