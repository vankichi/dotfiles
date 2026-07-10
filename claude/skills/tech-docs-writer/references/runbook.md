# Runbook Template (Google SRE Playbook style)

> **Source of truth:** `claude/ja/skills/tech-docs-writer/references/runbook.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

Write the Runbook assuming the on-call engineer reads it at 3am. Verbose background explanations are unnecessary; structure it so decisions and actions can be taken immediately.

## Required interview items

- Alert name / symptom
- Severity (SEV / P1-P5, or your internal standard)
- Scope of impact (user-facing impact / internal impact only)
- Dashboard / log query URLs to check
- Candidate mitigations
- Owner of the root-cause resolution
- Escalation target (team / individual / Slack channel)

Do not write a Runbook with zero mitigations decided. Even 「とりあえず再起動」 (just restart it for now) counts as a legitimate mitigation, so make sure to draw one out during the interview.

## Template body

```markdown
# Runbook: <アラート名 or 症状>

- **重大度**: SEV<N> / P<N>
- **オーナーチーム**: <team>
- **最終更新**: YYYY-MM-DD
- **関連アラート**: `<AlertmanagerのalertnameまたはダッシュボードURL>`

## Symptom (症状)

<何が見えたらこのRunbookを開くか。アラート文・ダッシュボード上の見え方・ユーザー報告の典型文を具体的に。>

例:
- Alertmanager: `HighErrorRate` が firing
- Grafana `<url>` で 5xx率 が 5%超

## Impact (影響)

- **ユーザー影響**: <例: APIレスポンスが失敗する。影響対象は全ユーザー/特定機能>
- **内部影響**: <例: 非同期ジョブが遅延>
- **SLO影響**: <例: 可用性SLOに対して X%消費する見込み>

## Diagnosis (診断手順)

原因の切り分けをチェックリスト形式で。上から順に実施。

1. **依存サービスのステータス確認**
   - コマンド: `kubectl get pods -n <ns>`
   - 見るもの: `Running` 以外のPodがないか
2. **直近デプロイの有無**
   - `kubectl rollout history deployment/<name> -n <ns>`
   - 直前30分以内のデプロイがあれば §Mitigation の「ロールバック」を優先
3. **外部依存の障害**
   - <依存サービスのステータスページURL>
4. **リソース逼迫**
   - ダッシュボード: <url>
   - CPU/メモリ/コネクション数を確認

## Mitigation (暫定対応)

原因が切り分けできていなくても、ユーザー影響を止めるための手を列挙。**副作用を明記**。

### A. ロールバック (直近デプロイが原因の場合)

```bash
kubectl rollout undo deployment/<name> -n <ns>
```

- 所要時間: 2〜3分
- 副作用: 新機能は一時的に使えなくなる

### B. 対象Podの再起動

```bash
kubectl rollout restart deployment/<name> -n <ns>
```

- 所要時間: 1〜5分
- 副作用: 処理中リクエストが中断される可能性

### C. トラフィックを別リージョンに寄せる

```bash
<コマンド or 手順>
```

- 所要時間: 1分
- 副作用: レイテンシが増える

## Resolution (根本対応)

<恒久対応の方針。Mitigation後にオーナーチームで行う作業。>
<該当Issue/PRがあればリンクを張る。>

## Verification (復旧確認)

- [ ] Grafana `<url>` のエラー率が通常範囲に戻っている (5分間継続)
- [ ] アラートが resolved になっている
- [ ] 関連するカナリア/合成監視が成功している

## Escalation (エスカレーション)

- **Primary**: `#team-<name>` Slack (<slack-url>)
- **Secondary**: `#oncall-<service>` に `@here` で投稿
- **30分経過しても収束しない場合**: SREチーム `#sre-oncall`

## Postmortem

- SEV2以上の場合、収束後24時間以内に postmortem を開始する
- テンプレート: <postmortem-template-url>

## 変更履歴

| 日付 | 変更内容 | 変更者 |
|------|---------|--------|
| YYYY-MM-DD | 初版 | <name> |
```

## Writing tips

1. Write Diagnosis in an order such that "working through it top to bottom narrows down the cause." Don't create mental detours.
2. Paste commands in an executable form. It's fine to have `<name>` placeholders, but state what to fill in immediately before the command.
3. Always document side effects for each Mitigation. Don't make someone run an operation with unknown side effects in the middle of the night.
4. Don't conflate Resolution with Mitigation. Mitigation stops the bleeding; Resolution cures the underlying cause.
5. Don't neglect updates. Renaming Alertmanager rules, changing K8s namespaces, and similar changes make a Runbook stale. Reflecting the diff every time the alert fires is about the right cadence.

## Auto-drafting from alert rules

When starting from a `PrometheusRule` or similar, use the following as the initial draft for `Symptom` and `Diagnosis`:

- `alert:` value → Runbook title
- `expr:` → basis for the Diagnosis "check metrics" step
- `annotations.summary` / `description` → Symptom body text
- If `annotations.runbook_url` is empty, propose filling it in with this Runbook's URL

## Save location

- `docs/runbook/<alertname-or-topic>.md`
- A 1:1 correspondence with the alert rule is preferable (group them once things grow large)

## References

- Google SRE Workbook - On-Call: https://sre.google/workbook/on-call/
