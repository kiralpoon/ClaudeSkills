# ExecPlans
When writing complex features or significant refactors, use an ExecPlan (as described in .agent/PLANS.md) from design to implementation.

## Tmux Workflow Rules

**CRITICAL: Never use manual sleep + capture-pane polling loops!**

When working with tmux panes, ALWAYS use the dedicated skills:

| Task | Use This | NOT This |
|------|----------|----------|
| View pane contents | `/see-terminal <pane>` | `tmux capture-pane` directly |
| Wait for command to finish | `/tmux-wait prompt <pane> [timeout]` | `sleep N && tmux capture-pane` |
| Wait for specific text | `/tmux-wait output <pane> "text" [timeout]` | polling loops with grep |
| Execute + wait | `/tmux-wait command <pane> <cmd>` | `tmux send-keys` + sleep |

**Examples:**

```bash
# ❌ WRONG - Manual polling
sleep 5 && tmux capture-pane -t 0 -p -S -50
sleep 10 && tmux capture-pane -t 0 -p -S -100  # still waiting...

# ✅ RIGHT - Use the skills
/tmux-wait prompt 0 60    # Waits efficiently, returns when done
/see-terminal 0           # Then check the results
```

**Workflow pattern:**
1. Send command: `tmux send-keys -t <pane> "command" Enter`
2. Wait for completion: `/tmux-wait prompt <pane> 60`
3. Check results: `/see-terminal <pane>`

## Ignore Memos / Personal Notes
- Treat files explicitly marked as personal memos as out of scope for coding, planning, or citations.
- A file is considered out of scope if any of the following is true (checked within the first 50 lines):
  - It contains a YAML front-matter block with `agent.ignore: true`.
  - It contains a line matching `AGENT-IGNORE: true` (case-insensitive).
- For such files, do not read beyond the header, do not summarize, cite, modify, or rely on their content unless the user explicitly asks.

This policy applies to the entire repository.
