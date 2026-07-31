# 検証済み断定 (verify-before-assert)

機械的に検証可能な事実の断定は、検証コマンドの実行後にのみ書く。対象は docs / ADR / comment / PR 記述 / user・subagent への報告の全て。書く側 (dev-cycle の各工程 / review-orchestrator / retrospect の insight 記述) は本ファイルを SoT とし、各所で手順を再掲しない。

## 断定の種別と検証手順

| 種別 | 検証手順 (書く前に実行) |
|---|---|
| code の機構 (型 / NULL 可否 / 呼び出し順 / 排他 / 冪等性 / 誰が不変条件を担保するか) | 該当 file を Read し、主張と file:line を突き合わせる。読んでいない経路の機構は書かない |
| 量化子 (唯一 / 常に / 必ず / のみ / 無条件 / 〜に限られる) | その量化子が成立する経路を全て列挙してから書く。列挙できないなら量化子を落とし、確認済み経路の事実だけを書く |
| 定量 (行数 / 件数 / 割合 / N 倍 / いつ誰が作ったか) | 測定コマンド (`git diff --numstat` / `grep -c` / `wc` 等) を実行し、主張に測定コマンドを併記する |
| git の ahead / behind | `git fetch` 後に `git rev-list --count A..B` を両方向 (または `git merge-base --is-ancestor`) で数値確定する。`git status` の "Recent commits" / `git log` の見た目から推測しない |
| 参照 (section 番号 / 手順名 / file path) | 参照先の実在を grep で確認する |

## 運用

- **subagent の定量・機構主張も同格**: relay (報告 / insight / escalation 資料への転記) の前に自分で同じ検証を実行する。1 行のコマンドで確かめられる事実を未検証のまま人間の判断材料に載せない
- **review 提出前の doc 散文 pass**: 自分が書いた散文に対し上表の該当種別の検証を review spawn 前に一巡させる。実装 (build / test / lint) が green でも散文が未検証なら review に出さない
- 検証は grep / Read / コマンドの実行として行う。「確認した」の自己申告で代替しない
