# Runbook テンプレート (Google SRE Playbook スタイル)

Runbookはオンコール当番が深夜3時に読む前提で書く。冗長な背景説明は不要で、判断と操作がすぐ取れる構造にする。

## 必須ヒアリング項目

- アラート名 / 症状 (Symptom)
- 重大度 (SEV / P1〜P5 など社内基準)
- 影響範囲 (ユーザー影響 / 内部影響のみ)
- 確認すべきダッシュボード / ログクエリのURL
- 暫定対応 (Mitigation) の候補
- 根本対応 (Resolution) のオーナー
- エスカレーション先 (チーム/個人/Slack channel)

Mitigation が1つも決まっていない状態でRunbookは書かない。「とりあえず再起動」も立派なMitigationなので、ヒアリングで必ず引き出す。

## テンプレート本文

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

## 書き方のコツ

1. Diagnosis は"上から順にやれば切り分く"順序で書く。思考の遠回りを作らない。
2. コマンドは実行可能な形で貼る。`<name>` プレースホルダがあってもよいが、何を入れるかは直前に書く。
3. Mitigation には副作用を必ず書く。副作用不明な操作を深夜に打たせない。
4. Resolution と Mitigation を混同しない。Mitigation は止血、Resolution は根治。
5. 更新を怠らない。Alertmanagerのルール名変更、K8s namespace変更などで陳腐化する。アラート発火のたびに差分を反映するくらいで丁度よい。

## アラートルールからの自動起こし

`PrometheusRule` などから出発する場合、以下を `Symptom` と `Diagnosis` の初期案にする:

- `alert:` 値 → Runbookタイトル
- `expr:` → Diagnosis の「メトリクス確認」ステップの基礎
- `annotations.summary` / `description` → Symptom 本文
- `annotations.runbook_url` が空なら、このRunbookのURLを埋める提案を行う

## 保存先

- `docs/runbook/<alertname-or-topic>.md`
- アラートルールと1対1対応が望ましい (大きくなってきたらグループ化)

## 参考

- Google SRE Workbook - On-Call: https://sre.google/workbook/on-call/
