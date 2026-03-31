# Team AI Pipeline

A Claude Code skill that orchestrates multiple AI agents in a build/review pipeline using tmux. Claude Code acts as Team Lead, coordinating a Builder (Claude), UI/UX Reviewer (Gemini), and Code Reviewer (Codex) through structured handoff files.

## Overview

Team AI has two modes:

**Mode A** — Build/Review Pipeline: Give it a task, and it builds, reviews, and iterates until all reviewers approve.

**Mode B** — Multi-Perspective Review: Get UX, architecture, and devil's advocate perspectives on existing code or concepts.

### Architecture

```
You (human)
  |
  v
Claude Code (Team Lead) ──── orchestrates via tmux ────┐
  |                                                      |
  |  ┌──────────────┬──────────────┐                     |
  |  │ Builder      │ Code Reviewer│                     |
  |  │ (claude -p)  │ (Codex CLI)  │  <── team-ai window
  |  ├──────────────┼──────────────┤                     |
  |  │ UX Reviewer  │ Status       │                     |
  |  │ (Gemini CLI) │ Monitor      │                     |
  |  └──────────────┴──────────────┘                     |
  |                                                      |
  └──────── reads/writes handoff files ─────────────────┘
```

The Team Lead never writes code. It sends tasks to agents via tmux, waits for completion, reads handoff files, evaluates verdicts, and routes the next step.

## Prerequisites

| Requirement | Purpose | Install |
|---|---|---|
| **tmux** | Agent pane layout | `sudo apt install tmux` or `brew install tmux` |
| **Claude Code** | Team Lead + Builder | Already installed if you're reading this |
| **Gemini CLI** (optional) | UX Reviewer | [google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli) |
| **Codex CLI** (optional) | Code Reviewer | [openai/codex](https://github.com/openai/codex) |

If Gemini or Codex are not installed, their roles fall back to `claude -p`.

### Authentication

```bash
# Gemini uses OAuth
gemini auth login

# Codex uses subscription auth
codex auth login
```

## Setup

### 1. Install the skill

```bash
cd team-ai
./install.sh
```

### 2. Initialize your project

In any project directory, inside Claude Code:

```
/init-team-ai
```

This creates:
- `.agent/TEAM.md` — communication protocol (committed to git)
- `.agent/templates/` — task and review templates (committed)
- `scripts/start-team.sh` — tmux layout launcher (committed)
- `.agent/pipeline/` — runtime state files (gitignored)
- `.gemini/settings.json` and `.codex/config.toml` — per-developer CLI configs (gitignored)

### 3. (Optional) Set up Chrome MCP for visual testing

```
/chrome-mcp
```

This gives all agents browser access for testing web applications.

## Usage

### Mode A: Build/Review Pipeline

```
/team-ai "add rate limiting to POST /users - max 10 requests per minute per IP"
```

The pipeline runs automatically:

1. **Build** — Builder implements the feature, self-reviews, self-tests
2. **UX Review** — Gemini reviews from a user experience perspective
3. **Code Review** — Codex reviews code quality, correctness, security
4. **Evaluate** — Team Lead reads both reviews:
   - Both APPROVED: presents summary to you for commit approval
   - Any NEEDS_REVISION: evaluates each issue, sends fix instructions back to Builder, loops

The loop continues until all reviewers approve (max 10 rounds). Deliberation (Team Lead challenging a reviewer's finding) does not consume a revision round.

### Mode B: Multi-Perspective Review

```
/team-ai review src/auth.py
/team-ai review "the caching strategy"
```

Three perspectives run and synthesize:

1. **UX Perspective** (Gemini) — user experience, accessibility, ergonomics
2. **Architecture Perspective** (Codex) — code quality, scalability, maintainability
3. **Devil's Advocate** (Claude, self-directed) — challenges assumptions from both perspectives

Output is written to `.agent/reviews/YYYYMMDD-<subject>.md`.

## How the Pipeline Works

### Handoff Files (Blackboard Pattern)

Agents communicate through files in `.agent/pipeline/`:

| File | Written by | Contains |
|---|---|---|
| `01-build.md` | Builder | Summary, files changed, test results |
| `02-ux-review.md` | UX Reviewer | Verdict (APPROVED/NEEDS_REVISION), issues |
| `03-code-review.md` | Code Reviewer | Verdict (APPROVED/NEEDS_REVISION), issues |
| `STATUS.json` | Team Lead | Current stage, verdicts, overrides |
| `pipeline.log` | Team Lead | Timestamped event log |
| `DONE.md` | Team Lead | Final summary after approval |

**The handoff file IS the signal.** Its existence means the agent finished. Its `Verdict:` field determines what happens next.

### Deliberation

When the Team Lead disagrees with a reviewer's findings, it can initiate deliberation:

1. Team Lead writes a **rebuttal** with evidence-based counter-arguments
2. The reviewer reads the rebuttal and responds honestly:
   - **Concede** — acknowledges the Team Lead's reasoning is sound
   - **Maintain** — provides new evidence supporting the original finding
3. Team Lead makes the final call, logging any overrides in `STATUS.json`

Deliberation does not consume a revision round. It's a structured debate mechanism that prevents unnecessary fix cycles while maintaining accountability through logged overrides.

### Pipeline State

`STATUS.json` tracks the current state:

```json
{
  "task": "add rate limiting to POST /users",
  "stage": "code_review",
  "activity_state": "active",
  "active_agent": "reviewer",
  "loop_round": 1,
  "build_verdict": "approved",
  "ux_verdict": "approved",
  "review_verdict": "pending",
  "overrides": [
    "[code_review] Issue 2: Redis requirement overridden — in-memory matches app architecture"
  ]
}
```

The Status Monitor pane shows this live (refreshes every 5 seconds).

## Session Recovery

If the tmux session crashes or gets killed mid-pipeline:

1. **Source code changes persist** — they're in the working directory, not in tmux
2. **Re-invoke `/team-ai`** with the same task — it detects the missing tmux layout
3. `start-team.sh` recreates the panes with new IDs, `SESSION.json` is rewritten
4. Pipeline restarts from the beginning (handoff files from the previous run are cleaned)

To manually kill the session:

```bash
# If running as a window inside your tmux session
tmux kill-window -t team-ai

# If running as a standalone session
tmux kill-session -t team-ai
```

## Tmux Navigation

When using window mode (the default when you're already in tmux):

| Keys | Action |
|---|---|
| `Ctrl+B n` | Switch to team-ai window (watch agents work) |
| `Ctrl+B p` | Switch back to your window (talk to Team Lead) |
| `Ctrl+B <number>` | Jump to a specific window by index |

## File Structure

After `/init-team-ai`, your project has:

```
your-project/
  .agent/
    TEAM.md                    # Communication protocol (committed)
    PLANS.md                   # ExecPlan guidelines (gitignored)
    pipeline/                  # Runtime state (gitignored)
      SESSION.json             #   Pane IDs for tmux targeting
      STATUS.json              #   Pipeline state
      pipeline.log             #   Event log
      01-build.md              #   Builder handoff
      02-ux-review.md          #   UX review handoff
      03-code-review.md        #   Code review handoff
      DONE.md                  #   Final summary
    templates/                 # Task templates (committed)
      build-task.md            #   Builder initial task
      fix-task.md              #   Builder revision task
      ux-task.md               #   UX review task
      review-task.md           #   Code review task
      ux-deliberation.md       #   UX deliberation prompt
      review-deliberation.md   #   Code review deliberation prompt
      perspective-ux.md        #   Mode B: UX perspective
      perspective-arch.md      #   Mode B: architecture perspective
      perspective-devil.md     #   Mode B: devil's advocate
      review-synthesis.md      #   Mode B: synthesis prompt
    reviews/                   # Mode B outputs (committed)
      20260331-server-js.md    #   Example synthesis
  scripts/
    start-team.sh              # Tmux layout launcher (committed)
  .gemini/
    settings.json              # Gemini CLI config (gitignored)
  .codex/
    config.toml                # Codex CLI config (gitignored)
```

## Related Skills

| Skill | Purpose |
|---|---|
| `/init-team-ai` | Scaffold pipeline infrastructure in a project |
| `/see-terminal` | View or control any tmux pane |
| `/tmux-wait` | Wait for agent completion (prompt detection) |
| `/chrome-mcp` | Set up Chrome DevTools for visual testing |

## Tips

- **Reduce permission prompts**: Press `Shift+Tab` to cycle to `acceptEdits` mode before starting a pipeline run
- **Watch agents work**: `Ctrl+B n` switches to the team-ai window where you can see all agents in real-time
- **All agents are persistent**: Claude (Builder), Gemini (UX), and Codex (Code Review) all stay running between tasks in interactive mode
- **Templates are committed**: Your team shares the same task templates and protocol via git. Runtime state is gitignored
- **Override logging**: Every time the Team Lead overrides a reviewer finding, it's logged in STATUS.json with reasoning — this creates an audit trail

## License

MIT License - See LICENSE file in the repository root.
