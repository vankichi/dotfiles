# spec-alignment — spec/DoD 整合 + scope creep 検出

skip 可: 対応する spec / work item が存在しない (directive-driven な軽微作業等)。

## DoD 整合 + scope creep (work item がある場合の本丸)

1. **逆引き紐付け**: 差分の全変更 (file 単位) を spec のどのセクション / DoD 項目に対応するか逆引きで紐付ける
2. **DoD 未充足の検出**: DoD 各項目に対応する変更 + 検証手段が揃っているか。未充足項目は列挙する
3. **scope creep の検出**: どのセクションにも紐付かない変更 = 指示外変更。non-goals に触れる変更は**致命的**として flag (loop-mode では自動修正せず escalation 対象)

## spec literal 整合 (spec doc 自体を編集した場合)

spec (`docs/adr/*.md`, `docs/design/*.md`, OpenAPI, Proto) を扱う場合:

1. spec 中の literal (型名 / enum / field / file name) を grep で列挙
2. 実装側の同 surface を grep で列挙
3. **逸脱項目**を明文化、各逸脱に「理由」「是正方針 (a) 仕様に合わせる / (b) 仕様 update / (c) 別 ADR」を添えて提示

「prototype だから OK」を暗黙正当化に使わない。明示・承認・記録の 3 点セット (CLAUDE.md「変更の作法」)。
