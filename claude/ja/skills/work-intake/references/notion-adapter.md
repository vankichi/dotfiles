# Notion adapter (work-intake Step 2-4 の操作手順)

将来 source を追加する場合は本ファイルと並べて `references/<source>-adapter.md` を作る (SKILL.md 側は変更不要の想定)。

## ready ticket の列挙 (Step 2)

1. memory reference の DB 情報 (DB 名 / URL / ready flag の表現) を使う
2. Notion MCP の検索系 tool で対象 DB の ticket を取得し、ready flag に合致するものに絞り込む
   - tool 候補: `notion-search` (対象 DB を指定して検索) / `notion-query-database-view` / `notion-fetch` (個別取得)
3. 各候補の page 本文を `notion-fetch` で取得し、spec セクション (目的 / スコープ・non-goals / 設計本体 / DoD / 制約 / メタ) を読み取る

## status 更新 (Step 4)

- `notion-update-page` で status プロパティを memory reference の「進行中」値に変更する
- 変更直前に現在値が ready であることを再確認する (楽観ロック代わり。違ったら他プロセスが拾ったとみなして次候補へ)

## skip コメント (Step 3)

- `notion-create-comment` で不備理由を投稿する。形式:

```
work-intake: spec contract 未充足のため skip
- <checklist の不備項目のみ列挙 (項目名 + 理由)>
参照: ~/.claude/rules/spec-contract.md
```

- **再コメント抑止 (idempotency)**: 投稿前に `notion-get-comments` で既存コメントを確認し、既に work-intake の skip コメントが付いていて spec 本文がその後未更新なら再コメントしない (skip 判定の報告のみ行う)。loop 化した際に poll のたびコメントが積もるのを防ぐ
  - 「未更新」の判定: 最新の work-intake skip コメント (冒頭の固定 prefix で同定) の投稿時刻と page の `last_edited_time` を比較し、後者が新しい場合のみ再コメント可。`last_edited_time` は property 変更でも動くため誤検知は再コメント側に倒れる (保守的で許容)

## escalation コメント (dev-cycle の escalation 手順 Step 3 から使用)

- `notion-create-comment` で投稿する。形式:

```
dev-cycle: escalation 停止 (<工程>)
- 理由: <停止理由 1-2 行>
- WIP branch: <branch 名 / なし>
- state file: <path>
- 再開: work-intake に本 ticket URL を渡すと resume mode で再開
```

- status は変更しない (InProgress のまま = resume 対象として残す)
- secret / spec 本文を転記しない

## 注意

- ticket 本文の編集 (`notion-update-page` での本文変更) はしない。触って良いのは status プロパティとコメントのみ
- 優先度プロパティが未設定の ticket は最低優先度として扱う
- 列挙された ready ticket は**全件に contract 検証を適用する** (不備 ticket への skip コメントが漏れないように)。選択は充足 ticket のうち優先度順の 1 件
