> **Source of truth:** `claude/ja/skills/self-review-changes/references/dependency.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# dependency — dependencies / supply chain

Skippable: the diff of dependency files (go.mod / go.sum / package.json / lock files / import lines) is 0.

- **Detecting new dependencies**: enumerate additions to go.mod / package.json / import lines. **New dependencies require user approval** (CLAUDE.md's "conduct principles"). In loop-mode, detection = immediate escalation (don't add one automatically and proceed)
- **Version updates**: whether a version change to an existing dependency is intentional (flag out-of-scope lock file changes)
- **Supply chain**: whether the name of a new dependency is a typosquat (verify an official org / a track record of high-frequency use), whether it's a package with an install script
- **Transitive dependency bloat**: whether one new dependency pulls in a large number of transitive dependencies (`go mod graph` / the scale of the lock diff)
- **Licence**: whether a new dependency's licence conflicts with the repo's policy (if unclear, flag)
