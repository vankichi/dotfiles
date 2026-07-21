# correctness — Copilot 頻出 11 category + 機械 check

skip 可: code diff が 0 (docs / config のみの変更)。

## Copilot 頻出 11 category (PR #26 + PR #30 の累計 26 件 review 分析より集約)

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
| 6 | **Symmetric constructor defense** | constructor 1 つに guard 追加したら、同 PR 内の他 constructor も同じ guard を持つか (下記「対称性 audit」で機械的 check) |
| 7 | **Doc/impl literal drift** | strong claim ("strictly", "preserves", "Returns X") を含む comment を impl と byte-level で照合 (下記「Doc last-write-wins」) |
| 8 | **Sentinel-on-error 漏洩** | 依存 interface が 0 / "" / nil / -1 を error 経路で返す契約か godoc 確認、consumer 側で defense (下記「Interface 契約 trace」) |
| 9 | **Exported function type contract** | `type X func(...) error` を export、docstring が "all options X" と claim → custom 実装も同じ contract を満たすか、factory で wrap |
| 10 | **Test assertion trivially passes** | repeated fixture content / loose `Contains` / nil-only check (詳細は references/test-adversarial.md) |
| 11 | **Slice OOB / panic guard (test)** | test 内 `slice[len-N:]` の N 直前に `len >= N` guard、input が短い時の panic |

## Rebut パターン (false positive の識別)

project context 上「適用不可」と判断して resolve するパターン:

- **Go 1.22+ loop variable shadow**: `go.mod` の go directive が 1.22+ なら shadow 不要
- **internal port boundary defense 再提案**: SD で撤回した場合、PR description を referenced して resolve
- **同じ警告の重複投稿**: 別 test に同 pattern が当てはまらない場合は false positive と明示

## 機械 check 1: 対称性 audit (Symmetric defense)

差分で追加した guard / validation / nil check と同種の対称対象 (`grep "^func New" $(git diff --name-only)` で同 PR 内 constructor 全列挙、`opts ...Option` を受ける関数も grep) が同じ guard を持つか確認、欠落があれば flag。

例: PR #30 C9 — `ports.NewChunkSpec` に nil opt reject を入れたら `chunker.New` の opts も同じ guard が必要 (1 箇所 fix で他を見逃した教訓)。

## 機械 check 2: Interface 契約 trace (Sentinel / Exported type)

変更 file 内で使った external interface の godoc を再 read、**戻り値の sentinel ケース** (0 / "" / nil / -1 / 特定 error sentinel) と consumer 側の分岐 (`if x <= X`, `errors.Is(...)`) で flow が一致するか確認。exported function type を export しているなら、docstring の "all" / "always" claim が custom 実装にも保たれるか、factory で normalize しているか check。

例: PR #30 C10 — `chunking.Tokenizer.CountTokens` は encoding error 時に 0 を返す、consumer の `tokens <= MaxTokens` 判定でこの 0 が「fits」と誤判定されないよう defense 必要。C13 — exported `ChunkSpecOption` の custom 実装が contract を破る経路を factory で wrap。

## 機械 check 3: Doc last-write-wins (コメント update 漏れ摘出)

実装変更後、変更 file 内の全コメントを疑って再 read。strong claim を grep (`grep -nE "(strictly|preserves|guarantees|ensures|always|never|returns|panics)"`)、各 claim を impl の literal 動作と byte-level で照合 (例: "strictly under X" は `<` か `<=` か / "preserves Y" は upstream が Y を trim していないか)。乖離は doc を impl に合わせるか、設計意図に基づいて impl を doc に合わせる。

例: PR #30 C11/C12 — `carryOverlap` の "kept strictly under overlap" は impl が equality 許容なので「at most overlap」に修正、`joinUnits` の "preserves original surface text" は SplitSentences が whitespace を trim しているので「reproduces sentence content but not byte-for-byte identical」に修正。

## 機械 check 4: 外部定数の権威検証 (hardcoded external constants)

差分に外部由来の hardcoded 定数 (LLM pricing / model ID / API rate limit / 第三者サービスの定数) が含まれる場合、port 元・memory・既存コードとの一致確認で済ませず、**authoritative source で数値そのものを検証**する。Anthropic の pricing / model ID の SoT は claude-api skill (「LLM pricing は memory で答えない」trigger をコードレビュー文脈でも適用)。

例: ccwatch から port した Opus レート $15/$75 は port 元と byte 一致だったが、現行レートは $5/$25 で 3x 過大計上 (2026-07-17 FB。「port 元と一致」は正当性の根拠にならない)。
