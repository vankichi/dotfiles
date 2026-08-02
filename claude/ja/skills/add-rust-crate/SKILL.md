---
name: add-rust-crate
description: 既存 Rust workspace に新 crate を追加する (Cargo.toml の workspace 継承 / CLI・TUI・lib 雛形 / README 表更新 / 必要なら workspace.dependencies 追加)。
when_to_use: 既存の Rust workspace に新しい crate を 1 つ足す時。「crate 追加して」「workspace に <name> を足して」。
---

# add-rust-crate

`rust-bootstrap` で作った workspace (or それ相当) に **新しい crate を 1 つ追加**する skill。何度でも使う。`crates/<name>/` を生やすだけのつもりでも、TUI 雛形・現代的な依存パターン・README 表更新までは決まりごとなので skill 化する。

> **Snapshot**: 2026-04 / Rust 1.95 / clap 4 / ratatui 0.30 / crossterm 0.29 / tokio 1 を前提。
> ratatui は API が比較的速く動くので、`ratatui::init` / `EventStream` / `recv_many` が
> その時点の推奨か (book / changelog) は流用前に確認すること。

## 適用条件

- ルートに `[workspace] members = ["crates/*"]` を持つ Rust workspace が既にある
- `[workspace.package]` で edition / license / repository などが集中管理されている
- `[workspace.dependencies]` に共通 dep が登録されている

未満たしなら先に `/rust-bootstrap` を呼ぶよう促す。

## 手順

### Step 0: 前提確認

```bash
test -f Cargo.toml && grep -q '\[workspace\]' Cargo.toml && echo "workspace OK"
ls crates/ 2>/dev/null
grep -A 30 '\[workspace.package\]' Cargo.toml
grep -A 30 '\[workspace.dependencies\]' Cargo.toml
```

`AskUserQuestion` で 1 ターンに集約:
- crate 名 (snake_case ではなく `kebab-case` 推奨。例: `mytool`)
- crate 種別 (`bin` / `tui` / `lib`)
- 1 行説明 (`Cargo.toml` の `description` と README の説明に使う)
- 追加で必要な dep があれば (`workspace.dependencies` に未登録のもの)

**種別が `tui` のときは `references/tui.md` を Read してから進める** (雛形・key 処理パターン・mpsc ingest パターンが入っている)。

### Step 1: 既存 crate との衝突チェック

```bash
test -d crates/<name> && echo "ALREADY EXISTS — abort"
grep -q "^name = \"<name>\"" crates/*/Cargo.toml && echo "NAME COLLISION — abort"
```

衝突したら user に別名を提案。

### Step 2: `workspace.dependencies` 拡張 (必要時のみ)

新 dep が必要なら、ルート `Cargo.toml` の `[workspace.dependencies]` に追記:

```toml
<new-dep> = { version = "X", features = ["..."] }
```

TUI 初導入時の追加 dep は `references/tui.md` 参照。既に登録されているなら何もしない (重複追加禁止)。

### Step 3: `crates/<name>/Cargo.toml`

workspace から全部継承:

```toml
[package]
name = "<name>"
version = "0.1.0"
description = "<one-line>"
edition.workspace = true
rust-version.workspace = true
license.workspace = true
authors.workspace = true
repository.workspace = true
homepage.workspace = true
keywords.workspace = true
categories.workspace = true
publish.workspace = true

[[bin]]                          # bin / tui のみ
name = "<name>"
path = "src/main.rs"

[dependencies]
anyhow.workspace = true
clap.workspace = true
# 種別に応じて追加 (下記 Step 4 参照)

[dev-dependencies]
tempfile.workspace = true

[lints]
workspace = true
```

`lib` 種別なら `[[bin]]` を消し、`src/lib.rs` を作る。

### Step 4: `src/main.rs` (種別別雛形)

#### `bin` (CLI)

```rust
//! <name> — <description>

use anyhow::Result;
use clap::Parser;

#[derive(Parser, Debug)]
#[command(name = "<name>", version, about)]
struct Cli {
    // 引数
}

fn main() -> Result<()> {
    let _cli = Cli::parse();
    Ok(())
}
```

#### `tui`

`references/tui.md` の雛形 (main.rs / app.rs / dependencies) を使う。ポイントだけ再掲:
- `ratatui::init()` / `ratatui::restore()` を使い、自前で `enable_raw_mode` 等を書かない
- key 入力は `EventStream` を `tokio::select!` に入れる (`poll(0)` 禁止)
- キーが 3 種以上に増えたら `classify_key` enum パターンに移行 (unit test 可能になる)

#### `lib` (内部共有 crate)

`Cargo.toml`:

```toml
[lib]
path = "src/lib.rs"
```

`src/lib.rs`:

```rust
//! <name> — <description>

#![warn(missing_docs)]
```

ライブラリは `pub` 公開を意識し、`#[must_use]` / `Debug` derive をきちんと付ける (バイナリより厳しめ)。

### Step 5: ルート README の tools 表更新

```markdown
| Crate | Description |
|---|---|
| [`<name>`](crates/<name>) | <description> |
```

既存の表に行を追加するだけ。アルファベット順を保つ。

### Step 6: `crates/<name>/README.md` (任意)

公開予定 (`publish = true`) なら個別 README を書く。個人 toolkit ならルート README に集約でよい。

### Step 7: 動作確認

```bash
. "$HOME/.cargo/env"
cargo build -p <name>                                && echo BUILD_OK
cargo test -p <name>  --all-targets                  && echo TEST_OK
cargo clippy -p <name> --all-targets -- -D warnings  && echo CLIPPY_OK
cargo fmt -p <name> -- --check                       && echo FMT_OK
```

TUI なら起動も:

```bash
cargo run -p <name> --release   # 'q' で終了
```

### Step 8: 完了報告

| 項目 | 状況 |
|---|---|
| crate 名 / 種別 | <値> |
| `crates/<name>/Cargo.toml` (workspace inheritance) | ✓ |
| `src/main.rs` (or `src/lib.rs`) | ✓ |
| `[workspace.dependencies]` 追加 dep | <値 or なし> |
| ルート README 表 | ✓ |
| `cargo build` / `test` / `clippy -D warnings` / `fmt --check` | ✓ |

## 鉄則

1. **workspace inheritance を必ず使う**: `*.workspace = true` で version / license / lints 全部
2. **`pub(crate)` から始める**: バイナリ crate は外部公開がない。`pub` は本当に外に出す lib のみ
3. **TUI は `ratatui::init` / `restore` + `EventStream`**: 自前で `enable_raw_mode` / `poll(0)` を書かない
4. **`workspace.dependencies` 重複追加禁止**: 既存があるか先に確認
5. **`scope を守る`**: 業務ロジック実装は対象外。骨格 + 1 つの動く `main` までで止める
6. **コミットしない**: 別 skill (`/commit-push-branch`) に委ねる

## アンチパターン

- crate 側 `Cargo.toml` に `version = "..."` / `license = "..."` をベタ書き
- TUI で `enable_raw_mode` + `EnterAlternateScreen` を自前実装 (`ratatui::init` を使う)
- `crossterm::event::poll(Duration::from_millis(0))` を async loop に書く (`EventStream` を `tokio::select!` に入れる)
- `mpsc::Receiver::recv` + `try_recv` ドレインの自前実装 (`recv_many(&mut buf, N)` 1 行)
- 1 crate 追加のために workspace ルートを大改造 (それは `rust-bootstrap` の仕事)
- README の表更新を忘れる (新 tool が discover されない)
