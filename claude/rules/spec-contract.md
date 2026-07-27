# spec contract — 人間と agent の唯一の契約

work-intake / dev-cycle は本 contract を満たす work item だけを自律 pipeline に入れる。
write-spec skill は人間の設計 draft が本 contract を満たすまで補佐する。
ready flag を立てるのは人間のみ。

## 必須セクション

| # | セクション | 記入基準 | NG 例 |
|---|---|---|---|
| 1 | 目的 / 背景 | なぜやるかを 1 段落。解決したい問題 or 得たい価値を明記 | 「〜を改善する」だけで対象が不明 |
| 2 | スコープ / non-goals | non-goals (今回やらないこと) を最低 1 項目明記 | non-goals が空 |
| 3 | 設計本体 | アーキ / API 契約 / データモデル。変更対象が repo 内のどこか特定できる粒度 | 「いい感じに実装」 |
| 4 | DoD (受け入れ条件) | 各項目が機械検証可能 (test / lint / 具体的動作)、または検証手順が書ける | 「動くこと」 |
| 5 | 制約 | security / performance / 新規依存の可否を明記 (該当なしなら「なし」と書く) | 未記載 |
| 6 | メタ | 対象 repo / 優先度 / ready flag | repo 不明 |

## 検証 checklist (write-spec / work-intake 共通)

検証時は**全項目の判定を必ず出力する** (満たす / 満たさない + 理由。黙った skip 禁止):

- [ ] 必須セクション 1-6 が全て存在する
- [ ] non-goals が 1 項目以上ある
- [ ] DoD の各項目に検証手順 (コマンド or 手順) が紐付いている
- [ ] 制約セクションに新規依存の可否が明記されている
- [ ] 対象 repo が実在する path / URL で特定できる
- [ ] 設計の未決事項 (「A か B か検討」等) が残っていない — 残っている場合 ready 不可
- [ ] DoD に example / test 表がある場合、各 input→expected を設計本体の算法に 1 行ずつ通して矛盾がない (non-goals との整合を含む)
- [ ] DoD の期待値が opaque (hash / checksum / 符号化 blob 等、目視比較不能) の場合、算法出力からの再計算と一致する — 不一致の golden は機械的に満たせない DoD であり ready 不可
- [ ] spec が「挙動不変 / 既存 test をそのまま green」を要求しつつ、**同じ shared code path に対する新しい内部挙動 (処理順序等) を別途指定していない** — 併存する場合は自己矛盾であり ready 不可 (実装側の tie-break は regression-guarded 側の優先)
- [ ] spec の literal (識別子 / 配置 path / 処理順序) を lint rule・層規約・design doc と **grep で照合済み** — 照合していない literal は spec に書かない
- [ ] 変更領域に触れる ADR / design doc を列挙し、spec との矛盾を cross-check した (doc 同士が矛盾する場合は SoT 階層で正を決める)
- [ ] DoD 各項目の**検証実行者と環境が実在する** (AWS 権限 / 別 repo 管轄 / live 環境が必要なものは agent が実行できない) — 実行不能なものは「human 検証 follow-up」欄へ分離し、機械検証可能な DoD と混ぜない
- [ ] DoD に **failure mode / 並行性 / 冪等性**の 3 欄がある (該当なしなら「なし」と明記) — 正常系のみの DoD は非機能の空白を実装後の review 指摘に持ち越す

## ready の意味

- ready = 人間が「この spec の通りに実装されたら受け入れる」と宣言した状態
- ready を立てられるのは人間のみ。write-spec は提案まで
- **ready flag の SoT は source 側の DB property** (Notion の status 等)。spec 本文への ready 記載は不要で、書かれていても参照扱い (stale し得る)
- ready 後の spec 変更は契約変更 — dev-cycle が着手済みの場合は escalation する
- **ready gate は自律 pipeline の入口 (work-intake) にのみ適用する**。対話 mode (人間が ticket を直接渡す実行) は対象外 — 人間の直接指示が起点であり、承認は対話の各所 (ExitPlanMode 等) で取る

## 置き場所

- 第一弾: Notion ticket (対象 DB / ready flag の表現は MEMORY.md の reference memory から取得する。本ファイルに hardcode しない)
- source を GitHub Issue 等に変えても本 contract は不変
