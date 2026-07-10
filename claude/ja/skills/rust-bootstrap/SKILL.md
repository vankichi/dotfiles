---
name: rust-bootstrap
description: 新規 / 既存ディレクトリに Rust workspace の動く骨格を一括セットアップする (crates/* レイアウト、lints 集中管理、Makefile、deny.toml、CI、rustup 導入まで。task runner は make のみ)。「Rust の workspace 切って」「Rust プロジェクトのセットアップ」「複数 tool 入れる Rust リポジトリにして」等で使う。
---

# rust-bootstrap

Rust workspace をゼロから「`make ci` (fmt-check + clippy -D warnings + test) が pass する状態」までセットアップする skill。1 リポジトリにつき 1 回しか使わない想定。

**ファイルテンプレートは `references/templates.md` に全部ある。Step 2 に着手する前に 1 回 Read し、placeholder を Step 0 の確認値で置換して使う。**

> **Snapshot**: 2026-04 / Rust 1.95 stable / edition 2024 / resolver 3 を前提に書かれてる。
> 半年以上経った場合、Cargo.toml テンプレや CI workflow のバージョン (dtolnay/rust-toolchain, Swatinem/rust-cache, EmbarkStudios/cargo-deny-action 等) は確認してから流用すること。

## 適用条件

- バイナリツール群を束ねる workspace を想定 (ライブラリ公開ではない)
- Rust 1.90+ / edition 2024 / resolver 3 を採用
- レイアウトは `crates/<name>/` に複数 crate (将来追加前提)。違うレイアウトのときはユーザーに確認

## 手順

### Step 0: 前提確認

```bash
which cargo && cargo --version && rustc --version    # 未導入なら Step 1 で rustup
ls -la                                               # 既存ファイル把握
test -f Cargo.toml && cat Cargo.toml                 # 既存 manifest 確認
```

確認事項 (AskUserQuestion で 1 ターンに集約):
- workspace 名 (= リポジトリ名でよいか)
- ライセンス (`MIT` / `Apache-2.0` / `MIT OR Apache-2.0` のどれか — エコシステム慣習は dual)
- 最初の crate 名 (例: `mytool`)
- repository URL (`https://github.com/<user>/<repo>`)
- バイナリの主用途 (CLI / TUI / daemon — TUI なら ratatui 雛形)

### Step 1: rustup インストール (未導入時のみ)

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default
. "$HOME/.cargo/env"
```

`. "$HOME/.cargo/env"` を以降の Bash 呼び出し前に挟むこと (PATH を継承させるため)。

### Step 2〜9: ファイル生成 (テンプレは `references/templates.md`)

| Step | ファイル | 要点 |
|---|---|---|
| 2 | ルート `Cargo.toml` | virtual workspace。`[workspace.package]` でメタ集中管理 / `[workspace.dependencies]` / lints / distribution-grade release profile。TUI なら crossterm + ratatui + futures を dependencies に追加 |
| 3 | `rust-toolchain.toml` | stable + rustfmt + clippy (CI と手元のズレ防止) |
| 4 | `crates/<name>/` | Cargo.toml は全部 workspace 継承 (`*.workspace = true`)、main.rs は clap + anyhow の最小 CLI |
| 5 | `rustfmt.toml` | edition 2024 / max_width 100 |
| 6 | `Makefile` | help / build / release / test / clippy / fmt / check / deny / ci / install / uninstall / clean / update |
| 7 | `deny.toml` | advisories + licenses allow-list + bans + sources (supply-chain 監査) |
| 8 | `.cargo/config.toml` | Windows static CRT + `cargo ci` / `cargo xclippy` alias |
| 9 | `.github/workflows/ci.yml` | lint (fmt + clippy) / test (3 OS matrix) / deny の 3 job |

**install 戦略 (Step 6 の設計判断)**: `cargo install --path` は毎回 release build がトリガーされるが、`make install` は workspace 一括の release build を 1 回走らせて `cp` で配るので、複数 binary の workspace では速い。default の `PREFIX = ~/.local/bin` は sudo 不要 + XDG 標準。`/opt/homebrew/bin` は Homebrew 管理外のバイナリを混ぜると update 時に混乱の素なので避ける。

### Step 10: `LICENSE`

選んだライセンスに応じて配置。`MIT OR Apache-2.0` なら `LICENSE-MIT` と `LICENSE-APACHE` 両方。MIT のみなら `LICENSE`。

### Step 11: `.gitignore`

```
/target
**/*.rs.bk
.DS_Store
```

`Cargo.lock` は **コミットする** (binary workspace の慣習)。`.gitignore` に入れない。

### Step 12: ルート `README.md`

tools 表 + `make help` / `make ci` / `make install` の説明 (テンプレは `references/templates.md`)。

### Step 13: CLAUDE.md / 既存 README 同期

`CLAUDE.md` があれば「## 開発コマンド」を追記 (追記分のテンプレは `references/templates.md`)。既存 README は上書きせず追記。

### Step 14: 動作確認

```bash
. "$HOME/.cargo/env"
cargo build --workspace                && echo BUILD_OK
cargo test  --workspace --all-targets  && echo TEST_OK
cargo clippy --workspace --all-targets --all-features -- -D warnings && echo CLIPPY_OK
cargo fmt --all -- --check             && echo FMT_OK
```

`make ci` で同じ 3 つを一括実行できる。

### Step 15: 完了報告

| 項目 | 状況 |
|---|---|
| `cargo build --workspace` | ✓ |
| `cargo test` / `cargo clippy -D warnings` / `cargo fmt --check` | ✓ |
| workspace 名 / 最初の crate | <確認値> |
| ライセンス | <確認値> |
| `Cargo.toml` (workspace.package + dependencies + lints + profile) | ✓ |
| `rust-toolchain.toml` / `rustfmt.toml` / `Makefile` / `deny.toml` / `.cargo/config.toml` | ✓ |
| `.github/workflows/ci.yml` | ✓ |
| LICENSE / README.md | ✓ |

## 鉄則

1. **既存ファイル尊重**: 既存 `.gitignore` / `CLAUDE.md` / `README.md` は上書きせず追記
2. **コメントは英語**: Rust ファイルのコメントは英語 (`//`, `///`, `//!`)
3. **`Cargo.lock` はコミットする**: バイナリ workspace の現代的慣習
4. **scope を守る**: 機能実装 (TUI イベントループ・サーバ実装等) は対象外。次の skill (`add-rust-crate`) や手作業に渡す
5. **コミットしない**: コミットは別 skill (`/commit-push-branch`) に委ねる
6. **`pub` より `pub(crate)`**: バイナリ crate は外部公開がないので可視性は最小から始める
7. **task runner は `make` のみ**: `make` は macOS / Linux 標準同梱で追加 dep ゼロ。`just` / `task` / `xtask` などは新規 dep なので default では入れない (ユーザーが明示的に希望した場合のみ)。Makefile に対する利点は cross-platform / 引数 / `--list` 程度で、追加 dep を払うほど大きくない

## アンチパターン

- `Cargo.toml` に各 crate ごとの version/license/repo をベタ書き (workspace inheritance を使わない)
- `[profile.release]` を crate 側 Cargo.toml に書く (Cargo は workspace ルートしか見ない)
- `.gitignore` に `Cargo.lock` を入れる (library crate の慣習を binary に持ち込まない)
- `resolver = "2"` のまま放置 (edition 2024 + Rust 1.84+ なら 3 を選ぶ)
- `pedantic` clippy を allow なしで有効化 (`cast_precision_loss` など意図的なものは workspace lints で allow + 理由コメント)
- ライブラリ公開向けの `#[non_exhaustive]` / `C-CRATE-DOC` を全 type に強制 (binary crate には過剰)
- `rust-toolchain.toml` を作らない (CI と手元の toolchain ズレの温床)
- `cargo-dist` を最初から仕込む (個人 toolkit には過剰、リリースを手で作るタイミングで導入)
- 「`just` がデファクト / 現代的」のような研究エージェントの **印象論** を鵜呑みにして新規 dep を入れる (実態は ripgrep / fd / bat / cargo / rustc / uv / ruff いずれも `just` を使っていない)
