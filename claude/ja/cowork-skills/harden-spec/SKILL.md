---
name: harden-spec
description: 設計 draft / ticket を repo と 3 者照合して実装可能な spec にする。乖離 5 分類 + data model 最小化を当て、未決は選択肢と推奨を付けて人間に返す。working tree のみ読む。「spec 詰めて」「実装可能にして」等で使う。
---

# harden-spec

人間が書いた設計 draft / ticket を、repo の実態と突き合わせて **実装可能な spec** にする。

**設計判断はしない。** 未決は選択肢 + 推奨 + 根拠を出して人間に返す。実装計画も作らない (`plan-implementation` の責務)。

`write-spec` との境界: あちらは spec contract の穴埋め (必須 section が揃っているか)。本 skill は **repo の実態との突合** (書かれていることが repo で成立するか)。

## 発火条件

default-on。skip する場合は理由を出力する。

- 「spec を詰めて」「実装可能にして」「設計を repo と突き合わせて」等の要求
- ticket / 設計 draft の本文が入力にあり、対象 repo が開かれている

## 前提

- **working tree しか読まない。** `git` / `gh` / branch / diff に依存しない。進行中 PR / branch との衝突検出は本 skill の責務外 (Claude Code の `/spec-check` 側)
- 観点の SoT は repo 側の `.claude/rules/spec-drift.md`。**最初にこれを読む**
- data model に触る spec なら `.claude/rules/data-modeling.md` も読む
- どちらも無い repo の場合: `references/portable-checklist.md` の汎用版に落として続行し、「repo 固有の観点なしで実施」と明示する

## 手順

1. **spec の literal を一覧化** — 識別子 / path / 引用 / 列・field / コマンド
2. **repo に解決** — 各 literal を grep する。未解決は乖離候補
3. **乖離を全分類で判定** — 検出あり / なし + 何を確認したかを **全分類について出力する** (黙った skip 禁止)
4. **data model 最小化** — 新規の永続状態の提案があれば、導出 > 既存列の意味を締める > 列追加 の順で当てる
5. **未決の洗い出し** — 選択肢 + 推奨 1 つ + 根拠を提示し、人間の決定を待つ
6. **本文反映** — 決定を spec 本文に書き戻す。却下した案と理由も残す (同じ議論の再燃を防ぐ)

## 出力

- 乖離 1 件ごと: 分類 / 両側の evidence (repo 側は path + symbol または見出し、spec 側は section 見出し + 原文引用) / なぜ乖離か / 解消案
- 未決一覧: 選択肢・推奨・根拠
- 最後に実装可能かの判定。**ready flag は立てない** (人間のみ)

## やらないこと

- 設計判断の独断、ready flag、commit / push
- 進行中 PR / branch との衝突検出 (`/spec-check` 側)
- 実装配置 / PR 分割 / 着手手順 (`plan-implementation` 側)
- line 番号での引用 (stale する。path + symbol または見出しで指す)
