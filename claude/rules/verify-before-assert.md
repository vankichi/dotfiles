# 検証済み断定 (verify-before-assert)

機械的に検証可能な事実の断定は、検証コマンドの実行後にのみ書く。対象は docs / ADR / comment / PR 記述 / user・subagent への報告の全て。書く側 (dev-cycle の各工程 / reviewer / retrospect の insight 記述) は本ファイルを SoT とし、各所で手順を再掲しない。

## 断定の種別と検証手順

| 種別 | 検証手順 (書く前に実行) |
|---|---|
| code の機構 (型 / NULL 可否 / 呼び出し順 / 排他 / 冪等性 / 誰が不変条件を担保するか) | 該当 file を Read し、主張と file:line を突き合わせる。読んでいない経路の機構は書かない |
| 量化子 (唯一 / 常に / 必ず / のみ / 無条件 / 〜に限られる) | その量化子が成立する経路を全て列挙してから書く。列挙できないなら量化子を落とし、確認済み経路の事実だけを書く |
| 定量 (行数 / 件数 / 割合 / N 倍 / いつ誰が作ったか) | 測定コマンド (`git diff --numstat` / `grep -c` / `wc` 等) を実行し、主張に測定コマンドを併記する |
| git の ahead / behind | `git fetch` 後に `git rev-list --count A..B` を両方向 (または `git merge-base --is-ancestor`) で数値確定する。`git status` の "Recent commits" / `git log` の見た目から推測しない |
| 参照 (section 番号 / 手順名 / file path) | 参照先の実在を grep で確認する |
| sweep の完了 (除去した / 残りは N 件 / 0 件になった) | **削除対象の全表記形を含むパターン**で grep し、結果を主張に転記する。`ADR-0012` だけで数えて `docs/adr/0012-....md` 形式を取りこぼす類の狭い pattern を receipt にしない |
| 同一 doc / 同一 PR 内の他 section が所有する事実 | その事実の **owner section を開いて突き合わせる**。code と一致していても他 section と矛盾すれば誤り。突き合わせ先を書けない主張は書かない |

## 運用

- **subagent の定量・機構主張も同格**: relay (報告 / insight / escalation 資料への転記) の前に自分で同じ検証を実行する。1 行のコマンドで確かめられる事実を未検証のまま人間の判断材料に載せない
- **review 提出前の doc 散文 pass**: 自分が書いた散文に対し上表の該当種別の検証を review spawn 前に一巡させる。実装 (build / test / lint) が green でも散文が未検証なら review に出さない
- **receipt の scope は主張の scope と一致させる**: 検証コマンドが主張より狭い範囲しか見ていないなら receipt にならない。「除去した」には全表記形の grep、定量には報告直前の再測定 (記憶や前 round の値を書かない)、状態には「まだやっていないこと」を先書きしない
- **自己点検は「自分の文を読み直す」ではなく「突き合わせ先を開く」**: 読み直しは元の誤りと同じ盲点 (他 section を見ていない) を再生産する。各主張について owner の section / code を開く工程として実行する
- **再掲を作らないことが最も安い予防**: 他 section が所有する事実は再掲せず pointer にする。再掲がある限り 1 箇所の編集ごとに「今見ていない箇所」との矛盾が生まれ、claim-vs-claim 照合の負債が残り続ける
- 検証は grep / Read / コマンドの実行として行う。「確認した」の自己申告で代替しない
