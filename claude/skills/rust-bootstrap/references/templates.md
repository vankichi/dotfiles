> **Source of truth:** `claude/ja/skills/rust-bootstrap/references/templates.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# rust-bootstrap file templates

A collection of file templates corresponding to the step numbers in SKILL.md. Replace the placeholders (`<name>` / `<license>` / `<repo-url>` / `<user>` / `<one-line>`) with the values confirmed in Step 0.

## Step 2: workspace `Cargo.toml`

A virtual workspace at the root (no `[package]`). Centralize metadata for all crates with `[workspace.package]`:

```toml
[workspace]
resolver = "3"
members = ["crates/*"]

[workspace.package]
edition = "2024"
rust-version = "1.90"
license = "<license>"            # e.g., "MIT" or "MIT OR Apache-2.0"
authors = ["<user>"]
repository = "<repo-url>"
homepage = "<repo-url>"
keywords = ["cli"]
categories = ["command-line-utilities"]
publish = false                  # do not publish to crates.io

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

**If building a TUI**, add to `[workspace.dependencies]`:

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

## Step 4: The first crate (`crates/<name>/`)

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

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

build: ## Debug build (all crates in the workspace)
	cargo build --workspace --all-targets

release: ## Release build (lto=fat / panic=abort)
	cargo build --workspace --release --locked

test: ## Run tests (all crates in the workspace)
	cargo test --workspace --all-targets --locked

clippy: ## clippy (-D warnings)
	cargo clippy --workspace --all-targets --all-features -- -D warnings

fmt-check: ## Check formatting
	cargo fmt --all -- --check

fmt: ## Apply formatting
	cargo fmt --all

check: ## Compile check only
	cargo check --workspace --all-targets --locked

deny: ## Supply-chain audit (requires cargo-deny)
	cargo deny check

ci: fmt-check clippy test ## fmt-check + clippy + test all at once

install: release ## Release build → copy to $(PREFIX) (default: ~/.local/bin)
	@mkdir -p $(PREFIX)
	@for crate in crates/*/; do \
		name=$$(basename $$crate); \
		cp target/release/$$name $(PREFIX)/$$name; \
		if [ "$$(uname)" = "Darwin" ]; then \
			codesign --force --sign - $(PREFIX)/$$name >/dev/null 2>&1; \
		fi; \
		echo "installed $$name -> $(PREFIX)/$$name"; \
	done

uninstall: ## Remove binaries from $(PREFIX)
	@for crate in crates/*/; do \
		name=$$(basename $$crate); \
		rm -f $(PREFIX)/$$name; \
		echo "removed $(PREFIX)/$$name"; \
	done

clean: ## Remove build artifacts
	cargo clean

update: ## Update Cargo.lock
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

## Step 12: Root `README.md`

A simplified version including a tools table:

```markdown
# <repo>

A Cargo workspace of small terminal tools.

## Tools

| Crate | Description |
|---|---|
| [`<name>`](crates/<name>) | <one-line> |

## Build & install

\```sh
make help                # all recipes
make ci                  # fmt-check + clippy + test
make install             # release build → ~/.local/bin/
make install PREFIX=/opt/homebrew/bin
make uninstall
\```

If `~/.local/bin` is not on your PATH, add
`export PATH="$HOME/.local/bin:$PATH"` to `~/.zshrc` or similar.

## Adding a new tool

1. Create `crates/<new-name>/Cargo.toml` inheriting from workspace
2. Add a row to the table above
3. Confirm that `make ci` passes
```

## Step 13: Content appended to CLAUDE.md's "Development commands" section

```markdown
## Development commands

| Command | Purpose |
|---|---|
| `make` (= `make help`) | List of recipes |
| `make ci` | fmt-check + clippy + test |
| `make release` | Release build (`lto = "fat"`, `panic = "abort"`) |
| `make install` | Copy all crates to `$(PREFIX)` (default: `~/.local/bin`) |
| `make install PREFIX=/opt/homebrew/bin` | Change the install destination |
| `make uninstall` | Remove the installed binaries |
| `make deny` | Supply-chain audit (`cargo deny check`, requires `cargo install cargo-deny`) |

When adding a new crate, use the `/add-rust-crate` skill.
```
