---
name: rust-bootstrap
description: Sets up a working skeleton for a Rust workspace in a new or existing directory in one shot (crates/* layout, centralized lints, Makefile, deny.toml, CI, all the way through installing rustup. The only task runner is make). Used for things like 「Rust の workspace 切って」「Rust プロジェクトのセットアップ」「複数 tool 入れる Rust リポジトリにして」.
---

> **Source of truth:** `claude/ja/skills/rust-bootstrap/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# rust-bootstrap

A skill that sets up a Rust workspace from scratch to the point where "`make ci` (fmt-check + clippy -D warnings + test) passes". Intended to be used only once per repository.

**All the file templates are in `references/templates.md`. Read it once before starting Step 2, and use it by replacing the placeholders with the values confirmed in Step 0.**

> **Snapshot**: Written assuming 2026-04 / Rust 1.95 stable / edition 2024 / resolver 3.
> If more than six months have passed, verify the versions used in the Cargo.toml template and CI workflow (dtolnay/rust-toolchain, Swatinem/rust-cache, EmbarkStudios/cargo-deny-action, etc.) before reusing them.

## Applicability

- Assumes a workspace that bundles a set of binary tools (not a published library)
- Adopts Rust 1.90+ / edition 2024 / resolver 3
- Layout is multiple crates under `crates/<name>/` (assuming future additions). If a different layout is needed, confirm with the user

## Procedure

### Step 0: Check prerequisites

```bash
which cargo && cargo --version && rustc --version    # if not installed, rustup in Step 1
ls -la                                               # grasp existing files
test -f Cargo.toml && cat Cargo.toml                 # check existing manifest
```

Items to confirm (consolidate into one AskUserQuestion turn):
- Workspace name (= is it fine to use the repository name)
- License (one of `MIT` / `Apache-2.0` / `MIT OR Apache-2.0` — dual licensing is the ecosystem convention)
- Name of the first crate (e.g. `mytool`)
- Repository URL (`https://github.com/<user>/<repo>`)
- Primary purpose of the binary (CLI / TUI / daemon — if TUI, use the ratatui skeleton)

### Step 1: Install rustup (only if not already installed)

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default
. "$HOME/.cargo/env"
```

Insert `. "$HOME/.cargo/env"` before subsequent Bash calls (to inherit the PATH).

### Steps 2-9: Generate files (templates are in `references/templates.md`)

| Step | File | Key points |
|---|---|---|
| 2 | Root `Cargo.toml` | Virtual workspace. Centralize metadata with `[workspace.package]` / `[workspace.dependencies]` / lints / a distribution-grade release profile. For TUI, add crossterm + ratatui + futures to dependencies |
| 3 | `rust-toolchain.toml` | stable + rustfmt + clippy (prevents drift between CI and local) |
| 4 | `crates/<name>/` | Cargo.toml inherits everything from the workspace (`*.workspace = true`); main.rs is a minimal CLI with clap + anyhow |
| 5 | `rustfmt.toml` | edition 2024 / max_width 100 |
| 6 | `Makefile` | help / build / release / test / clippy / fmt / check / deny / ci / install / uninstall / clean / update |
| 7 | `deny.toml` | advisories + licenses allow-list + bans + sources (supply-chain audit) |
| 8 | `.cargo/config.toml` | Windows static CRT + `cargo ci` / `cargo xclippy` aliases |
| 9 | `.github/workflows/ci.yml` | 3 jobs: lint (fmt + clippy) / test (3-OS matrix) / deny |

**Install strategy (design decision for Step 6)**: `cargo install --path` triggers a release build every time, but `make install` runs a single release build for the whole workspace and distributes binaries via `cp`, which is faster for workspaces with multiple binaries. The default `PREFIX = ~/.local/bin` requires no sudo and follows the XDG standard. `/opt/homebrew/bin` is avoided because mixing in binaries that aren't managed by Homebrew causes confusion during updates.

### Step 10: `LICENSE`

Place it according to the chosen license. For `MIT OR Apache-2.0`, place both `LICENSE-MIT` and `LICENSE-APACHE`. For MIT only, place `LICENSE`.

### Step 11: `.gitignore`

```
/target
**/*.rs.bk
.DS_Store
```

`Cargo.lock` **is committed** (the convention for binary workspaces). Do not add it to `.gitignore`.

### Step 12: Root `README.md`

A tools table + explanation of `make help` / `make ci` / `make install` (template is in `references/templates.md`).

### Step 13: Sync CLAUDE.md / existing README

If `CLAUDE.md` exists, append a "## Development commands" section (the template for the appended content is in `references/templates.md`). For an existing README, append rather than overwrite.

### Step 14: Verify it works

```bash
. "$HOME/.cargo/env"
cargo build --workspace                && echo BUILD_OK
cargo test  --workspace --all-targets  && echo TEST_OK
cargo clippy --workspace --all-targets --all-features -- -D warnings && echo CLIPPY_OK
cargo fmt --all -- --check             && echo FMT_OK
```

`make ci` can run the same three checks together.

### Step 15: Completion report

| Item | Status |
|---|---|
| `cargo build --workspace` | ✓ |
| `cargo test` / `cargo clippy -D warnings` / `cargo fmt --check` | ✓ |
| Workspace name / first crate | <confirmed value> |
| License | <confirmed value> |
| `Cargo.toml` (workspace.package + dependencies + lints + profile) | ✓ |
| `rust-toolchain.toml` / `rustfmt.toml` / `Makefile` / `deny.toml` / `.cargo/config.toml` | ✓ |
| `.github/workflows/ci.yml` | ✓ |
| LICENSE / README.md | ✓ |

## Golden rules

1. **Respect existing files**: for existing `.gitignore` / `CLAUDE.md` / `README.md`, append rather than overwrite
2. **Comments in English**: comments in Rust files are in English (`//`, `///`, `//!`)
3. **Commit `Cargo.lock`**: the modern convention for binary workspaces
4. **Stay in scope**: feature implementation (TUI event loops, server implementation, etc.) is out of scope. Hand off to the next skill (`add-rust-crate`) or manual work
5. **Do not commit**: committing is delegated to a separate skill (`/commit-push-branch`)
6. **Prefer `pub(crate)` over `pub`**: since binary crates have no external exposure, start with minimal visibility
7. **`make` is the only task runner**: `make` ships standard with macOS / Linux at zero added dependency cost. `just` / `task` / `xtask`, etc. are new dependencies and are not added by default (only if the user explicitly wants them). Their advantages over a Makefile — cross-platform support, arguments, `--list` — aren't large enough to justify the added dependency

## Anti-patterns

- Hardcoding each crate's version/license/repo in its own `Cargo.toml` (not using workspace inheritance)
- Writing `[profile.release]` in a crate's own `Cargo.toml` (Cargo only looks at the workspace root)
- Adding `Cargo.lock` to `.gitignore` (don't bring the library-crate convention into a binary project)
- Leaving `resolver = "2"` unchanged (choose 3 when using edition 2024 + Rust 1.84+)
- Enabling `pedantic` clippy without any allows (for intentional cases like `cast_precision_loss`, allow them in the workspace lints with a reason comment)
- Forcing library-publishing conventions like `#[non_exhaustive]` / `C-CRATE-DOC` onto every type (excessive for a binary crate)
- Not creating `rust-toolchain.toml` (a breeding ground for drift between CI and local toolchains)
- Setting up `cargo-dist` from the very start (excessive for a personal toolkit; introduce it when you actually start cutting releases by hand)
- Blindly trusting a research agent's **unsubstantiated impression** that "`just` is the de facto standard / the modern choice" and adding it as a new dependency (in reality, none of ripgrep, fd, bat, cargo, rustc, uv, or ruff use `just`)
