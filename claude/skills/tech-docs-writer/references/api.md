# API Specification Template (Markdown based on OpenAPI 3.1 concepts)

> **Source of truth:** `claude/ja/skills/tech-docs-writer/references/api.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

Rather than outputting OpenAPI YAML/JSON directly, this produces a human-readable Japanese Markdown API specification. However, the granularity of information is aligned with OpenAPI 3.1, making it easy to convert to a machine-readable format when needed.

## Required interview items

- API type (REST / gRPC / GraphQL)
- Service name and version
- Base URL (per environment: development / staging / production)
- Authentication method (Bearer Token / API Key / mTLS / OAuth2 / none)
- List of target endpoints (at least 1)
- Parameter / request / response shape for each endpoint
- Error scheme (common error response format, status code policy)
- Whether rate limiting applies

If many points are unclear, propose an approach where you first complete one endpoint, show the template, and then fill in the rest.

## Template body

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

## Writing tips

1. List only errors that "can actually occur." Listing `500` for every endpoint carries zero information. Write the error conditions specific to that endpoint.
2. Always include a concrete example (JSON) alongside the request/response. A schema table alone is easily misread.
3. Always specify date-times in RFC3339 with an explicit timezone, e.g., `2026-04-21T12:00:00Z`.
4. For gRPC, break headings down by `.proto` service/method, and include the request/response message definitions alongside them.

## Save location

- REST: `docs/api/<service-name>.md` or `docs/api/<resource>.md`
- If there are multiple endpoints, organize hierarchically as `docs/api/<service>/<resource>.md`

## References

- OpenAPI 3.1 specification: https://spec.openapis.org/oas/v3.1.0
