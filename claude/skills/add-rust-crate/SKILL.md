---
name: add-rust-crate
description: Adds a new crate to an existing Rust workspace (workspace inheritance in Cargo.toml / CLI, TUI, and lib skeletons / README table update / adding to workspace.dependencies if needed). Used for things like 「workspace に新 crate 追加」「<name> という tool を生やして」「新しい binary crate 切って」.
when_to_use: When adding a single new crate to an existing Rust workspace. Triggers like 「crate 追加して」「workspace に <name> を足して」.
---

# add-rust-crate

> **Source of truth:** `claude/ja/skills/add-rust-crate/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

A skill that **adds one new crate** to a workspace created by `rust-bootstrap` (or an equivalent one). Used repeatedly. Even though it might seem like just spinning up `crates/<name>/`, things like the TUI skeleton, modern dependency patterns, and README table updates are fixed conventions, so this is turned into a skill.

> **Snapshot**: Assumes 2026-04 / Rust 1.95 / clap 4 / ratatui 0.30 / crossterm 0.29 / tokio 1.
> Since ratatui's API moves relatively fast, verify (via the book / changelog) whether
> `ratatui::init` / `EventStream` / `recv_many` are still the recommended approach at that point in time before reusing them.

## Applicability

- A Rust workspace already exists at the root with `[workspace] members = ["crates/*"]`
- `edition` / `license` / `repository`, etc. are centrally managed via `[workspace.package]`
- Common dependencies are registered in `[workspace.dependencies]`

If these aren't met, prompt the user to call `/rust-bootstrap` first.

## Procedure

### Step 0: Check prerequisites

```bash
test -f Cargo.toml && grep -q '\[workspace\]' Cargo.toml && echo "workspace OK"
ls crates/ 2>/dev/null
grep -A 30 '\[workspace.package\]' Cargo.toml
grep -A 30 '\[workspace.dependencies\]' Cargo.toml
```

Consolidate into one `AskUserQuestion` turn:
- Crate name (recommend `kebab-case` rather than snake_case; e.g. `mytool`)
- Crate kind (`bin` / `tui` / `lib`)
- One-line description (used for the `description` in `Cargo.toml` and the README description)
- Any additional dependencies needed (ones not yet registered in `workspace.dependencies`)

**When the kind is `tui`, Read `references/tui.md` before proceeding** (it contains the skeleton, key-handling patterns, and the mpsc ingest pattern).

### Step 1: Check for conflicts with existing crates

```bash
test -d crates/<name> && echo "ALREADY EXISTS — abort"
grep -q "^name = \"<name>\"" crates/*/Cargo.toml && echo "NAME COLLISION — abort"
```

If there's a conflict, suggest a different name to the user.

### Step 2: Extend `workspace.dependencies` (only if needed)

If a new dependency is needed, append it to `[workspace.dependencies]` in the root `Cargo.toml`:

```toml
<new-dep> = { version = "X", features = ["..."] }
```

For the additional dependencies needed when introducing TUI for the first time, see `references/tui.md`. If it's already registered, do nothing (do not add duplicates).

### Step 3: `crates/<name>/Cargo.toml`

Inherit everything from the workspace:

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

[[bin]]                          # bin / tui only
name = "<name>"
path = "src/main.rs"

[dependencies]
anyhow.workspace = true
clap.workspace = true
# add depending on the kind (see Step 4 below)

[dev-dependencies]
tempfile.workspace = true

[lints]
workspace = true
```

For the `lib` kind, remove `[[bin]]` and create `src/lib.rs`.

### Step 4: `src/main.rs` (skeleton by kind)

#### `bin` (CLI)

```rust
//! <name> — <description>

use anyhow::Result;
use clap::Parser;

#[derive(Parser, Debug)]
#[command(name = "<name>", version, about)]
struct Cli {
    // arguments
}

fn main() -> Result<()> {
    let _cli = Cli::parse();
    Ok(())
}
```

#### `tui`

Use the skeleton in `references/tui.md` (main.rs / app.rs / dependencies). Key points restated here:
- Use `ratatui::init()` / `ratatui::restore()`; don't write `enable_raw_mode` etc. yourself
- For key input, put `EventStream` into `tokio::select!` (`poll(0)` is forbidden)
- Once there are 3 or more kinds of keys, move to the `classify_key` enum pattern (this makes it unit-testable)

#### `lib` (internal shared crate)

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

For a library, be conscious of `pub` exposure, and properly attach `#[must_use]` / `Debug` derives (stricter than for a binary).

### Step 5: Update the tools table in the root README

```markdown
| Crate | Description |
|---|---|
| [`<name>`](crates/<name>) | <description> |
```

Just add a row to the existing table. Keep alphabetical order.

### Step 6: `crates/<name>/README.md` (optional)

If it's planned for publication (`publish = true`), write a dedicated README. For a personal toolkit, it's fine to consolidate into the root README.

### Step 7: Verify it works

```bash
. "$HOME/.cargo/env"
cargo build -p <name>                                && echo BUILD_OK
cargo test -p <name>  --all-targets                  && echo TEST_OK
cargo clippy -p <name> --all-targets -- -D warnings  && echo CLIPPY_OK
cargo fmt -p <name> -- --check                       && echo FMT_OK
```

For a TUI, also launch it:

```bash
cargo run -p <name> --release   # quit with 'q'
```

### Step 8: Completion report

| Item | Status |
|---|---|
| Crate name / kind | <value> |
| `crates/<name>/Cargo.toml` (workspace inheritance) | ✓ |
| `src/main.rs` (or `src/lib.rs`) | ✓ |
| Additional dependencies added to `[workspace.dependencies]` | <value or none> |
| Root README table | ✓ |
| `cargo build` / `test` / `clippy -D warnings` / `fmt --check` | ✓ |

## Golden rules

1. **Always use workspace inheritance**: use `*.workspace = true` for version / license / lints, all of it
2. **Start with `pub(crate)`**: binary crates have no external exposure. Use `pub` only for a lib that is genuinely exposed externally
3. **TUI uses `ratatui::init` / `restore` + `EventStream`**: don't write `enable_raw_mode` / `poll(0)` yourself
4. **No duplicate additions to `workspace.dependencies`**: check first whether it already exists
5. **Stay in scope**: business logic implementation is out of scope. Stop at the skeleton plus one working `main`
6. **Do not commit**: committing is delegated to a separate skill (`/commit-push-branch`)

## Anti-patterns

- Hardcoding `version = "..."` / `license = "..."` in the crate's own `Cargo.toml`
- Implementing `enable_raw_mode` + `EnterAlternateScreen` yourself for a TUI (use `ratatui::init`)
- Writing `crossterm::event::poll(Duration::from_millis(0))` in an async loop (put `EventStream` into `tokio::select!`)
- Implementing your own `mpsc::Receiver::recv` + `try_recv` drain loop (use `recv_many(&mut buf, N)` in one line instead)
- Overhauling the workspace root just to add one crate (that's `rust-bootstrap`'s job)
- Forgetting to update the README table (the new tool won't be discovered)
