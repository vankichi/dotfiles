# test-adversarial — Trivial pass の摘出

skip 可: test ファイルの diff が 0。

各 test の assertion について「**実装の挙動を逆にしても pass する mutation はあるか?**」と問う。input に repeated content / 同一値 / nil / empty が含まれる場合は特に注意、`strings.Contains` / `len(got) > 0` / `errors.Is(...)` 系の assertion が trivially 通る経路を探す。

例: PR #30 C7 — 80 個の同一 sentence repeat で carry-over の overlap を `strings.Contains` で check → carry-over が壊れても trivially true。distinct marker (`[文NNN]`) を入れて `HasPrefix` で boundary 検証する形が正解。

あわせて test 内の slice 操作 (`slice[len-N:]`) に `len >= N` guard があるか、input が短い時に panic しないかを確認する。
