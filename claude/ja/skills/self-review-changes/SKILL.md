---
name: self-review-changes
description: 直前の編集差分 (作業ツリー or staged) を観点別に self-review する skill。観点は references/ に分割され、diff 内容で機械的に発火する (default-on + 理由付き skip)。対話時は修正方針を提示し user 承認後に Edit。loop-mode では本 skill は直接起動されず、review-orchestrator agent が本 skill の観点体系 (references/) を読んで review-lens への fan-out を主管する。「self review して」「review して」「修正箇所ないか確認して」等で使う。
---

# self-review-changes

直前の編集差分を観点別に再走査し、修正候補を洗い出して直す skill。**4 Phase**: Mindset → Observation → 観点実行 → Action。
観点の中身は `references/` に 1 観点 1 ファイルで分割されている (skill 粒度原則)。

> **plugin との使い分け**: `/code-review`・`/simplify` plugin は diff の bug / 簡素化に特化。本 skill は設定の正確性 / docs 整合 / memory feedback 整合 / spec 整合まで含む広域 self-review。コードの bug だけなら `/code-review`、変更全体を規約込みで見直すなら本 skill。

## 適用条件

- 何らかのファイル編集が直前ターンで行われている (commit 前 or 直近 commit 後)
- 修正対象範囲が明確 (`git diff` で見える範囲)

## Phase 0: Mindset shift (実装者 → 外部 reviewer)

self-review の最大バイアスは「自分の intent が見えて actual gap が見えない」こと。Phase 1 以降に進む前に**「初めてこの code を見た外部 reviewer」**として読む宣言を内面で立てる。コメントは binding contract と扱い、「私はこう意図した」「typical input では起きない」「内部 caller だから OK」は禁句。wire form / nil / empty / 境界値 / cancellation 中 / 不正 spec などを adversarial に想定する。

## Phase 1: Observation (差分把握 + 関連情報取得)

1. 差分把握: `git status` / `git diff --stat` / `git diff [--cached]` (直近 commit 後は `git show HEAD`)
2. 全変更 file を Read tool で並列読み込み (Bash の `cat` ではなく)
3. `MEMORY.md` index を Read し、編集内容に関連する feedback / project entry を中身まで read
4. 対応する spec / work item があれば取得 (spec-alignment 観点の入力)

## Phase 2: 観点の実行 (default-on + 機械的 skip 判定)

観点は全て default-on。**skip して良いのは下表の機械的条件を満たす時だけ**で、skip には理由を付ける:

| 観点 (references/) | skip 可の条件 (機械判定) |
|---|---|
| correctness.md | code diff が 0 (docs / config のみの変更) |
| filetype-checks.md | なし (常時実施) |
| conventions.md | なし (常時実施) |
| spec-alignment.md | 対応する spec / work item が存在しない |
| test-adversarial.md | test ファイルの diff が 0 |
| performance.md | code diff が 0 |
| observability.md | 新規 code path なし (docs / config / test のみ) |
| dependency.md | 依存ファイル (go.mod / go.sum / lock / import 行) の diff が 0 |
| code-quality.md | code diff が 0 |

- 実施する観点の references を Read し、checklist を diff に適用する
- **loop-mode**: 本 skill は直接起動されず、`review-orchestrator` agent が本 SKILL.md と references/ を Read して観点 fan-out を主管する (`review-lens` へ観点 reference path + diff 範囲 + spec を渡し並列・**同期**起動)。対話時は inline で順に実施
- dependency 観点が新規依存を検出した場合、loop-mode では即 escalation (CLAUDE.md の壁)

## Phase 3: Action (統合レポート → 承認 → 修正 → 再検証)

### 3.1 統合レポート (強制出力)

**全観点の実施状況を必ず表で出す** (黙った skip 禁止):

```
## Self-review 結果

| 観点 | 実施/skip (理由) | 発見 |
|---|---|---|
| correctness | 実施 | 2 件 |
| dependency | skip (依存ファイル diff 0) | - |
...

| # | file:line | 問題 | 修正方針 | 重要度 |
|---|---|---|---|---|
| 1 | cmd/x/main.go:1 | コメント日本語 | 英語に書き換え | 致命的 (memory feedback 違反) |

## 問題なし
- <確認したが問題なかった対象>
```

重要度は **致命的 / 望ましい / nit** の 3 段階。

### 3.2 承認

- **対話時**: 「進めて」を待つ (selective approval 可)
- **loop-mode**: review-orchestrator の verdict (fix instructions) を dev-cycle が適用し、再 review の反復で解消を確認。nit は draft PR に注記

### 3.3 修正 Edit (並列) → 3.4 再検証

承認された候補を Edit で並列実施 → `make test` / `make lint` 再実行 + 関連 grep 再走 (別 location への同問題波及を確認)。

## 鉄則

1. **Phase 0 の mindset shift を skip しない**: 「自分の intent」で読まず「外部 reviewer として code とコメントだけ」で判断
2. **観点の実施状況表を必ず出力**: 黙った skip 禁止。skip は機械的条件 + 理由付きのみ
3. **致命的 / 望ましい / nit を区別**: 取捨選択できるように
4. **memory feedback は関連 entry を中身まで read**: index 行だけで判断しない
5. **spec 逸脱は明示・承認・記録**: 「prototype だから OK」を暗黙正当化に使わない (CLAUDE.md「変更の作法」)
6. **副作用検証**: 修正後にビルド / テスト / lint を再実行
7. **隠さない**: 自分が直前ターンで作ったものでも問題があれば指摘する
