---
name: self-review-changes
description: 直前の編集差分 (作業ツリー or staged) を self-review し、正確性 / 整合性 / best practice / memory feedback との整合をチェックする。修正方針を提示し user 承認後に Edit する。「self review して」「review して」「修正箇所ないか確認して」等で使う。
---

# self-review-changes

直前の編集差分を再走査し、修正候補を洗い出して承認を取ってから直す skill。**4 Phase**: Mindset → Observation → Analysis → Action。

> **plugin との使い分け**: `/code-review`・`/simplify` plugin は diff の bug / 簡素化に特化。本 skill はそれに加えて **設定の正確性 / docs 整合 / memory feedback 整合 / Copilot 11-category** まで含む広域 self-review。コードの bug だけなら `/code-review`、変更全体を規約込みで見直すなら本 skill。

## 適用条件

- 何らかのファイル編集が直前ターンで行われている (commit 前 or 直近 commit 後)
- 修正対象範囲が明確 (`git diff` で見える範囲)

---

## Phase 0: Mindset shift (実装者 → 外部 reviewer)

self-review の最大バイアスは「自分の intent が見えて actual gap が見えない」こと。 Phase 1 以降に進む前に **「初めてこの code を見た外部 reviewer」** として読む宣言を内面で立てる。 コメントは binding contract と扱い、 「私はこう意図した」「typical input では起きない」「内部 caller だから OK」 は禁句。 wire form / nil / empty / 境界値 / 異常 tokenizer output / cancellation 中 / 不正 spec などを adversarial に想定する。 Phase 2、 特に 2.6-2.9 でこの mindset を maintain。

---

## Phase 1: Observation (差分把握 + 関連情報取得)

### 1.1 差分把握

```bash
git status
git diff --stat
git diff [--cached]
git show HEAD --stat && git show HEAD  # 直近 commit 後
```

### 1.2 全変更 file を Read で並列確認

各 file を Read tool で並列読み込み (Bash の `cat` ではなく)。

### 1.3 関連 memory を Read

- `MEMORY.md` index を Read、編集内容に関連する feedback / project entry を判定して中身まで read
- **毎回必読**:
  - 本 skill Phase 2.1 / 2.1.1 (Copilot 頻出 11 category + Rebut パターン)、Phase 2.6-2.9 で機械的 check
  - CLAUDE.md「変更の作法」(指示外の変更の flag) (Phase 2.3)
  - 推測 mapping 禁止 (原文 literal の範囲だけ / Phase 2.5)

---

## Phase 2: Analysis (観点別 check)

### 2.1 設計観点 — Copilot 頻出 11 category (最重要)

Copilot review で頻出する 11 category (PR #26 + PR #30 の累計 26 件 review 分析より集約)。 以下に展開する。

**PR #26 由来 (5 category)**:

| # | Category | 重要観点 |
|---|---|---|
| 1 | **Documentation accuracy** | helper / API rename したら関連 docs を全 grep / sample の `_` error drop / doc comment と実装の挙動一致 |
| 2 | **Input validation** | public API (`WithXxx` / `NewXxx` / handler arg) で 0 / 負値 / nil / empty / traversal を check、validation 配置は constructor 末尾 |
| 3 | **Edge case** | wire form parameters 付き (MIME `mime.ParseMediaType`) / `strings.TrimSpace` empty check / batch 全要素 fail / empty 出力 catch |
| 4 | **Concurrency / cancellation** | `ctx.Deadline` 尊重 / goroutine spawn 避け / `ctx.Err()` 都度 check / **ctx を最深部まで伝播** (pre-processing loop も含む) |
| 5 | **Error contract** | sentinel 意味契約 (transient vs permanent) / 4xx は retry なし / boundary error の port-level wrap |

**PR #30 由来の拡張 (6 category)**:

| # | Category | 重要観点 |
|---|---|---|
| 6 | **Symmetric constructor defense** | constructor 1 つに guard 追加したら、 `grep "^func New"` で同 PR 内の他 constructor も同じ guard を持つか確認 (Phase 2.6 で機械的 check) |
| 7 | **Doc/impl literal drift** | strong claim ("strictly", "preserves", "Returns X") を含む comment を impl と byte-level で照合 (Phase 2.9 で機械的 check) |
| 8 | **Sentinel-on-error 漏洩** | 依存 interface が 0 / "" / nil / -1 を error 経路で返す契約か godoc 確認、 consumer 側で defense (Phase 2.7 で機械的 check) |
| 9 | **Exported function type contract** | `type X func(...) error` を export、 docstring が "all options X" と claim → custom 実装も同じ contract を満たすか、 factory で wrap (Phase 2.7 で機械的 check) |
| 10 | **Test assertion trivially passes** | repeated fixture content / loose `Contains` / nil-only check が「実装が壊れていても通る」シナリオ (Phase 2.8 で機械的 check) |
| 11 | **Slice OOB / panic guard (test)** | test 内 `slice[len-N:]` の N 直前に `len >= N` guard、 input が短い時の panic |

### 2.1.1 Rebut パターン (false positive を識別)

以下は project context 上「適用不可」と判断して reply で resolve する Rebut パターン:

- **Go 1.22+ loop variable shadow**: `go.mod` の go directive が 1.22+ なら shadow 不要
- **internal port boundary defense 再提案**: SD で撤回した場合、 PR description を referenced して resolve
- **同じ警告の重複投稿**: 別 test に同 pattern が当てはまらない場合は false positive と明示

### 2.2 file type 別の機械的 check

- **Go (`*.go`)**: `gofmt` / `goimports` / godoc 規約 (`// Package <name>` / `// FuncName ...`) / `fmt.Errorf("...: %w", err)` / context arg 最初 / 不要 export
- **設定 (`.golangci.yaml` / `Makefile` / `*.yaml` / `*.json`)**: 形式バージョン (e.g. golangci-lint v1 vs v2) / regex glob (`gen` 中間一致 vs `^gen/` ルート限定) / インデント
- **Markdown / Docs**: 相対 link / コードブロック言語指定 / 表セル数一貫性 / heading 階層
- **Shell / Makefile / Dockerfile**: shell injection (`$VAR` クォート) / 危険コマンド (`rm -rf`, `curl | sh`)
- **Proto (`.proto`)**: package / option / field number / 後方互換性 (`buf breaking`)

### 2.3 spec literal 整合 (spec doc を扱う作業のみ)

spec (`docs/adr/*.md`, `docs/design/*.md`, OpenAPI, Proto) を扱う場合:

1. spec 中の literal (型名 / enum / field / file name) を grep で列挙
2. 実装側の同 surface を grep で列挙
3. **逸脱項目** を明文化、各逸脱に「理由」「是正方針 (a) 仕様に合わせる / (b) 仕様 update / (c) 別 ADR」を添えて user 提示

「prototype だから OK」を暗黙正当化に使わない。明示・承認・記録の 3 点セット (CLAUDE.md「変更の作法」(指示外の変更の flag))。

### 2.4 memory 規約整合

Phase 1.3 で把握した関連 memory に対して、編集差分が違反していないか check:

- 用語規約 (memory の用語規約に準拠)
- 文書スタイル (前提節を立てない、prototype 期の緩和)
- コメント言語 (`*.go` / Makefile / proto / shell の英語)
- コメント内に Phase / ticket ID 表記の混入
- commit message スタイル (短く、変更内容のみ)

### 2.5 cross-reference / forbidden tokens grep

変更 file 全体に grep:

- **一時情報の混入**: `ticket`, `in a later`, `future ticket`, `see (commit|PR) #`, ticket ID 形式 (`#?\d+`, `[A-Z]+-\d+`)。検査 pattern の literal は project の `MEMORY.md` feedback から取得、skill 側 hardcode しない
- **cross-reference 実在確認**: コメント内 section 参照 (`§[0-9]+\.[0-9]+` 等) の引用語彙が原文と一致しているか
- **推測 mapping**: 原文に書かれていない対応関係をコメントで補完していないか

### 2.6 対称性 audit (Symmetric defense check)

差分で追加した guard / validation / nil check と同種の対称対象 (`grep "^func New" $(git diff --name-only)` で同 PR 内 constructor 全列挙、 `opts ...Option` を受ける関数も grep) が同じ guard を持つか確認、 欠落があれば flag。

例: PR #30 C9 — `ports.NewChunkSpec` に nil opt reject を入れたら `chunker.New` の opts も同じ guard が必要 (1 箇所 fix で他を見逃した教訓)。

### 2.7 Interface 契約 trace (Sentinel / Exported type)

変更 file 内で使った external interface の godoc を再 read、 **戻り値の sentinel ケース** (0 / "" / nil / -1 / 特定 error sentinel) と consumer 側の分岐 (`if x <= X`, `errors.Is(...)`) で flow が一致するか確認。 exported function type を export しているなら、 docstring の "all" / "always" claim が custom 実装にも保たれるか、 factory で normalize しているか check。

例: PR #30 C10 — `chunking.Tokenizer.CountTokens` は encoding error 時に 0 を返す、 consumer の `tokens <= MaxTokens` 判定でこの 0 が「fits」と誤判定されないよう defense 必要。 C13 — exported `ChunkSpecOption` の custom 実装が contract を破る経路を factory で wrap。

### 2.8 Test adversarial review (Trivial pass の摘出)

各 test の assertion について 「**実装の挙動を逆にしても pass する mutation はあるか?**」 と問う。 input に repeated content / 同一値 / nil / empty が含まれる場合は特に注意、 `strings.Contains` / `len(got) > 0` / `errors.Is(...)` 系の assertion が trivially 通る経路を探す。

例: PR #30 C7 — 80 個の同一 sentence repeat で carry-over の overlap を `strings.Contains` で check → carry-over が壊れても trivially true。 distinct marker (`[文NNN]`) を入れて `HasPrefix` で boundary 検証する形が正解。

### 2.9 Doc last-write-wins (コメント update 漏れ摘出)

実装変更後、 変更 file 内の全コメントを疑って再 read。 strong claim を grep (`grep -nE "(strictly|preserves|guarantees|ensures|always|never|returns|panics)"`)、 各 claim を impl の literal 動作と byte-level で照合 (例: "strictly under X" は `<` か `<=` か / "preserves Y" は upstream が Y を trim していないか / "returns Z on W" は実際の戻り値は何か)。 乖離は doc を impl に合わせるか、 設計意図に基づいて impl を doc に合わせる。

例: PR #30 C11/C12 — `carryOverlap` の "kept strictly under overlap" は impl が equality 許容なので「at most overlap」に修正、 `joinUnits` の "preserves original surface text" は SplitSentences が whitespace を trim しているので「reproduces sentence content but not byte-for-byte identical」に修正。

---

## Phase 3: Action (修正方針 → 承認 → 修正 → 再検証)

### 3.1 修正候補整理 (table 形式で提示)

```
## Self-review 結果

| # | file:line | 問題 | 修正方針 | 重要度 |
|---|---|---|---|---|
| 1 | .golangci.yaml:14 | paths 値が部分一致 regex で過剰マッチ | `^gen/` に変更 | 望ましい |
| 2 | cmd/x/main.go:1 | コメント日本語 | 英語に書き換え | 致命的 (memory feedback 違反) |

## 問題なし
- go.mod (module path / go directive 正しい)
- Makefile (ターゲット動作確認済み)
```

重要度: **致命的 / 望ましい / nit** の 3 段階で区別。

### 3.2 ユーザー承認

「進めて」を待つ。selective approval (一部のみ承認) も受け入れる。

### 3.3 修正 Edit (並列)

承認された候補を Edit tool で並列実施。

### 3.4 再検証

修正後の副作用 check:
- `make test`, `make lint` 再実行
- 関連 grep を再走 (修正で別 location に同問題が出ていないか)

---

## 鉄則

1. **Phase 0 の mindset shift を skip しない**: 実装者バイアスを意識的に外す。 「自分の intent」 で読まず、 「外部 reviewer として code とコメントだけ」 で判断
2. **修正方針を先に提示**: 黙って Edit しない
3. **致命的 / 望ましい / nit を区別**: user が取捨選択できるように
4. **memory feedback は関連 entry を中身まで read**: index 行だけで判断しない
5. **Copilot 頻出 11 category を毎回 check** (Phase 2.1): docs accuracy / validation / edge case / cancellation / error contract / 対称性 / doc drift / sentinel 漏洩 / exported func type contract / test trivial pass / slice OOB
6. **対称性 / interface 契約 / test adversarial / doc last-write-wins の 4 機械 check を skip しない** (Phase 2.6-2.9): 真の blindspot は ここに集中する
7. **spec 逸脱は明示・承認・記録**: 暗黙正当化に「prototype だから」を使わない (CLAUDE.md「変更の作法」(指示外の変更の flag))
8. **推測 mapping 禁止**: コメントの cross-reference / 用語対応は原文 literal の範囲だけ
9. **副作用検証**: 修正後にビルド / テスト / lint を再実行
10. **隠さない**: 自分が直前ターンで作ったものでも問題があれば指摘する。 「typical input では起きない」「内部 caller だから OK」を理由に check を skip しない
