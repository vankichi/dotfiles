# rust-bootstrap file templates

SKILL.md の Step 番号に対応するファイルテンプレート集。placeholder (`<name>` / `<license>` / `<repo-url>` / `<user>` / `<one-line>`) は Step 0 の確認値で置換する。

## Step 2: workspace `Cargo.toml`

ルートに virtual workspace (`[package]` なし)。`[workspace.package]` で全 crate のメタを集中管理:

```toml
[workspace]
resolver = "3"
members = ["crates/*"]

[workspace.package]
edition = "2024"
rust-version = "1.90"
license = "<license>"            # 例: "MIT" or "MIT OR Apache-2.0"
authors = ["<user>"]
repository = "<repo-url>"
homepage = "<repo-url>"
keywords = ["cli"]
categories = ["command-line-utilities"]
publish = false                  # crates.io 公開しない

[workspace.dependencies]
anyhow = "1"
# `env` feature lets `#[arg(env = "FOO")]` fall back to env var when CLI flag absent.
clap = { version = "4", features = ["derive", "env"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tokio = { version = "1", features = ["fs", "rt-multi-thread", "macros", "sync", "time", "io-util"] }
tempfile = "3"

[workspace.lints.rust]
unsafe_code = "forbid"

[workspace.lints.clippy]
pedantic = { level = "warn", priority = -1 }
module_name_repetitions = "allow"
missing_errors_doc = "allow"
missing_panics_doc = "allow"

# Distribution-grade release profile.
[profile.release]
lto = "fat"
codegen-units = 1
strip = "symbols"
panic = "abort"
opt-level = 3
incremental = false

[profile.dist]
inherits = "release"
```

**TUI を作るなら** `[workspace.dependencies]` に追加:

```toml
crossterm = { version = "0.28", features = ["event-stream"] }
ratatui = "0.29"
futures = "0.3"
```

## Step 3: `rust-toolchain.toml`

```toml
[toolchain]
channel = "stable"
components = ["rustfmt", "clippy"]
```

## Step 4: 最初の crate (`crates/<name>/`)

`crates/<name>/Cargo.toml`:

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

[[bin]]
name = "<name>"
path = "src/main.rs"

[dependencies]
anyhow.workspace = true
clap.workspace = true

[dev-dependencies]
tempfile.workspace = true

[lints]
workspace = true
```

`crates/<name>/src/main.rs`:

```rust
//! <name> — <one-line description>

use anyhow::Result;
use clap::Parser;

#[derive(Parser, Debug)]
#[command(name = "<name>", version, about)]
struct Cli {}

fn main() -> Result<()> {
    let _cli = Cli::parse();
    Ok(())
}
```

## Step 5: `rustfmt.toml`

```toml
edition = "2024"
max_width = 100
use_field_init_shorthand = true
use_try_shorthand = true
```

## Step 6: `Makefile`

```makefile
.DEFAULT_GOAL := help

# Override: `make install PREFIX=/opt/homebrew/bin`
PREFIX ?= $(HOME)/.local/bin

.PHONY: help build release test clippy fmt-check fmt check deny ci install uninstall clean update

help: ## このヘルプを表示
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

build: ## デバッグビルド (workspace 全 crate)
	cargo build --workspace --all-targets

release: ## リリースビルド (lto=fat / panic=abort)
	cargo build --workspace --release --locked

test: ## テスト実行 (workspace 全 crate)
	cargo test --workspace --all-targets --locked

clippy: ## clippy (-D warnings)
	cargo clippy --workspace --all-targets --all-features -- -D warnings

fmt-check: ## フォーマット確認
	cargo fmt --all -- --check

fmt: ## フォーマット適用
	cargo fmt --all

check: ## コンパイル確認のみ
	cargo check --workspace --all-targets --locked

deny: ## supply-chain 監査 (要 cargo-deny)
	cargo deny check

ci: fmt-check clippy test ## fmt-check + clippy + test 一括

install: release ## release build → $(PREFIX) にコピー (default: ~/.local/bin)
	@mkdir -p $(PREFIX)
	@for crate in crates/*/; do \
		name=$$(basename $$crate); \
		cp target/release/$$name $(PREFIX)/$$name; \
		if [ "$$(uname)" = "Darwin" ]; then \
			codesign --force --sign - $(PREFIX)/$$name >/dev/null 2>&1; \
		fi; \
		echo "installed $$name -> $(PREFIX)/$$name"; \
	done

uninstall: ## $(PREFIX) からバイナリ削除
	@for crate in crates/*/; do \
		name=$$(basename $$crate); \
		rm -f $(PREFIX)/$$name; \
		echo "removed $(PREFIX)/$$name"; \
	done

clean: ## ビルド成果物削除
	cargo clean

update: ## Cargo.lock 更新
	cargo update
```

## Step 7: `deny.toml` (cargo-deny)

```toml
[graph]
all-features = true

[advisories]
version = 2
yanked = "deny"
ignore = []

[licenses]
version = 2
allow = [
    "MIT", "MIT-0", "Apache-2.0", "Apache-2.0 WITH LLVM-exception",
    "BSD-2-Clause", "BSD-3-Clause", "ISC",
    "Unicode-3.0", "Unicode-DFS-2016", "Zlib", "CC0-1.0", "MPL-2.0",
]
confidence-threshold = 0.93

[bans]
multiple-versions = "warn"
wildcards = "deny"
deny = []

[sources]
unknown-registry = "deny"
unknown-git = "deny"
allow-registry = ["https://github.com/rust-lang/crates.io-index"]
```

## Step 8: `.cargo/config.toml`

```toml
[target.'cfg(all(target_env = "msvc", target_os = "windows"))']
rustflags = ["-C", "target-feature=+crt-static"]

[alias]
ci = "test --workspace --all-targets --locked"
xclippy = "clippy --workspace --all-targets --all-features -- -D warnings"
```

## Step 9: `.github/workflows/ci.yml`

```yaml
name: ci
on:
  push: { branches: [main] }
  pull_request:

permissions:
  contents: read

env:
  CARGO_TERM_COLOR: always
  RUST_BACKTRACE: 1

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with: { components: rustfmt, clippy }
      - uses: Swatinem/rust-cache@v2
      - run: cargo fmt --all --check
      - run: cargo clippy --workspace --all-targets --all-features -- -D warnings
  test:
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
        with: { shared-key: ${{ matrix.os }} }
      - run: cargo test --workspace --all-targets --locked
      - run: cargo build --workspace --release --locked
  deny:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: EmbarkStudios/cargo-deny-action@v2
```

## Step 12: ルート `README.md`

tools 表を含む簡易版:

```markdown
# <repo>

A Cargo workspace of small terminal tools.

## Tools

| Crate | Description |
|---|---|
| [`<name>`](crates/<name>) | <one-line> |

## Build & install

\```sh
make help                # 全レシピ
make ci                  # fmt-check + clippy + test
make install             # release build → ~/.local/bin/
make install PREFIX=/opt/homebrew/bin
make uninstall
\```

`~/.local/bin` が PATH に通っていない場合は `~/.zshrc` 等に
`export PATH="$HOME/.local/bin:$PATH"` を追加。

## Adding a new tool

1. Create `crates/<new-name>/Cargo.toml` inheriting from workspace
2. Add a row to the table above
3. `make ci` が通ることを確認
```

## Step 13: CLAUDE.md「開発コマンド」追記分

```markdown
## 開発コマンド

| コマンド | 用途 |
|---|---|
| `make` (= `make help`) | レシピ一覧 |
| `make ci` | fmt-check + clippy + test |
| `make release` | release ビルド (`lto = "fat"`, `panic = "abort"`) |
| `make install` | 全 crate を `$(PREFIX)` へコピー (default: `~/.local/bin`) |
| `make install PREFIX=/opt/homebrew/bin` | install 先を変更 |
| `make uninstall` | install したバイナリを削除 |
| `make deny` | supply-chain audit (`cargo deny check`、要 `cargo install cargo-deny`) |

新 crate を追加するときは `/add-rust-crate` skill を使う。
```
