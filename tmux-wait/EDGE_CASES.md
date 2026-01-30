# tmux-wait Edge Cases

Known detection issues, false positives, and workarounds.
Each entry: **Symptom** → **Cause** → **Fix/Status**.

---

## Shell Prompt Detection

_No known edge cases yet._

---

## Claude Code Detection

### 1. Middle dot in MCP status line (fixed)

- **Symptom**: tmux-wait never returns when Claude is idle, times out
- **Cause**: Status line `1 MCP server failed · /mcp` contains `·` (U+00B7 middle dot), which matched the thinking spinner regex
- **Fix**: Removed `·` from the indicator pattern — the other spinner chars (`✻✽✶✢`) are unique enough
- **Date**: 2026-01-30

### 2. Stale thinking indicators in scrollback (fixed)

- **Symptom**: tmux-wait never returns after Claude finishes a task, even though `❯` prompt is visible
- **Cause**: Lines like `✻ Cooked for 34s` remain in the 50-line capture from a previous operation, triggering the "still processing" check
- **Fix**: Narrowed the indicator check from all 50 captured lines to only the last 5 non-empty lines near the prompt
- **Date**: 2026-01-30

### 3. Autocomplete menu not dismissed (unresolved)

- **Symptom**: After sending `/command` + Enter + sleep 1 + Enter, the autocomplete dropdown stays visible. Last line is the autocomplete suggestion, which matches no prompt pattern, so tmux-wait loops forever
- **Cause**: The 1-second sleep between the two Enters is sometimes not enough for Claude's UI to process and dismiss autocomplete
- **Workaround**: After tmux-wait detects this (or times out), send an additional Enter and retry. No code fix yet — handled procedurally by the caller
- **Date**: 2026-01-30
