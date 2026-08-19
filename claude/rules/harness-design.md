---
paths:
  - "**/claude/skills/**"
  - "**/claude/agents/**"
  - "**/claude/rules/**"
  - "**/claude/CLAUDE.md"
  - "**/.claude/skills/**"
  - "**/.claude/agents/**"
---

# harness 設計の原則

skills / agents / rules / CLAUDE.md を書く / 直す時の規約。**対象 file を触る時だけ自動ロードされる**。

公式 best practice: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices

## 0. 作る前に — 存在理由の証明

**新規 skill / agent / rule は「実際に起きた摩擦」に紐づく時だけ作る**。想像した要求に対して作らない。

作る前に答える:
1. **この不足で実際に失敗した事例はあるか** (session log / commit / 実作業の記憶)
2. **既存の plugin / builtin で代替できないか** (`superpowers` / `/code-review` / `/simplify` / `/security-review` / builtin agent)
3. **eval を 3 本書けるか** — 書けないなら要求が曖昧。本文より先に eval を書く

**Don't**: 自己改善ループで harness が harness を育てる。実務の摩擦を経ずに増えた要素は使われないまま腐る。

## 1. rules と skills の使い分け

**判定基準は「発火保証が要るか、呼び出し式でよいか」の一点**。

| | rules (`paths` 付き) | skills |
|---|---|---|
| ロード | 対象 file を触ると**全文が確実に**入る | 起動時は name + description のみ。本文は invoke 時 |
| 向く内容 | **規約** — 該当 file を触る限り常に適用されるべきもの | **手順** — user / model が意図して呼ぶもの |
| 例 | Go の命名規約、K8s の manifest 規約、secret の扱い | repo 調査手順、commit & push、session 連携 |

- 規約を skill に置くと**発火せず適用漏れする** (実績あり: Go 規約が skill にあったが適用されなかった)
- 手順を rules に置くと**関係ない作業でも全文が入る**
- `paths` の無い rules は**全 session でロードされる**。毎 session 必要なものだけに限る

## 2. 何をどこに置くか

| 層 | 置き場所 | 中身 | 判定 |
|---|---|---|---|
| global harness | dotfiles → `~/.claude/` | 言語横断の作法 / 汎用手順 | **層名・ディレクトリ名を書いたら失格** |
| project 規約 | 対象 repo の `.claude/` | その repo の layout / build コマンド / commit 規約 / 罠 | 導出コストが高く安定した事実のみ |
| runtime 導出 | どこにも置かない | 構造・コマンド・規約は**毎回 repo から導出する** | 迷ったらここ |

- **project 固有用語を global の agent / skill に hardcode しない**
- **構造前提を書かない** — 「DDD なら `internal/{domain,application}/`」のような記述は、実 repo の構造と噛み合わない時に打ち消せない。「repo の既存 layout を読んで従う」と書く
- **規約が衝突した時の優先順位**: 文体・命名・書式は**対象 repo が勝つ** (global は既定値)。ただし**安全側の壁 (secret / 新規依存 / 破壊的操作 / permission deny) は global が常に勝つ**

## 3. 書く時の原則

- **model が既に持つ知識を書かない** — 一般的な言語作法・広く知られた best practice の再掲は context を食うだけ。書くのは **house の選択・事故になる罠・grep で拾える検出シグナル**に限る
- **同じ規定を 2 箇所に書かない** — SoT を 1 つ決めて他所からは参照する。再掲は必ず乖離する
- **model が自発的にやることを指示に書かない** — 自己検証 / 再チェックの重複指示は cost だけ増やす。検証は実コマンド (build / test / lint / 再 grep) の実行として書く
- **Don't は検出手段とセットで書く** — 「lint が落とす」「grep で拾う (コマンドを書く)」「判断が要る (grep 不可と明記)」の 3 系統に分ける。手段の無い Don't は守られない
- **選択肢を並べない** — default を 1 つ示し、逸脱条件を escape hatch として添える
- **時限情報を書かない** — 「2025 年 8 月以降は〜」は腐る。旧仕様は「Old patterns」section に隔離する
- **用語を統一する** — 同じものを「field」「box」「element」と呼び分けない
- review 系の prompt に「重大度の高いものだけ報告」「保守的に」を書かない (報告が減る)。全件挙げさせ、取捨は後段で行う
- 出力長の抑制は「section 構成 + 行数上限」で機械的に与える (「簡潔に」単独では効かない)

## 4. skill の構造 (公式規約)

**frontmatter は `name` と `description` の 2 field のみ**。独自 field (`when_to_use` 等) を足さない — 「いつ使うか」は description に含める。

| field | 制約 |
|---|---|
| `name` | 64 字以内 / 小文字・数字・hyphen のみ / `anthropic`・`claude` を含めない |
| `description` | 1,024 字以内 / 非空 / **三人称** / **「何をするか」と「いつ使うか」の両方**を書く |

- **name は gerund 形を優先** (`surveying-repos` / `coordinating-sessions`)。noun phrase / action 形も可だが **collection 内で統一する**。`helper` / `utils` / `tools` のような vague 名は禁止
- description は skill 選択の唯一の材料。具体的な trigger 語を含める。「Helps with documents」のような曖昧な記述は発火しない
- **SKILL.md 本文は 500 行以下**。超えるなら `references/` へ分割する
- **`references/` は SKILL.md から 1 階層まで** — reference から更に reference を張ると partial read (`head -100`) されて情報が欠ける
- **100 行を超える reference には冒頭に目次**を置く (partial read されても全体像が見える)
- **分割の判定基準は「常に全部読まれるか」の一点**:
  - 常に全部読まれる → **SKILL.md 内に inline** (分割しても progressive disclosure にならず往復を強いるだけ)
  - 条件分岐で一部しか読まれない → **split** (種別ごと / 言語ごと / 異常系手順など)
- 多段階の手順には**コピー可能な checklist** を置く
- 品質が要る手順には **feedback loop** を書く (validator 実行 → 修正 → 再実行 → green で次へ)
- path は必ず forward slash

## 5. 自由度の設定

手順の壊れやすさに合わせる。

| 自由度 | 使う場面 | 書き方 |
|---|---|---|
| 高 | 複数の正解がある / 文脈で判断が変わる | 散文の手順 |
| 中 | 推奨 pattern はあるが変形を許す | 引数付きの template |
| 低 | 壊れやすい / 順序が critical | 実行するコマンドを固定し「変更するな」と明記 |

## 6. 権限

- 新規 agent / skill / hook に `Bash(*)` 等の広範 permission を default で与えない
- 外部送信を含む skill は user 承認後に追加する
- hook で自動実行される command は user に明示してから commit する
- MCP tool は必ず完全修飾名で書く (`ServerName:tool_name`)

## 7. 検証

新規 / 変更した skill は deploy 前に確認する:

- [ ] frontmatter が `name` / `description` の 2 field のみ、制約を満たす
- [ ] description に「何をするか」と「いつ使うか」の両方があり三人称
- [ ] 本文 500 行以下 / reference は 1 階層 / 100 行超の reference に目次
- [ ] 一般知識の再掲が無い (house の選択・罠・検出シグナルだけ)
- [ ] 構造前提 (層名・ディレクトリ名) を hardcode していない
- [ ] Don't に検出手段が付いている
- [ ] eval を 3 本以上書いた
- [ ] `ls -la ~/.claude/skills` で symlink が解決する
