# Audit (diagnosing existing docs against Diátaxis)

Diagnose existing docs and **propose** relocations and improvements. Actual file moves happen only after user approval.

**Do not create four empty sections up front** — the Diátaxis structure emerges as a result of improvements; it is not a frame you build first and then fill.

## Procedure

### 1. Inventory

```bash
find docs -name '*.md' | sort
wc -l $(find docs -name '*.md') | sort -n | tail -20   # 巨大 doc = 種別混在の候補
```

Put every file into a table. **Count them and report the numbers** (never write "roughly" or "many").

### 2. Type determination

Apply the compass to each file (SKILL.md §3). Judge by the content, not by the location or filename.

| Sign | Actual type |
|---|---|
| Has steps, single path, aimed at a beginner | tutorial |
| Has steps, has branches, clear goal | how-to |
| Mostly tables and lists, no steps | reference |
| Mostly why / options / history | architecture |
| Two or more of the above in one file | **split candidate** |

### 3. Contamination detection

```bash
grep -nE 'なぜ|理由は|とは|または|お好みで' docs/tutorial/*.md          # tutorial への説明・選択肢
grep -nE '学び|理解し|仕組み|背景'          docs/how-to/**/*.md         # how-to への教育
grep -nE 'まず|次に|してください|推奨|べき'  docs/reference/*.md         # reference への手順・意見
grep -nE '^[0-9]+\. |してください'          docs/architecture/*.md      # architecture への手順
grep -rn 'TBD\|TODO\|未定'                  docs/                       # 未確定の放置
```

grep produces candidates. Filter out acceptable cases such as a one-line minimal explanation.

### 4. Inspect the C4 diagrams (architecture)

Apply the `c4.md` checklist. Frequent hits: mixed levels / unlabelled lines / missing legend / deployment concerns inside the Container diagram.

### 5. Propose relocations

One line per file.

| Current path | Determined type | Destination | Notes |
|---|---|---|---|
| `docs/design/foo.md` | explanation + reference mixed | `docs/architecture/c2-container.md` + `docs/reference/foo.md` | Split three tables into reference |

Always attach the following to the proposal:

- **Link impact** — the hit count of `grep -rn '<旧 path>' . --include='*.md' --include='*.go'`
- **Doc inventory updates** — the documentation-structure section of the target repo's CLAUDE.md and `docs/index.md`
- **Handling of decision records** — when the restructure overturns a decision in an existing ADR, **the ADR is not rewritten; a superseding ADR must be raised** (raising it is the human's call)

### 6. One improvement at a time

Do not propose a grand restructure. Decompose it into "make the one file in front of you one notch better", repeated. Each improvement must keep links consistent on its own and be committable on its own.

## Migration map from the old structure

Reading across from a genre-based structure.

| Old | New |
|---|---|
| `docs/readme/getting-started.md` | `docs/tutorial/<topic>.md` (study) or `docs/how-to/<goal>.md` (work) |
| `docs/readme/user-manual.md` | Mostly split into how-to. Spec tables go to reference |
| `docs/runbook/*.md` | `docs/how-to/runbook/*.md` |
| `docs/api/*.md` | Abolished. Make the schema the SoT and link from `docs/reference/` |
| `docs/adr/*.md` | `docs/architecture/adr/*.md` (keep the numbers) |
| `docs/design/<top>.md` | Break up per C4 level → `c1-context.md` / `c2-container.md` / `dynamic-*.md` / `deployment-<env>.md` |
| `docs/design/subsystems/*.md` | `docs/architecture/c3-<container>.md` |
| `docs/design/crosscutting/*.md` | The why goes to `docs/architecture/<topic>.md`; operational procedures go to `docs/how-to/` |
| `docs/plan/*.md` | Outside docs (ticket / Wiki) |
| arc42 §12 Glossary equivalent | `docs/reference/glossary.md` |
| arc42 §10 Quality Requirements equivalent | `docs/architecture/<topic>.md` (SLOs belong with the support-boundary doc) |

## Reporting format

- Inventory counts (measured)
- Breakdown by type and the split candidates
- Contamination hit counts, and the real problems left after triage
- The relocation proposal table
- The next single improvement (exactly one)
