---
name: deriving-repo-conventions
description: 未知の repo の layout / build・test・lint コマンド / commit 規約 / 貢献 flow を実測から導出し、検証したうえで project-local な .claude/CLAUDE.md に定着させる手順。初めて触る repo での作業開始時、「この repo の規約を調べて」「.claude にまとめて」「層構造どうなってる」時、および記録済みの規約が実態と合わなくなった時に使用する。既知の architecture pattern を実物確認なしに当てはめないための gate でもある。
---

# repo 規約の導出

**構造を推測しない**ための手順。既知 pattern (DDD / clean architecture / 標準 Go layout) を当てはめて外すのが最大の事故なので、全て実測から起こす。

## 手順

```
- [ ] 1. 書き込み先の安全確認
- [ ] 2. layout の導出
- [ ] 3. コマンドの導出と実行検証
- [ ] 4. commit / 貢献規約の導出
- [ ] 5. 記録
```

### 1. 書き込み先の安全確認

```bash
git check-ignore -v .claude && echo "untracked OK" || echo "TRACKED — 要確認"
```

`.claude` が gitignore されていなければ、書いた内容が repo に commit され得る。**upstream に PR する fork では特に危険**。tracked になる場合は user に確認してから進む。

### 2. layout の導出

言語ごとの実体を数え、**多い順に実際のディレクトリを見る**。

```bash
find . -name '*.go' -not -path './.git/*' | sed 's|/[^/]*$||' | sort | uniq -c | sort -rn | head -15
```

`domain` / `application` / `adapters` のような**層名を探しに行かない**。無い repo のほうが多い。あったと書く前に `find` の結果に実在することを確認する。

複数言語なら全て出す (Rust の `crates/` と Go の `controller/` が同居する等)。

### 3. コマンドの導出と実行検証

出所は `Makefile` / `justfile` / `package.json` / `Taskfile` / CI workflow の順に探す。

```bash
grep -E '^[a-z][a-z0-9_/-]*:' Makefile | head -30
ls .github/workflows/
```

**導出したコマンドを実際に実行する**。通らないコマンドを規約として記録すると、以降の全 session が壊れた前提で動く。

- 通った → 記録する
- 通らない / 時間がかかりすぎる → **記録しないか「未検証」と明記する**。憶測を確定形で書かない
- codegen (`make gen` 等) は副作用があるため、実行せず**存在と用途だけ**記録する

### 4. commit / 貢献規約の導出

```bash
git log --oneline -30
ls CONTRIBUTING.md CODEOWNERS .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null
git remote -v && git branch --show-current
```

commit message の prefix 形式 (`fix:` / `feat(scope):` / emoji 等) は **実際の log から読む**。自分の他 repo の習慣を持ち込まない。

fork かどうか (`remote` が upstream と別) は PR 先が変わるため必ず確認する。

### 5. 記録

`.claude/CLAUDE.md` に書く。**既存 file があれば読んでから差分だけ更新**し、人間が書いた記述を消さない。

```markdown
# <repo 名>

## layout
- <実在するディレクトリ> — <役割>

## コマンド
| 用途 | コマンド | 検証 |
|---|---|---|
| build | `<cmd>` | 実行確認済み / 未検証 |

## commit / PR
- message 形式: <log から読んだ実例>
- fork か: <upstream の有無と PR 先>

## 罠
- <実際に踏んだもののみ>
```

**「罠」に想像を書かない**。実際に踏んだものだけ。

repo 固有だが file 種別ごとにしか要らない規約は `.claude/rules/<topic>.md` に `paths:` 付きで分ける (該当 file を触った時だけロードされる)。

## 実測と記録が食い違った時

**停止して報告する**。記録を黙って書き換えない。第一仮説は「記録が古い」だが、確定するのは user。回避策で埋めて進まない。
