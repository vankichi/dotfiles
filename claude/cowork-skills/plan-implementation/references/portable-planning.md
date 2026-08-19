# Generic planning perspectives (fallback when the repo has no layer-convention files)

Use this only when the repo has no `.claude/rules/layering.md` / `.claude/rules/review-checklist.md`. When using it, state in the output that the run went without the repo-specific layer conventions.

## Layer placement

- Establish the dependency direction first (which layer imports which). If it isn't readable, grep the imports of three existing files to infer it and state that it is an inference
- Put new symbols **next to the existing files of the same kind**. Before creating a new layer or package, write down why the existing location isn't enough
- Create a replacement seam only when it's needed, as a minimal interface on the consumer side. Don't pre-build an interface with a single use site

## Dependency order

- Implement the referenced side first (leaves → callers)
- If it cycles, change how the PRs are cut (split the shared part out first)

## PR split

- 1 PR = 1 responsibility. Cut when it exceeds the size guideline (if the repo states none, use 800 lines as a stated provisional value)
- Cutting lines: layer / responsibility / stage (foundation → wiring) / file type
- Colocate the corresponding doc update in the same PR. File an issue for any discrepancy this PR can't fix and link it from the PR
- A PR of only new, unreferenced files (foundation only) is acceptable. Don't invert the stack order against the dependency order

## Granularity of the steps

- List the files to touch by path, one per line
- Order them test-first (failing test → implementation → green)
- Pitfalls: constraints hit before / vendor-specific quirks / places where generated artifacts must be regenerated
- Local verification commands must **exist in the repo's task definition files**. If there are none, write "no verification means" (don't instruct anyone to create one)
