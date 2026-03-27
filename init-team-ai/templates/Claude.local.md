# Local Claude Code Preferences

This file contains personal preferences for Claude Code that are specific to this repository and should not be committed to version control.

## Git Commit Preferences

**DO NOT include "Co-Authored-By: Claude" credit in commit messages.**

When creating commits:
- Write clear, descriptive commit messages
- Do NOT append any co-author lines
- Keep commits focused and concise
- Follow the existing commit message style in the repository

<!-- BEGIN TEMPLATE: agent-workflow -->
## Agent Workflow

Always read and follow the guidelines in:
- `Agents.md` (root of project) - Core agent behavior and ExecPlan usage
- `.agent/PLANS.md` - Detailed ExecPlan authoring guidelines
<!-- END TEMPLATE: agent-workflow -->

<!-- BEGIN TEMPLATE: pre-approved-commands -->
## Pre-Approved Commands

The `.claude/settings.local.json` file includes pre-approved permissions for safe, read-only commands and essential tmux operations:

**File operations**: ls, cat, pwd, cd, find, head, tail
**Git operations**: git status, git log, git diff, git show, git branch
**System info**: which, whereis, date, whoami, hostname, ps
**Text processing**: echo, grep, sed
**Tmux operations**: tmux (for see-terminal skill)
**Utilities**: sleep (for polling/monitoring)

These permissions enable smooth operation of skills like `/see-terminal` without repeatedly asking for approval.
<!-- END TEMPLATE: pre-approved-commands -->

<!-- BEGIN TEMPLATE: team-ai-quick-reference -->
## Team AI Quick Reference

Use this section when acting as Team Lead in the `/team-ai` pipeline. **Read `.agent/TEAM.md` for the full protocol** — this section is a quick-reference for the most critical operational rules.

### Pipeline Flow

```
Stage 1 (Build):      Task → Builder (claude -p) → 01-build.md → Verdict: APPROVED
Stage 2 (UX Review):  Task → Gemini (-y)         → 02-ux-review.md → Verdict
Stage 3 (Code Review): Task → Codex (--full-auto) → 03-code-review.md → Verdict
Stage 4 (Evaluate):   Both APPROVED → summary → user approves → commit
                      NEEDS_REVISION → collect issues → fix-task → loop to Stage 1
```

Max 5 rounds per review stage (independent budgets). On 6th rejection → escalate to user.
Deliberation does not consume a round. Read TEAM.md for deliberation file format.

Mode B (multi-perspective review): parallel UX + Architecture + Devil's Advocate → synthesis.
Triggered by "review"/"perspectives" in task. Outputs to `.agent/reviews/`.

### SESSION.json — Pane Targeting

Location: `.agent/pipeline/SESSION.json` (written by `scripts/start-team.sh`)

Read at pipeline start to get stable pane IDs:

```json
{
  "panes": {
    "lead":     "%5",
    "builder":  "%6",
    "ux":       "%7",
    "reviewer": "%8",
    "monitor":  "%9"
  }
}
```

Target panes with `%N` syntax: `tmux send-keys -t %7 "command" Enter`
**Never use `:0.1` indices** — they shift when panes are added/removed.
Set the "lead" field yourself: `tmux display-message -p '#{pane_id}'`

### Session Setup

```bash
bash scripts/start-team.sh [working-directory]
```

- Inside tmux: creates "team-ai" window (Ctrl+B n/p to switch)
- Outside tmux: creates standalone session (tmux attach -t team-ai)
- Idempotent — if team-ai exists, exits without changes
- Gemini starts as `gemini -y` (interactive, yolo mode)
- Codex starts as `codex --full-auto` (interactive, full auto-approve)
- Builder pane starts empty — Team Lead invokes `claude -p` per task

### Sending Tasks to Agent Panes

**Builder** (non-interactive, stdin redirect — single Enter):
```bash
tmux send-keys -t "$BUILDER_PANE" "claude -p < .agent/pipeline/.build-task.md" Enter
```
Builder runs non-interactively: `claude -p` is invoked per task and exits after completion.

**UI/UX Reviewer** (interactive TUI — two-Enter pattern):
```bash
tmux send-keys -t "$UX_PANE" "$(cat .agent/pipeline/.ux-task.md)" Enter
sleep 1
tmux send-keys -t "$UX_PANE" Enter
```

**Code Reviewer** (interactive TUI — two-Enter pattern):
```bash
tmux send-keys -t "$REVIEWER_PANE" "$(cat .agent/pipeline/.review-task.md)" Enter
sleep 1
tmux send-keys -t "$REVIEWER_PANE" Enter
```

Builder uses stdin redirect (single Enter, exits after each task).
Gemini and Codex run persistently — tasks are typed into the running TUI using the two-Enter pattern.

### Two-Enter Pattern (Interactive TUI Input Only)

When typing text into a running Claude/Codex/Gemini TUI prompt:

```bash
tmux send-keys -t <pane> "your text" Enter   # Type + first Enter
sleep 1                                        # Wait for autocomplete/UI
tmux send-keys -t <pane> Enter                # Submit
```

NEVER combine: `tmux send-keys "text" Enter Enter` will NOT work.

### tmux-wait Invocation

```bash
/tmux-wait prompt <PANE_ID> <timeout>        # Wait for agent to finish (DEFAULT)
/tmux-wait output <PANE_ID> "text" <timeout>  # Wait for specific text
/tmux-wait command <PANE_ID> <command>         # Execute + wait (shell only)
```

Recommended timeouts: Builder 600s, Gemini 300s, Codex 300s.
Sequential parallel waits: wait for likely-slower agent first (Gemini > Codex).

### Gemini Permission Priming

Gemini `-y` enables "auto-edit" mode (auto-approves file edits, still prompts for shell/MCP). On first use per session, Shell commands trigger "Action Required". Handle:

1. tmux-wait auto-detects "Action Required" — returns immediately
2. Approve "Allow for this session": `tmux send-keys -t <pane> Down Enter`
3. Subsequent uses of the same tool category auto-approve for the session

Codex `--full-auto` auto-approves within workspace sandbox — no priming needed for typical operations.

### CLI Auto-Detection (tmux-wait)

| CLI | Fingerprint | Prompt | Permission | Processing |
|-----|-------------|--------|------------|------------|
| Codex | `gpt-`, `% left` | `›` | `"Would you like"` (rare with --full-auto) | `• Working` |
| Gemini | `/model`, `Gemini [0-9]` | `> ` or `* ` (YOLO) | `"Action Required"` | Braille spinners `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏` |
| Claude | `for shortcuts` | `❯` or `›` | `"Do you want"` | `✻✽✶✢`, `Symbioting`, `Running.*agents` |
| Shell | (none) | `$` `#` `%` | N/A | N/A |

Permission prompts are checked against the full 50-line capture.
Prompt characters are found in the last 10 non-empty lines (TUI status bars sit below prompts).
`? for shortcuts` appears in all three CLIs — detection order (Codex → Gemini → Claude) prevents misidentification.

### STATUS.json

Location: `.agent/pipeline/STATUS.json` — Team Lead writes via Write tool after every state change.

Two-axis model:
- `stage`: build | ux_review | code_review | evaluating | fixing | done | escalated
- `activity_state`: pending | active | completed | stuck | error

Update `active_agent`, `loop_round`, verdicts, `overrides[]`, and `updated_at` on every transition. See TEAM.md for full schema.

### Task File Preparation

Templates in `.agent/templates/` have `{{TOKENS}}` — replace before sending:
- `build-task.md`: `{{TASK_DESCRIPTION}}`
- `fix-task.md`: `{{TASK_DESCRIPTION}}`, `{{UX_ISSUES}}`, `{{REVIEW_ISSUES}}`, `{{ROUND}}`
- `ux-task.md`, `review-task.md`: `{{TASK_DESCRIPTION}}`

Prepared files → `.agent/pipeline/.build-task.md` (dot prefix, gitignored).
Prepare static files ONCE before loop. Prepare fix-task INSIDE loop (changes each round).

### Artifact Cleanup

Before each pipeline run, clean stale artifacts:
```bash
rm -f .agent/pipeline/0*.md .agent/pipeline/DONE.md .agent/pipeline/PLAN.md
rm -f .agent/pipeline/.build-task.md .agent/pipeline/.ux-task.md .agent/pipeline/.review-task.md .agent/pipeline/.fix-task.md
```

### Health Check (Before Every Pipeline Run)

1. SESSION.json exists with valid pane IDs → if missing, run `start-team.sh`
2. Each pane ID still exists in tmux → if missing, recreate
3. Each pane at shell/CLI prompt (not busy) → if busy, `/tmux-wait prompt PANE 60`
4. Set lead pane ID: `tmux display-message -p '#{pane_id}'` → write to SESSION.json

### Completion Detection

- Builder finishes → exits to shell prompt (`$`) → `/tmux-wait prompt` detects it
- Gemini finishes → returns to TUI prompt (`> `) → `/tmux-wait prompt` detects it
- Codex finishes → returns to TUI prompt (`›`) → `/tmux-wait prompt` detects it
- Handoff file existence IS the signal (blackboard pattern)
- Parse `Verdict:` field for routing: APPROVED → next stage, NEEDS_REVISION → collect issues
- No handoff file after wait → activity_state "error" → retry same task
<!-- END TEMPLATE: team-ai-quick-reference -->

## Usage

Claude Code reads this file at the start of each session via the SessionStart hook.
For the full team-ai protocol including handoff format, deliberation workflow,
and retry logic, read `.agent/TEAM.md`.
