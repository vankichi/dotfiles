# TUI 雛形 (ratatui + tokio + crossterm EventStream)

crate 種別が `tui` のときだけ読む。

## workspace.dependencies (未登録なら追加)

```toml
crossterm = { version = "0.28", features = ["event-stream"] }
ratatui = "0.29"
futures = "0.3"
```

## `crates/<name>/Cargo.toml` の `[dependencies]` に追加

```toml
crossterm.workspace = true
ratatui.workspace = true
futures.workspace = true
tokio.workspace = true
```

## `src/main.rs`

```rust
//! <name> — <description>

mod app;

use anyhow::Result;
use clap::Parser;

#[derive(Parser, Debug)]
#[command(name = "<name>", version, about)]
struct Cli {}

#[tokio::main]
async fn main() -> Result<()> {
    let _cli = Cli::parse();
    let mut terminal = ratatui::init();
    let res = app::run(&mut terminal).await;
    ratatui::restore();
    res
}
```

## `src/app.rs`

```rust
use anyhow::Result;
use crossterm::event::{Event, EventStream, KeyCode, KeyEventKind};
use futures::StreamExt;
use ratatui::{DefaultTerminal, Frame, widgets::{Block, Borders, Paragraph}};
use std::time::Duration;

pub(crate) async fn run(terminal: &mut DefaultTerminal) -> Result<()> {
    let mut events = EventStream::new();
    let mut tick = tokio::time::interval(Duration::from_millis(250));
    tick.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

    loop {
        terminal.draw(view)?;

        tokio::select! {
            _ = tick.tick() => {}
            Some(Ok(ev)) = events.next() => {
                if let Event::Key(k) = ev
                    && k.kind == KeyEventKind::Press
                    && matches!(k.code, KeyCode::Char('q') | KeyCode::Esc)
                {
                    return Ok(());
                }
            }
        }
    }
}

fn view(f: &mut Frame<'_>) {
    let p = Paragraph::new("hello — press q to quit")
        .block(Block::default().borders(Borders::ALL).title(" <name> "));
    f.render_widget(p, f.area());
}
```

`ratatui::init()` が **panic hook + raw mode + alt screen** を一括処理するので自前で `enable_raw_mode` 等は書かない。`crossterm::event::poll(0)` も `EventStream` で置換。

## スケールしてきた時のパターン (2 種類以上のキー処理がある TUI)

最初の version で q だけなら上記で十分。**3 種以上のキー** や **destructive 系**(reset / delete) が出てきたら、event loop に直接 match を書かず **enum で意図を取り出す**:

```rust
#[derive(Debug, PartialEq, Eq)]
enum KeyAction {
    Quit,
    Reset,
    Refresh,
    Ignore,
}

/// Pure mapping: testable without spinning up the TUI.
fn classify_key(code: KeyCode) -> KeyAction {
    match code {
        KeyCode::Char('q') | KeyCode::Esc => KeyAction::Quit,
        KeyCode::Char('r') => KeyAction::Reset,
        KeyCode::Char('R') => KeyAction::Refresh,
        _ => KeyAction::Ignore,
    }
}

// Loop 内:
match classify_key(k.code) {
    KeyAction::Quit => return Ok(()),
    KeyAction::Reset => state.reset(),
    KeyAction::Refresh => state.refresh()?,
    KeyAction::Ignore => {}
}
```

利点: `classify_key` を unit test できる。loop 内が「意図名の match」で読みやすい。workspace 内に既存 TUI crate があれば、その classify_key 実装を先に参照して流儀を揃える。

## tokio mpsc を ingest source に使うとき

外部スレッドからイベント (file watcher / websocket / etc.) を流すなら `recv_many` でドレインするのが効率的:

```rust
let mut event_buf = Vec::with_capacity(64);
loop {
    tokio::select! {
        _ = tick.tick() => {}
        n = rx.recv_many(&mut event_buf, 64) => {
            if n == 0 { return Ok(()); }  // sender closed
            for ev in event_buf.drain(..) { state.ingest(&ev); }
        }
        Some(Ok(ct_ev)) = events.next() => { /* keys */ }
    }
    terminal.draw(|f| view(f, &state))?;
}
```

`try_recv` を while ループで叩くより 1 回の syscall で済む。
