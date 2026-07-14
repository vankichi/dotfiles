# observability — 運用可観測性

skip 可: 新規 code path なし (docs / config / test のみの変更)。

- **log の有無**: 新規の error 経路 / 分岐に、運用時に「何が起きたか」を特定できる log があるか (正常系の冗長 log は逆に flag)
- **error message の actionable さ**: message だけで「どの入力で / どこで / 次に何を見るべきか」が分かるか。context (id / key / 件数) が wrap されているか
- **PII / secret の混入**: log / error message / metric label に PII・token・接続文字列・ticket 本文の丸ごと転記が入っていないか (**致命的**)
- **metric / trace**: 常駐 process / 定期実行 / 外部呼び出しを追加した場合、成功・失敗・所要時間が観測できるか (repo に metrics 基盤がある場合のみ。なければ flag せず注記)
