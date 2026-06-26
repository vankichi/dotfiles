# 最小 parser (TypeScript)

zod の discriminatedUnion + `.or(z.object({ type: z.string() }))` catch-all で未知 type を安全に無視する。

```ts
import { z } from "zod";

const Usage = z.object({
  input_tokens: z.number().default(0),
  output_tokens: z.number().default(0),
  cache_creation_input_tokens: z.number().default(0),
  cache_read_input_tokens: z.number().default(0),
});

const ContentBlock = z.discriminatedUnion("type", [
  z.object({ type: z.literal("tool_use"), name: z.string() }),
  z.object({ type: z.literal("text"), text: z.string().optional() }),
  z.object({ type: z.literal("thinking"), thinking: z.string().optional() }),
]).or(z.object({ type: z.string() }));  // catch-all

const AssistantEvent = z.object({
  type: z.literal("assistant"),
  message: z.object({
    model: z.string().optional(),
    content: z.array(ContentBlock).default([]),
    usage: Usage.optional(),
  }),
});

const Event = z.discriminatedUnion("type", [AssistantEvent])
  .or(z.object({ type: z.string() }));  // catch-all

export function parseLine(line: string) {
  const t = line.trim();
  if (!t) return null;
  return Event.parse(JSON.parse(t));
}
```
