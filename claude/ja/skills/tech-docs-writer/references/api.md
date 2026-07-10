# API仕様書テンプレート (OpenAPI 3.1 の考え方に基づく Markdown)

OpenAPIのYAML/JSONをそのまま出力するのではなく、人間が読める日本語のMarkdown API仕様書を作る。ただし情報粒度は OpenAPI 3.1 に揃えることで、必要になったときに機械可読形式へ変換しやすくする。

## 必須ヒアリング項目

- APIの種類 (REST / gRPC / GraphQL)
- サービス名・バージョン
- Base URL (環境ごと: 開発/ステージング/本番)
- 認証方式 (Bearer Token / API Key / mTLS / OAuth2 / なし)
- 対象エンドポイント一覧 (最低1つ)
- 各エンドポイントのパラメータ/リクエスト/レスポンスの形
- エラー体系 (共通エラーレスポンス形式、ステータスコード方針)
- レート制限の有無

不明点が多い場合はまずエンドポイント1本を完成させ、テンプレートを示してから残りを埋めるアプローチを提案する。

## テンプレート本文

```markdown
# <サービス名> API 仕様書

- **バージョン**: v1.0.0
- **最終更新**: YYYY-MM-DD
- **オーナー**: <チーム名>

## 概要

<このAPIの目的を3〜5文で。解決する課題と主要ユースケース。>

## 環境

| 環境 | Base URL |
|------|----------|
| 開発 | `https://api-dev.example.com` |
| ステージング | `https://api-stg.example.com` |
| 本番 | `https://api.example.com` |

## 認証

<認証方式とトークン取得手順>

```http
Authorization: Bearer <token>
```

## 共通仕様

### リクエストヘッダ

| ヘッダ | 必須 | 説明 |
|--------|------|------|
| `Authorization` | ✓ | 認証トークン |
| `Content-Type` | ✓ | `application/json` |
| `X-Request-ID` | - | トレース用UUID (省略時はサーバで採番) |

### エラーレスポンス

全エンドポイント共通:

```json
{
  "error": {
    "code": "INVALID_ARGUMENT",
    "message": "人間向けメッセージ",
    "details": []
  }
}
```

| HTTPステータス | code | 意味 |
|---------------|------|------|
| 400 | `INVALID_ARGUMENT` | リクエストパラメータ不正 |
| 401 | `UNAUTHENTICATED` | 認証情報なし/不正 |
| 403 | `PERMISSION_DENIED` | 権限不足 |
| 404 | `NOT_FOUND` | リソースなし |
| 409 | `CONFLICT` | 競合 |
| 429 | `RESOURCE_EXHAUSTED` | レート制限 |
| 500 | `INTERNAL` | サーバ内部エラー |

### レート制限

- <制限値>。超過時は `429` と `Retry-After` ヘッダを返却。

## エンドポイント

### <リソース名>

#### `POST /v1/<resource>`

<1行の要約>

##### リクエスト

```http
POST /v1/<resource> HTTP/1.1
Host: api.example.com
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "string",
  "count": 0
}
```

| フィールド | 型 | 必須 | 説明 | 制約 |
|-----------|-----|------|------|------|
| `name` | string | ✓ | リソース名 | 1〜64文字 |
| `count` | integer | - | 個数 | 0以上, 既定値0 |

##### レスポンス (200 OK)

```json
{
  "id": "res_01HXXXX",
  "name": "example",
  "count": 0,
  "created_at": "2026-04-21T12:00:00Z"
}
```

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `id` | string | ULID |
| `name` | string | 入力と同じ |
| `count` | integer | 入力と同じ |
| `created_at` | string (RFC3339) | 作成時刻 |

##### エラー

| ステータス | code | 条件 |
|-----------|------|------|
| 400 | `INVALID_ARGUMENT` | `name` が空 / 長さ超過 |
| 409 | `CONFLICT` | 同名のリソースが既に存在 |

##### 備考

<冪等性キーの扱い、リトライ推奨条件、関連エンドポイントなど>

#### `GET /v1/<resource>/{id}`

...(同じ構造で記述)...

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| YYYY-MM-DD | v1.0.0 | 初版 |
```

## 書き方のコツ

1. エラーは"起こりうるもの"に絞って列挙。`500` を全エンドポイントに列挙するのは情報量ゼロ。そのエンドポイント固有のエラー条件を書く。
2. リクエスト/レスポンスは必ず具体例(JSON)を併記する。スキーマ表だけだと誤読される。
3. 日時は RFC3339 / タイムゾーンを必ず明示。`2026-04-21T12:00:00Z` のように。
4. gRPCの場合は `.proto` のservice/method単位で見出しを切り、リクエスト/レスポンスのmessage定義を併記する。

## 保存先

- REST: `docs/api/<service-name>.md` または `docs/api/<resource>.md`
- 複数エンドポイントがある場合は `docs/api/<service>/<resource>.md` と階層化

## 参考

- OpenAPI 3.1 仕様: https://spec.openapis.org/oas/v3.1.0
