# Team AI Communication Protocol

All agents must read this file before beginning any pipeline task.
The working directory for all file paths is the project root.

## Roles

Team Lead (Claude Code, pane saved in SESSION.json as "lead")
  Orchestrates the pipeline. Reads all handoff files, routes feedback
  to the Builder, escalates critical decisions to the user, presents
  the final summary. Never writes code. Updates STATUS.json.

Builder (Claude via claude -p, pane saved as "builder")
  Implements features, self-reviews, self-tests (uses Chrome MCP for
  browser apps). Writes 01-build.md after each build/fix cycle.
  Only modifies source code when instructed by the Team Lead.

UI/UX Reviewer (Gemini CLI or Claude fallback, pane saved as "ux")
  Runs non-interactively via: gemini -y < taskfile
  Reviews code and tests visually using Chrome MCP for browser apps.
  Writes 02-ux-review.md. Does NOT modify code.

Code Reviewer (Codex CLI, pane saved as "reviewer")
  Runs non-interactively via: codex exec --full-auto - < taskfile
  Reviews code quality, correctness, style, and security.
  Can also test visually using Chrome MCP for browser apps.
  Writes 03-code-review.md. Does NOT modify code.

Status Monitor (pane saved as "monitor")
  Passive display pane — no agent runs here. Shows a live refresh of
  STATUS.json, handoff file listing, and the last 20 lines of pipeline.log.
  Useful for debugging; may be removed in a future version.

## Pipeline Stages

Stage 1 (Build):
  Builder implements, self-reviews, self-tests (Chrome MCP if browser app).
  Output: .agent/pipeline/01-build.md  [Verdict: APPROVED]

Stage 2 (UI/UX Review):
  UI/UX Reviewer reviews code and tests visually.
  Output: .agent/pipeline/02-ux-review.md [Verdict: APPROVED or NEEDS_REVISION]

Stage 3 (Code Review):
  Code Reviewer reviews code quality, correctness, and style.
  Output: .agent/pipeline/03-code-review.md [Verdict: APPROVED or NEEDS_REVISION]

Stage 4 (Evaluate):
  Team Lead reads all feedback. If issues found: collects feedback,
  sends Builder specific fix instructions, loop back to Stage 1.
  If critical decision: escalate to user.
  If all clean: present final summary to user for approval before commit.

Completion detection: The handoff file IS the signal. When an agent
finishes, it writes its handoff file and exits. The Team Lead detects
completion via tmux-wait (pane returns to shell), then reads the
handoff file and parses its Verdict field for routing.

## Handoff File Format

Every handoff file must use exactly this structure:

  # Stage N — [Stage Name] Handoff

  ## Summary
  2-3 sentences describing what was done.

  ## Files Changed
  - path/to/file.py — brief description of change

  ## Lineage
  Brief history of prior decisions relevant to this stage:
  - Round N (ux_review): UI/UX issues raised, what was fixed, what was disputed/overridden
  - Round N (code_review): code issues raised, what was fixed, what was disputed/overridden
  (Leave empty on first pass. Team Lead populates this on revision rounds
  so the Builder and reviewers understand what has already been tried and decided.)

  ## Verdict
  APPROVED  (or)  NEEDS_REVISION

  ## Issues
  1. Specific, actionable issue. (leave empty if none)

  ## Suggestions
  - Non-blocking improvement ideas. (leave empty if none)

  ## Ready For Next Stage
  true  (or)  false

  ## Route
  NEXT  (or)  BACK_TO_BUILDER

## Completion Detection

The pipeline uses handoff files as both payload and coordination signal
(the "blackboard pattern"). When an agent finishes, it writes its handoff
file (e.g., 02-ux-review.md). The Team Lead detects completion via tmux-wait
(pane returns to shell prompt), then checks for the handoff file and parses
the Verdict field. No separate signal files are needed — the handoff file's
existence IS the signal, and its Verdict field IS the routing decision.

Completion detection flow:
1. tmux-wait returns (pane at shell prompt) → agent has exited
2. Check if expected handoff file exists (e.g., 02-ux-review.md)
3. If exists: parse Verdict field → route accordingly
4. If missing: treat as error, log, increment round counter, retry

For deliberation: the response file (e.g., deliberation-review-1-response.md)
serves the same role — its existence means the reviewer has responded.

## SESSION.json Schema

Location: .agent/pipeline/SESSION.json
Written by start-team.sh when the team-ai panes are created.
Contains stable pane IDs so the Team Lead can always find its teammates.

  {
    "session": "current-session-name",
    "window": "team-ai",
    "mode": "window",
    "created_at": "ISO8601 timestamp",
    "panes": {
      "lead":     "%5",
      "builder":  "%6",
      "ux":       "%7",
      "reviewer": "%8",
      "monitor":  "%9"
    }
  }

The actual %N numbers are assigned dynamically at creation time.
"mode" is either "window" (panes in current tmux session) or "session"
(standalone tmux session — fallback when not already in tmux).
In window mode, the team-ai panes live in a new window of the current
session. Switch to them with Ctrl+B n, switch back with Ctrl+B p.
In session mode, view them with: tmux attach -t team-ai.

## STATUS.json Schema

Location: .agent/pipeline/STATUS.json
Updated by Team Lead after every state change.

  {
    "task": "short task description",
    "stage": "build|ux_review|code_review|evaluating|fixing|done|escalated|review-mode-b",
    "activity_state": "pending|active|completed|stuck|error",
    "active_agent": "lead|builder|ux|reviewer|none",
    "loop_round": 0,
    "started_at": "ISO8601 timestamp",
    "updated_at": "ISO8601 timestamp",
    "build_verdict": "pending|approved",
    "ux_verdict": "pending|approved|needs_revision",
    "review_verdict": "pending|approved|needs_revision",
    "last_issue": "most recent rejection reason, or empty string",
    "overrides": []
  }

"stage" tracks where in the pipeline we are (lifecycle axis).
"activity_state" tracks the liveness of the currently active agent (health axis):
  pending   — agent has not been invoked yet for this stage
  active    — agent command was sent, tmux-wait is running
  completed — agent finished (pane returned to shell prompt); Team Lead routes next
  stuck     — tmux-wait timed out; agent appears blocked or unresponsive
  error     — agent produced no handoff file, or handoff was malformed
These two axes together let the Team Lead distinguish "Codex finished and
returned APPROVED" from "Codex timed out and is stuck" without polling the
pane repeatedly. Since Codex and Gemini exit after each task (ephemeral
executors, not persistent daemons), there is no distinction between "idle"
and "exited" — both are simply "completed".
"active_agent" names which agent is currently responsible.
"loop_round" counts how many full build→ux_review→code_review loops
have run. The pipeline loops until both reviewers approve with no
issues, or until the Team Lead escalates a critical decision to the user.
The "overrides" array accumulates any points where the Team Lead decided to
proceed despite a maintained objection. Each entry is a short string:
"[stage] issue N: <reason for override>".

## Deliberation Files

When the Team Lead disputes any reviewer findings, it writes a rebuttal:
  .agent/pipeline/deliberation-ux-N-rebuttal.md       (for UI/UX review disputes)
  .agent/pipeline/deliberation-ux-N-response.md       (Gemini's response)
  .agent/pipeline/deliberation-review-N-rebuttal.md   (for code review disputes)
  .agent/pipeline/deliberation-review-N-response.md   (Codex's response)
where N is the loop round number.
The stage prefix prevents naming collisions when both stages
reach the same round number within a single pipeline run.

Rebuttal format (written by Team Lead):
  # Deliberation Rebuttal — [Stage] Round N
  Stage: ux (or review)
  Timestamp: ISO8601

  ## Issues I Agree With (Builder will fix)
  - Issue [number]: <what will be changed>

  ## Issues I Dispute
  - Issue [number]: <counter-argument>
    Evidence: <file:line, test output, or reasoning>
    Proposed Resolution: <what Team Lead proposes instead>

Response format (written by reviewer):
  # Deliberation Response — [Stage] Round N
  Timestamp: ISO8601

  ## Conceded Points
  - Issue [number]: <reasoning for concession>

  ## Maintained Points
  - Issue [number]: <reasoning, any new evidence>

After reading the response, Team Lead makes the final call. Maintained
points may be added to the Builder's fix instructions, accepted as valid,
or overridden with logged reasoning. The Builder never interacts with
reviewers directly — the Team Lead is always the intermediary.

## Retry Limits

Maximum 5 revision rounds per stage (independent budgets).
UX review stage: up to 5 rounds before escalating.
Code review stage: up to 5 rounds before escalating.
Budgets are independent — UX rounds do not consume code review budget and vice versa.
Deliberation does not consume a revision round — it is part of the same round.
On the 6th rejection within a stage, Team Lead escalates to the user.

## Environment Variables

The following environment variables must be set in the shell before running /team-ai.
They are inherited by tmux panes created by start-team.sh (new-session passes the
current environment automatically). If they are not set, agents will fail silently.

  ANTHROPIC_API_KEY — required by `claude -p` (Builder). Set in your shell profile or .env.
  OPENAI_API_KEY    — required by `codex exec` (Code Reviewer). Set in your shell profile or .env.
  GEMINI_API_KEY    — required by Gemini CLI unless authenticated via `gemini auth login`.

To verify they are set in the pane environment after the session starts:
  tmux send-keys -t %BUILDER  "echo $ANTHROPIC_API_KEY" Enter
  tmux send-keys -t %UX       "echo $GEMINI_API_KEY"  Enter
  tmux send-keys -t %REVIEWER "echo $OPENAI_API_KEY"  Enter

## Gitignore Note

.agent/pipeline/ is gitignored (ephemeral runtime artifacts).
.agent/PLANS.md is gitignored (local authoring guidelines).
.agent/TEAM.md, .agent/templates/, and .agent/reviews/ ARE committed.
.gemini/settings.json is gitignored (local browser config — each dev sets up their own).
.codex/ is gitignored (local Codex config — each dev sets up their own).
Run /chrome-mcp to install Chrome, then /init-team-ai to create these local config files.
