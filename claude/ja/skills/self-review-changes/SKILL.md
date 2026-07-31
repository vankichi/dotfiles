---
name: self-review-changes
description: 直前の編集差分 (作業ツリー or staged) を観点別に self-review する skill。10 観点の checklist を本ファイル 1 枚に持ち、diff 内容で機械的に発火する (default-on + 理由付き skip)。対話時は修正方針を提示し user 承認後に Edit。loop-mode では `reviewer` agent が本 checklist を読んで適用する。「self review して」「review して」「修正箇所ないか確認して」等で使う。
---

# self-review-changes

編集差分を観点別に再走査し、修正候補を洗い出す skill。**観点 checklist の SoT は本ファイル** — 対話時の self-review と loop-mode の `reviewer` agent が同じ checklist を共有する。

> **plugin との使い分け**: `/code-review`・`/simplify` は diff の bug / 簡素化に特化。本 skill は設定の正確性 / docs 整合 / memory 規約整合 / spec 整合まで含む広域 review。

## 適用条件

- 何らかのファイル編集が直前ターンで行われている (commit 前 or 直近 commit 後)
- 修正対象範囲が `git diff` で見える

## 手順

1. **外部 reviewer として読む**: 「自分の intent」ではなく「初めてこの code を見た人間」として読む。コメントは binding contract。「こう意図した」「typical input では起きない」「内部 caller だから OK」は禁句。wire form / nil / empty / 境界値 / cancellation 中 / 不正 spec を adversarial に想定する
2. **差分把握**: `git status` / `git diff [--cached]` (直近 commit 後は `git show HEAD`) → 全変更 file を Read (Bash の `cat` ではなく)
3. **関連情報**: `MEMORY.md` の関連 feedback / project entry を中身まで read。対応する spec / work item があれば取得
4. **観点適用**: 下記 10 観点を skip 条件に従って適用
5. **SoT 突合 (finding 報告前の必須 step)**: 指摘対象について (a) spec / ticket の禁止事項・Out of Scope、(b) design doc の該当節、(c) DB schema / 型定義コメントの不変条件 を grep で確認。**突合で矛盾する finding は報告しない**。これは事実照合であり severity 絞りではない
6. **統合レポート出力** → 承認 → Edit → build / test / lint 再実行 + 関連 grep 再走 (同問題の他 location への波及確認)

## 観点 (default-on。skip は下記の機械的条件を満たす時のみ、理由付きで)

### correctness — skip: code diff 0
- **入力検証**: public API (`WithXxx` / `NewXxx` / handler 引数) で 0 / 負値 / nil / empty / traversal を check。validation は constructor 末尾に配置
- **edge case**: wire form の parameters 付き (MIME は `mime.ParseMediaType`) / `strings.TrimSpace` 後の empty / batch 全要素 fail / empty 出力
- **ctx**: `ctx.Deadline` 尊重 / 不要な goroutine spawn 回避 / `ctx.Err()` を都度 check / **最深部まで伝播** (pre-processing loop も含む)
- **error 契約**: sentinel の意味契約 (transient vs permanent) / 4xx は retry しない / boundary error の port-level wrap
- **slice OOB**: `slice[len-N:]` の直前に `len >= N` guard

### filetype-checks — skip: なし
- **Go**: `gofmt` / `goimports` / godoc 規約 (`// Package <name>` / `// FuncName ...`) / `fmt.Errorf("...: %w", err)` / ctx が第一引数 / 不要 export
- **設定 (`.golangci.yaml` / Makefile / yaml / json)**: 形式バージョン (golangci-lint v1 vs v2) / regex glob (`gen` 中間一致 vs `^gen/` ルート限定) / インデント
- **Markdown**: 相対 link / code fence の言語指定 / 表セル数の一貫性 / heading 階層
- **Shell / Makefile / Dockerfile**: shell injection (`$VAR` のクォート) / 危険コマンド (`rm -rf`, `curl | sh`)
- **Proto**: package / option / field number / 後方互換 (`buf breaking`)

### conventions — skip: なし
- memory 規約への適合: 用語規約 / 文書スタイル / コメント言語 (`*.go`・Makefile・proto・shell は英語) / commit message スタイル
- **一時情報の混入**: `ticket`, `in a later`, `future ticket`, `see (commit|PR) #`, ticket ID 形式。検査 pattern の literal は project の `MEMORY.md` から取得し skill 側に hardcode しない
- **cross-reference 実在確認**: コメント内の section 参照の引用語彙が原文と一致するか
- **推測 mapping**: 原文に書かれていない対応関係をコメントで補完していないか

### spec-alignment — skip: 対応する spec / work item が無い
- **逆引き紐付け**: 差分の全変更を spec のどのセクション / DoD 項目に対応するか逆引き
- **DoD 未充足**: 各 DoD 項目に対応する変更 + 検証手段が揃っているか。未充足は列挙
- **scope creep**: どのセクションにも紐付かない変更 = 指示外変更。non-goals に触れる変更は**致命的** (loop-mode では自動修正せず escalation)
- spec doc 自体を編集した場合は、spec 中の literal (型名 / enum / field) と実装側の同 surface を両方 grep し、逸脱ごとに「理由」「是正方針 (a) 仕様に合わせる / (b) 仕様 update / (c) 別 ADR」を添える

### test-adversarial — skip: test ファイルの diff 0
- 各 assertion に「**実装の挙動を逆にしても pass する mutation はあるか?**」と問う
- input に repeated content / 同一値 / nil / empty が含まれる場合は特に注意。`strings.Contains` / `len(got) > 0` / `errors.Is(...)` が trivially 通る経路を探す
- 例: 同一 sentence を 80 回 repeat した input で carry-over を `strings.Contains` 検証 → carry-over が壊れても true。distinct marker + `HasPrefix` で boundary を検証する形が正解

### performance — skip: code diff 0
profile は取らず静的に疑い箇所を flag (基準の詳細は `~/.claude/rules/performance.md`)。
- **計算量**: 追加 loop の nest が O(n²) 以上でないか / 既存 O(n) 経路を劣化させていないか
- **I/O**: loop 内の逐次 I/O (N+1 query / 1 件ずつの API call) を batch 化・事前 fetch できないか
- **hot path allocation**: loop 内の slice/map 生成・string 連結・`fmt.Sprintf` / `strings.Builder` や事前 capacity の検討
- **同期**: 粗すぎる lock 範囲 / 並列化できる独立処理の直列実行

### observability — skip: 新規 code path 無し (docs / config / test のみ)
- 新規の error 経路・分岐に、運用時「何が起きたか」を特定できる log があるか (正常系の冗長 log は逆に flag)
- error message だけで「どの入力で / どこで / 次に何を見るか」が分かるか。context (id / key / 件数) が wrap されているか
- **PII / secret の混入**: log / error message / metric label に PII・token・接続文字列・ticket 本文の転記が無いか (**致命的**)
- 常駐 process / 定期実行 / 外部呼び出しを追加した場合、成功・失敗・所要時間が観測できるか (metrics 基盤がある repo のみ)

### ops-docs-hazard — skip: `docs/runbook/**` の変更が無く、かつ docs の追加行に shell command の code fence が無い
「文章として正しいか」ではなく「**この手順を文字通り実行した運用者が誤った / 破壊的な行動を取らないか**」で読む。code 系観点が code diff 0 で skip されるため、docs 専用変更ではここが唯一の防波堤。
- **影響 scope の明記**: 各 command が 単一対象 / 全件 / 不可逆 のどれか本文で判別できるか。明記が無い command は**致命的**
- **破壊的 command**: 不可逆 command が明示禁止か guard 付きか。別節の記述から不可逆 command へ読み手が辿り着く経路が生まれていないか
- **前提の充足性**: 必要権限 / 時間の窓 / 実行順序 / 事前状態 が手順内で満たせるか。別 doc にしか無いなら link があるか
- **行き止まり**: 提示した代替手段・次の step が実在するか (存在しない command / 未実装の機能を「こうする」と書いていないか)
- **禁止・警告の実効性**: 禁止対象が実際にその挙動を決める knob を指しているか
- **再課金 / 副作用**: 再実行が外部 API の再課金や重複処理を招くなら、その旨と回避条件があるか
- **量化子の反例**: 「唯一 / 常に / 必ず / のみ」等の全称表現ごとに反例経路を 1 つ探す (`~/.claude/rules/verify-before-assert.md`)

### dependency — skip: 依存ファイル (go.mod / go.sum / package.json / lock 系 / import 行) の diff 0
- **新規依存の検出**: 追加を列挙。**新規依存は user 承認必須** (CLAUDE.md 行動原則)。loop-mode では検出 = 即 escalation
- version 更新が意図的か (指示外の lock file 変動は flag) / typosquat・install script 持ちでないか / 間接依存の膨張 / licence の矛盾

### code-quality — skip: code diff 0
bug 検出ではなく「より良い書き方」の観点。
- **重複 / reuse**: 同等の helper / util が repo 内に既存でないか grep。同型処理を 2 箇所以上に書いていないか
- **簡素化**: 不要な中間変数 / 深い nest (early return で平坦化) / 過剰な抽象化 (1 実装しかない interface)
- **命名 / altitude**: 挙動と名前の一致、repo 既存語彙との一貫性。関数内の抽象度が揃っているか
- **コメント**: 「何をするか」の自明コメント・PR 向け説明コメントは削除対象。書くべきは「code に書けない制約」のみ
- **定数**: 式中の magic number / 2 回以上出現する同一 literal が named const か。関連定数が const block にまとまっているか
- **同一 PR 内の一貫性**: 導入した命名 / const / helper を diff で再 grep し「片方だけ named const」型の取りこぼしを検出
- 規約の詳細は `go-style` / `go-test` / `ddd-clean-architecture` が SoT

## 機械 check (correctness の補強。grep で実行する)

1. **対称性 audit**: 差分で追加した guard / validation / nil check について、同種の対称対象 (`grep "^func New" $(git diff --name-only)` で同 PR 内 constructor を全列挙、`opts ...Option` を受ける関数も grep) が同じ guard を持つか確認。1 箇所だけ直して他を見逃す型の見落としを潰す
2. **interface 契約 trace**: 変更 file で使った external interface の godoc を再 read し、戻り値の sentinel ケース (0 / "" / nil / -1 / 特定 error) と consumer 側の分岐 (`if x <= X`, `errors.Is(...)`) で flow が一致するか確認。例: `CountTokens` が encoding error 時に 0 を返す → consumer の `tokens <= MaxTokens` が「fits」と誤判定する
3. **doc last-write-wins**: 実装変更後、変更 file 内の strong claim を grep (`grep -nE "(strictly|preserves|guarantees|ensures|always|never|returns|panics)"`) し、各 claim を impl の literal 動作と byte-level で照合 ("strictly under X" は `<` か `<=` か 等)。乖離は doc を impl に合わせるか、設計意図に基づき impl を doc に合わせる
4. **外部定数の権威検証**: 差分に外部由来の hardcoded 定数 (LLM pricing / model ID / API rate limit) がある場合、**authoritative source で数値そのものを検証**する。「port 元と byte 一致」は正当性の根拠にならない。Anthropic の pricing / model ID の SoT は `claude-api` skill

## false positive の識別

project context 上「適用不可」と判断して resolve してよいパターン:
- Go 1.22+ の loop variable shadow (`go.mod` の go directive が 1.22+ なら不要)
- SD で撤回済みの internal port boundary defense の再提案 (PR description を参照して resolve)
- 同じ警告の重複投稿 (別 test に同 pattern が当てはまらない場合)

## 出力形式

```
## Self-review 結果

| 観点 | 実施/skip (理由) | 発見 |
|---|---|---|
| correctness | 実施 | 2 件 |
| dependency | skip (依存ファイル diff 0) | - |
...

| # | file:line | 問題 | 修正方針 | 重要度 |
|---|---|---|---|---|
| 1 | cmd/x/main.go:1 | コメント日本語 | 英語に書き換え | 致命的 (memory 規約違反) |

## 問題なし
- <確認したが問題なかった対象>
```

重要度は **致命的 / 望ましい / nit** の 3 段階。

## 鉄則

1. **全観点の実施状況を必ず表で出力**: 黙った skip 禁止。skip は機械的条件 + 理由付きのみ
2. **severity で事前に絞らず全件挙げてから 3 段階に分類する** (「重大なものだけ」の絞り込みは報告そのものを減らす)
3. **memory は関連 entry を中身まで read**: index 行だけで判断しない
4. **隠さない**: 自分が直前ターンで作ったものでも問題があれば指摘する
