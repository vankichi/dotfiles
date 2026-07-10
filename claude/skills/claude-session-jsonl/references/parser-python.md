> **Source of truth:** `claude/ja/skills/claude-session-jsonl/references/parser-python.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# Minimal parser (Python)

Use a dict-based approach and discard anything where `type != "assistant"`. The dataclass is only for usage.

```python
import json
from dataclasses import dataclass, field

@dataclass
class Usage:
    input_tokens: int = 0
    output_tokens: int = 0
    cache_creation_input_tokens: int = 0
    cache_read_input_tokens: int = 0

    @property
    def context_size(self) -> int:
        return (
            self.input_tokens
            + self.cache_creation_input_tokens
            + self.cache_read_input_tokens
        )

def parse_line(line: str):
    line = line.strip()
    if not line:
        return None
    d = json.loads(line)
    if d.get("type") != "assistant":
        return None
    msg = d.get("message", {})
    u = msg.get("usage") or {}
    tools = [c.get("name") for c in msg.get("content", []) if c.get("type") == "tool_use"]
    return {
        "model": msg.get("model"),
        "tools": tools,
        "usage": Usage(
            input_tokens=u.get("input_tokens", 0),
            output_tokens=u.get("output_tokens", 0),
            cache_creation_input_tokens=u.get("cache_creation_input_tokens", 0),
            cache_read_input_tokens=u.get("cache_read_input_tokens", 0),
        ),
        "timestamp": d.get("timestamp"),
    }
```
