# 最小 parser (Rust)

serde の tagged enum + `#[serde(other)]` catch-all で未知 type を安全に無視する。

```rust
use serde::Deserialize;

#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "kebab-case")]
pub(crate) enum Event {
    Assistant(AssistantEvent),
    #[serde(other)]
    Other,
}

#[derive(Debug, Deserialize)]
pub(crate) struct AssistantEvent {
    pub message: AssistantMessage,
}

#[derive(Debug, Deserialize)]
pub(crate) struct AssistantMessage {
    #[serde(default)] pub model: Option<String>,
    #[serde(default)] pub content: Vec<ContentBlock>,
    #[serde(default)] pub usage: Option<Usage>,
}

#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub(crate) enum ContentBlock {
    ToolUse { #[serde(default)] name: String },
    #[serde(other)] Other,
}

#[derive(Debug, Default, Deserialize, Clone, Copy)]
pub(crate) struct Usage {
    #[serde(default)] pub input_tokens: u64,
    #[serde(default)] pub output_tokens: u64,
    #[serde(default)] pub cache_creation_input_tokens: u64,  // 5min + 1hr 合計
    #[serde(default)] pub cache_read_input_tokens: u64,
    #[serde(default)] pub cache_creation: Option<CacheCreation>,
}

#[derive(Debug, Default, Deserialize, Clone, Copy)]
pub(crate) struct CacheCreation {
    #[serde(default)] pub ephemeral_5m_input_tokens: u64,
    #[serde(default)] pub ephemeral_1h_input_tokens: u64,
}

impl Usage {
    /// (5min, 1hr) breakdown for cost calc. Old logs without `cache_creation`
    /// are treated as all-5min for backward compat.
    pub fn cache_creation_split(&self) -> (u64, u64) {
        match self.cache_creation {
            Some(c) => (c.ephemeral_5m_input_tokens, c.ephemeral_1h_input_tokens),
            None => (self.cache_creation_input_tokens, 0),
        }
    }
}

pub(crate) fn parse_line(line: &str) -> serde_json::Result<Option<Event>> {
    let t = line.trim();
    if t.is_empty() { return Ok(None); }
    Ok(Some(serde_json::from_str(t)?))
}
```
