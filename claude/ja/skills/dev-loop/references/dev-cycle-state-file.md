# dev-cycle state file template

state file (per-project plans dir の `<ticket-slug>.md`) の構成の SoT。dev-cycle が実装計画導出で書き出し、後続 agent / 再開時の context bootstrap に使う。

```
# <Phase> / <Ticket ID>: <タイトル> — 実装プラン

## Context
なぜこの変更が必要か (DoD ベース)

## Confirmed decisions
確定した literal を列挙。再実装時の参照源、後続 agent が context bootstrap に使う。永続的な設計判断はここに置く。
| 判断項目 | 採用 literal | 根拠 (DoD / docs どちら) |

## Scope decisions (DoD 由来の意図的限定)
DoD で「stub のみで OK」「後続 ticket で実装」と明示されている範囲限定。逸脱ではないので PR description には flag しない。
| 範囲限定項目 | DoD 根拠 | 後続 ticket |

## Spec deviations (PR description で flag、reviewer 確認対象)
DoD / docs と実装で割れる「永続的な構造選択」のみ。reviewer に確認したい項目だけを残す。
| # | 逸脱内容 | 是正方針 (spec update / 維持 / 後日見直し) |

## Phase 2+ migration (follow-up ticket 化)
暫定実装で将来 refactor 予定のもの。follow-up として記録、本 PR では実装しない。
| 暫定実装 | 将来形 | follow-up ticket / link |

## Carryover (既存問題、別 ticket)
scope 外の既存問題で、本 PR では触らないが視認しておきたいもの。
| 既存問題 | 影響範囲 | 対応 ticket |

## Documentation updates (Tier 分類)
docs 突合で抽出した矛盾箇所の Tier 別整理と本 ticket での扱い。
| 対象 doc | 修正内容 | Tier (1/2/3/4) | 扱い (同 commit / 同 PR / 別 ticket) |

## 影響範囲
impact-A/B/C の分類と「対象 symbol → 参照元」の対応表 (実装計画導出の影響範囲調査の出力)

## Current state (随時更新)
進行状態。後続 agent / 再開時に Read 1 回で context bootstrap できるように。
計画段階では「未実施」とだけ書く — 実測前の値・commit sha・PR URL・review 周回数を書かない (template を埋める圧力による捏造防止)。
- Stage X 完了 / Y 進行中 (wip commit と対応)
- 直近 commit: <hash> / test 修正試行カウント: <n>/3
- Pending questions / escalation 停止 (<工程> / <理由>)

## Design review (api-design-review)
実行結果 summary (6 観点の検出有無 / 反映済み / user 判断済み / 残置 follow-up)

## 主要な設計判断
| 判断項目 | 決定 | 根拠 |

## 実装ステップ (実行順)
### Step 1: ...
- 新規 / 編集ファイル + 内容概要

## DoD と実装ステップの対応
| DoD 項目 | 対応 Step | 検証方法 |

## 想定される落とし穴

## 検証手順 (実装完了後)

## 次のチケットへの引き継ぎ (スコープ外)

## 参照
- ticket URL / docs のパス / repo 規約 digest の原本 path
```
