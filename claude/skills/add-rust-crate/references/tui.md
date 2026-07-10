> **Source of truth:** `claude/ja/skills/add-rust-crate/references/tui.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# TUI skeleton (ratatui + tokio + crossterm EventStream)

Read this only when the crate kind is `tui`.

## workspace.dependencies (add if not already registered)

```toml
crossterm = { version = "0.28", features = ["event-stream"] }
ratatui = "0.29"
futures = "0.3"
```

## Add to `[dependencies]` in `crates/<name>/Cargo.toml`

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

`ratatui::init()` handles **the panic hook + raw mode + alt screen** all at once, so don't write `enable_raw_mode` etc. yourself. Also replace `crossterm::event::poll(0)` with `EventStream`.

## Pattern for when things scale up (a TUI with 2 or more kinds of key handling)

If the first version only handles 'q', the above is sufficient. Once **3 or more kinds of keys** or **destructive operations** (reset / delete) show up, don't write `match` directly in the event loop — instead **extract intent via an enum**:

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

// Inside the loop:
match classify_key(k.code) {
    KeyAction::Quit => return Ok(()),
    KeyAction::Reset => state.reset(),
    KeyAction::Refresh => state.refresh()?,
    KeyAction::Ignore => {}
}
```

Benefit: `classify_key` can be unit tested. The loop reads clearly because it's a "match on intent name". If there's already an existing TUI crate in the workspace, reference its `classify_key` implementation first to keep the style consistent.

## When using tokio mpsc as an ingest source

If events are streamed in from an external thread (file watcher / websocket / etc.), draining with `recv_many` is efficient:

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

This takes a single syscall, compared to hammering `try_recv` in a while loop.
