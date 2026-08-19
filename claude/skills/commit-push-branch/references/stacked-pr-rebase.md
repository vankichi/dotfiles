# 親が squash merge された後の stacked branch 復旧

親が squash merge されると親の全 commit は patch-id が一致しなくなり、`git rebase --onto` は親相当の再適用で衝突する。**commit 単位の rebase を試さない**。目標 tree を確定させて 1 commit に collapse する。

1. `git diff <親 tip> origin/<default>` が**空**であることを確認する (空でなければこの手順は使えない)
2. `git branch backup/<name> <子 tip>` で復旧点を作る
3. `NEW=$(git commit-tree <子 tip>^{tree} -p origin/<default> -F <msg file>)`
4. `git checkout -B <branch> $NEW` (`reset --hard` は使わない)
5. 機械的に検証する:
   - `git diff <子 tip> HEAD` が空 (review 済み head と tree が byte 一致)
   - `git diff origin/<default> HEAD --stat` が想定差分と一致

push は force が必要なため **user の明示指示を待つ**。`--force-with-lease` と backup ref を併せて提示する。
