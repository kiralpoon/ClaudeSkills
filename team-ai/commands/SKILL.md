---
name: team-ai
description: Run the team AI pipeline — multi-agent build/review/fix loop or multi-perspective review
argument-hint: "<task description>" or "review <subject>"
allowed-tools: Read(*), Write(*), Edit(*), Bash(*), Glob(*), Grep(*), Skill(tmux-wait), Skill(see-terminal)
---

# Team AI Pipeline

## Mode Detection

Parse `$ARGS` to determine mode:

- If `$ARGS` starts with `review` (case-insensitive) or contains "perspectives" or "different angles": **Mode B** (multi-perspective review). The subject is everything after the `review` keyword.
- Otherwise: **Mode A** (build/review pipeline). The task description is `$ARGS`.

If `$ARGS` is empty, print usage and stop:

```
Usage:
  /team-ai "add input validation to the login endpoint"   — Mode A: build/review pipeline
  /team-ai review src/auth.py                              — Mode B: multi-perspective review
  /team-ai review "the caching strategy"                   — Mode B: review a concept
```

---

## Prerequisites Check (Both Modes)

Verify these files exist (created by `/init-team-ai`):

- `.agent/TEAM.md`
- `.agent/templates/build-task.md`
- `scripts/start-team.sh`

If any are missing, print:

```
Run /init-team-ai first to scaffold the pipeline infrastructure.
```

Then stop.

---

## Session Health Check (Both Modes)

### Step 1: Ensure tmux session exists

```bash
tmux has-session -t team-ai 2>/dev/null
```

If it fails, run `bash scripts/start-team.sh` and wait 5 seconds for CLIs to start.

### Step 2: Read SESSION.json

Read `.agent/pipeline/SESSION.json` and extract pane IDs into variables:

- `BUILDER_PANE` = panes.builder
- `UX_PANE` = panes.ux
- `REVIEWER_PANE` = panes.reviewer
- `MONITOR_PANE` = panes.monitor

If SESSION.json is missing or corrupt:

```
team-ai session is running but SESSION.json is missing. Run: tmux kill-session -t team-ai
Then re-invoke /team-ai.
```

### Step 3: Record Team Lead pane

```bash
LEAD_PANE=$(tmux display-message -p '#{pane_id}')
```

Update SESSION.json's `lead` field with this value using the Edit tool.

### Step 4: Verify pane IDs exist

For each pane ID, verify it exists:

```bash
tmux list-panes -a -F '#{pane_id}' | grep -q "^%N$"
```

If any pane is missing, re-run `bash scripts/start-team.sh`, sleep 5, re-read SESSION.json.

### Step 5: Check pane readiness

For each worker pane, check if busy:

```bash
tmux display-message -p -t "$PANE_ID" '#{pane_current_command}'
```

If the result is not a shell (`bash`, `zsh`, `sh`, `fish`) AND not `codex` or `gemini` (the persistent TUI agents), the pane is busy with a previous task. Use `/tmux-wait prompt PANE_ID 60` to wait.

**IMPORTANT**: Gemini and Codex run persistently in interactive mode. They do NOT need to be restarted between tasks. Only the Builder (claude -p) is invoked per task.

**TUI Crash Detection**: If the UX pane (Gemini) or Reviewer pane (Codex) is running a bare shell (`bash`, `zsh`, `sh`, `fish`) instead of the expected TUI, the agent has crashed or exited. Restart it:

- **Gemini crashed**: `tmux send-keys -t "$UX_PANE" "gemini -y" Enter` then `/tmux-wait prompt $UX_PANE 30`
- **Codex crashed**: `tmux send-keys -t "$REVIEWER_PANE" "codex --full-auto" Enter` then `/tmux-wait prompt $REVIEWER_PANE 30`

Always verify with `/see-terminal` after restarting to confirm the TUI is ready.

### Step 6: Verify all panes with /see-terminal

**CRITICAL:** Before starting any pipeline work, visually verify each pane is in the expected state:

```
/see-terminal $BUILDER_PANE
/see-terminal $UX_PANE
/see-terminal $REVIEWER_PANE
```

Do NOT skip this step. The Team Lead must double-check the tmux session properly and see each terminal before jumping into any conclusion about readiness.

Log: `[timestamp] Session healthy. Lead: LEAD_PANE, Builder: BUILDER_PANE, UX: UX_PANE, Reviewer: REVIEWER_PANE`

---

# MODE A — Build/Review Pipeline

## Step A1: Clean Pipeline State

```bash
rm -f .agent/pipeline/0*.md .agent/pipeline/DONE.md .agent/pipeline/PLAN.md
rm -f .agent/pipeline/.build-task.md .agent/pipeline/.ux-task.md .agent/pipeline/.review-task.md .agent/pipeline/.fix-task.md
rm -f .agent/pipeline/deliberation-*.md
```

## Step A2: Initialize STATUS.json

Write `.agent/pipeline/STATUS.json`:

```json
{
  "task": "<TASK_DESCRIPTION>",
  "stage": "build",
  "activity_state": "pending",
  "active_agent": "builder",
  "loop_round": 0,
  "started_at": "<ISO8601>",
  "updated_at": "<ISO8601>",
  "build_verdict": "pending",
  "ux_verdict": "pending",
  "review_verdict": "pending",
  "last_issue": "",
  "overrides": []
}
```

Append to `.agent/pipeline/pipeline.log`:

```
[timestamp] ===== Pipeline started =====
[timestamp] Task: <TASK_DESCRIPTION>
```

## Step A3: Write PLAN.md and Prepare Static Task Files

Write `.agent/pipeline/PLAN.md` with the task description and 1-3 testable success criteria.

Prepare task files **once** (they only depend on the task description, which never changes):

1. Read `.agent/templates/build-task.md`, replace `{{TASK_DESCRIPTION}}`, write to `.agent/pipeline/.build-task.md`
2. Read `.agent/templates/ux-task.md`, replace `{{TASK_DESCRIPTION}}`, write to `.agent/pipeline/.ux-task.md`
3. Read `.agent/templates/review-task.md`, replace `{{TASK_DESCRIPTION}}`, write to `.agent/pipeline/.review-task.md`

Note: `fix-task.md` is prepared inside the loop (it changes each round with reviewer feedback).

## PIPELINE LOOP

Initialize `LOOP_ROUND = 0`. Loop until both reviewers approve.

### Loop Entry

1. Increment `LOOP_ROUND`
2. If `LOOP_ROUND > 10`: update STATUS.json stage to `"escalated"`, log, print "Max pipeline rounds reached (10). Please review the pipeline files manually." and **stop**.
3. Update STATUS.json: `loop_round`, `updated_at`

### Stage 1: Build

**Prepare task:**
- Round 1: use `.agent/pipeline/.build-task.md`
- Round > 1: read `.agent/templates/fix-task.md`, replace `{{TASK_DESCRIPTION}}`, `{{UX_ISSUES}}` (from 02-ux-review.md Issues section, or "None"), `{{REVIEW_ISSUES}}` (from 03-code-review.md Issues section, or "None"), `{{ROUND}}`, write to `.agent/pipeline/.fix-task.md`

**Clean stale handoff:**
```bash
rm -f .agent/pipeline/01-build.md
```

**Update STATUS.json:** stage=build, activity_state=active, active_agent=builder

**Send to Builder pane (non-interactive, single Enter):**

Round 1:
```bash
tmux send-keys -t "$BUILDER_PANE" "claude -p --allowedTools 'Edit,Write,Read,Bash,Glob,Grep' < .agent/pipeline/.build-task.md" Enter
```

Round > 1:
```bash
tmux send-keys -t "$BUILDER_PANE" "claude -p --allowedTools 'Edit,Write,Read,Bash,Glob,Grep' < .agent/pipeline/.fix-task.md" Enter
```

**IMPORTANT:** The `--allowedTools` flag is required because `claude -p` in non-interactive mode denies write operations by default.

**Log:** `[timestamp] Build task sent to Builder (round LOOP_ROUND). Pane: BUILDER_PANE`

**Wait:**
```
/tmux-wait prompt $BUILDER_PANE 600
```

**Verify pane state:** Always check the terminal after waiting to confirm the agent actually finished:
```
/see-terminal $BUILDER_PANE 100
```

**Check handoff:** If `.agent/pipeline/01-build.md` missing, set activity_state=error, log, re-send.

**Mark complete:** Update STATUS.json: build_verdict=approved, activity_state=completed.

Log: `[timestamp] Build complete (round LOOP_ROUND). Handing off to UI/UX Reviewer.`

### Stage 2: UI/UX Review

**Clean stale handoff:**
```bash
rm -f .agent/pipeline/02-ux-review.md
```

**Update STATUS.json:** stage=ux_review, activity_state=active, active_agent=ux

**Send to Gemini pane (interactive TUI — two-Enter pattern):**

Read `.agent/pipeline/.ux-task.md` content, then send via two-Enter pattern:

```bash
tmux send-keys -t "$UX_PANE" "$(cat .agent/pipeline/.ux-task.md)" Enter
sleep 1
tmux send-keys -t "$UX_PANE" Enter
```

**Log:** `[timestamp] UI/UX review sent to Gemini (round LOOP_ROUND). Pane: UX_PANE`

**Wait:**
```
/tmux-wait prompt $UX_PANE 300
```

**Verify pane state:** Always check the terminal after waiting:
```
/see-terminal $UX_PANE 100
```

**Check handoff:** If `.agent/pipeline/02-ux-review.md` missing, set activity_state=error, log, re-send.

**Parse verdict:** Read `02-ux-review.md`, extract `Verdict:` field.

**Update STATUS.json:** ux_verdict, activity_state=completed.

Log: `[timestamp] UI/UX review complete (round LOOP_ROUND). Verdict: VERDICT.`

### Stage 3: Code Review

**Clean stale handoff:**
```bash
rm -f .agent/pipeline/03-code-review.md
```

**Update STATUS.json:** stage=code_review, activity_state=active, active_agent=reviewer

**Send to Codex pane (interactive TUI — two-Enter pattern):**

Read `.agent/pipeline/.review-task.md` content, then send via two-Enter pattern:

```bash
tmux send-keys -t "$REVIEWER_PANE" "$(cat .agent/pipeline/.review-task.md)" Enter
sleep 1
tmux send-keys -t "$REVIEWER_PANE" Enter
```

**Log:** `[timestamp] Code review sent to Codex (round LOOP_ROUND). Pane: REVIEWER_PANE`

**Wait:**
```
/tmux-wait prompt $REVIEWER_PANE 300
```

**Verify pane state:** Always check the terminal after waiting:
```
/see-terminal $REVIEWER_PANE 100
```

**Check handoff:** If `.agent/pipeline/03-code-review.md` missing, set activity_state=error, log, re-send.

**Parse verdict:** Read `03-code-review.md`, extract `Verdict:` field.

**Update STATUS.json:** review_verdict, activity_state=completed.

Log: `[timestamp] Code review complete (round LOOP_ROUND). Verdict: VERDICT.`

### Stage 4: Evaluate

**Update STATUS.json:** stage=evaluating, active_agent=lead

**Read both review files and collect all issues.**

#### If BOTH verdicts are APPROVED:

Present summary to user:

```
Pipeline complete (round LOOP_ROUND). All reviews approved.

Summary: [from 01-build.md]
UX Review: APPROVED
Code Review: APPROVED
[If any overrides: list them]

Ready to commit? (y/n)
```

Wait for user response. If approved, proceed to **Done**. If user has feedback, loop again.

#### If ANY verdict is NEEDS_REVISION:

For each issue in both review files, evaluate:
- **Valid issue** → add to fix list
- **Misunderstanding** → dismiss with logged reasoning, add to STATUS.json overrides
- **Critical decision** → escalate to user

**Optional deliberation:** If you (the Team Lead) disagree with specific findings, you may write a rebuttal:
- Write `.agent/pipeline/deliberation-{ux|review}-N-rebuttal.md`
- Read the appropriate deliberation template, replace `{{TASK_DESCRIPTION}}` and `{{ROUND}}`
- Send to the reviewer pane (two-Enter pattern for Gemini/Codex)
- Wait for response file
- Parse conceded vs maintained points
- Override maintained-but-wrong points with logged reasoning

Deliberation does NOT consume a revision round.

After evaluation, go back to **Loop Entry** (Builder receives fix instructions in Stage 1).

### Done

After user approves:

1. Write `.agent/pipeline/DONE.md` with task summary, round count, verdicts, override history
2. Update STATUS.json: stage=done, activity_state=completed, active_agent=none
3. Log: `[timestamp] ===== Pipeline complete =====`
4. Print: `Pipeline complete. See .agent/pipeline/DONE.md for the full summary.`

---

# MODE B — Multi-Perspective Review

## Step B1: Determine Subject

Parse `$ARGS` — remove the leading `review` keyword. The remainder is the subject.

- If subject is a file path that exists: read it and create a 2-3 sentence summary as `CONTEXT`
- If subject is a description: use it directly as `CONTEXT`
- `SUBJECT = $ARGS` (the raw subject string)

## Step B2: Team Composition Check

Check which CLIs are available:

```bash
command -v gemini && echo "gemini available"
command -v codex && echo "codex available"
```

- If gemini missing: UX perspective falls back to `claude -p`
- If codex missing: Architecture perspective falls back to `claude -p`
- Devil's advocate is always Claude (self-directed by Team Lead)

Write `.agent/pipeline/REVIEW-CONFIG.json`:

```json
{
  "subject": "<SUBJECT>",
  "ux_agent": "gemini|claude",
  "arch_agent": "codex|claude",
  "devil_agent": "claude",
  "started_at": "<ISO8601>"
}
```

## Step B3: Initialize and Clean

Update STATUS.json: stage=review-mode-b, activity_state=active

Clean prior Mode B artifacts:

```bash
rm -f .agent/pipeline/ux-findings.md .agent/pipeline/arch-findings.md .agent/pipeline/devil-findings.md
rm -f .agent/pipeline/REVIEW-CONFIG.json
rm -f .agent/pipeline/.ux-task.md .agent/pipeline/.arch-task.md .agent/pipeline/.devil-task.md
```

## Step B4: Prepare Perspective Task Files

1. Read `.agent/templates/perspective-ux.md`, replace `{{SUBJECT}}` and `{{CONTEXT}}`, write to `.agent/pipeline/.ux-task.md`
2. Read `.agent/templates/perspective-arch.md`, replace `{{SUBJECT}}` and `{{CONTEXT}}`, write to `.agent/pipeline/.arch-task.md`

Devil's advocate task is prepared later (needs UX and arch findings).

## Step B5: Run UX and Architecture in Parallel

**Send UX task to Gemini pane:**

If ux_agent = "gemini" (interactive TUI):
```bash
tmux send-keys -t "$UX_PANE" "$(cat .agent/pipeline/.ux-task.md)" Enter
sleep 1
tmux send-keys -t "$UX_PANE" Enter
```

If ux_agent = "claude" (fallback, non-interactive):
```bash
tmux send-keys -t "$UX_PANE" "claude -p --allowedTools 'Read,Glob,Grep,Bash' < .agent/pipeline/.ux-task.md > .agent/pipeline/ux-findings.md" Enter
```

**Send Architecture task to Codex pane:**

If arch_agent = "codex" (interactive TUI):
```bash
tmux send-keys -t "$REVIEWER_PANE" "$(cat .agent/pipeline/.arch-task.md)" Enter
sleep 1
tmux send-keys -t "$REVIEWER_PANE" Enter
```

If arch_agent = "claude" (fallback, non-interactive):
```bash
tmux send-keys -t "$REVIEWER_PANE" "claude -p --allowedTools 'Read,Glob,Grep,Bash' < .agent/pipeline/.arch-task.md > .agent/pipeline/arch-findings.md" Enter
```

**Wait for both (sequential waits, parallel execution):**

```
/tmux-wait prompt $UX_PANE 300
/tmux-wait prompt $REVIEWER_PANE 300
```

Wait for the likely-slower agent first (Gemini > Codex heuristic).

**Verify findings files exist.** If either is missing (Gemini/Codex may not write to the expected path), check `/see-terminal` output to extract findings manually.

## Step B6: Run Devil's Advocate

Read `ux-findings.md` and `arch-findings.md`.

Read `.agent/templates/perspective-devil.md`, replace `{{SUBJECT}}`, `{{UX_FINDINGS}}`, `{{ARCH_FINDINGS}}`.

The devil's advocate runs as self-directed reasoning by the Team Lead (you). Write the output to `.agent/pipeline/devil-findings.md`.

## Step B7: Synthesize

Read all three findings files plus `.agent/templates/review-synthesis.md`.

Replace `{{SUBJECT}}`, `{{UX_FINDINGS}}`, `{{ARCH_FINDINGS}}`, `{{DEVIL_FINDINGS}}` in the synthesis template.

Perform the synthesis as self-directed reasoning. Write the output to:

```
.agent/reviews/<YYYYMMDD>-<subject-slug>.md
```

Where `<subject-slug>` is the subject converted to lowercase kebab-case (max 40 chars).

Create `.agent/reviews/` directory if it doesn't exist.

Update STATUS.json: stage=done, activity_state=completed.

Print:

```
Review complete. See .agent/reviews/<filename>.md for the full synthesis.
```

---

## Error Handling

- **Malformed handoff** (no Verdict line): treat as NEEDS_REVISION, increment retry counter, log
- **Timeout**: print "Agent did not finish within timeout. Check pane [PANE_ID] with /see-terminal. Continue waiting? (y/n)"
- **Missing CLI**: Use `claude -p` fallback in the respective pane
- **Session killed mid-run**: Re-invoke `/team-ai` — start-team.sh creates a new session, SESSION.json is rewritten

## Key Operational Rules

1. **Never write code yourself** — you are the Team Lead orchestrator. All code changes go through the Builder.
2. **Update STATUS.json after every state change** — stage, activity_state, active_agent, verdicts, timestamps.
3. **Gemini and Codex run persistently** — do NOT restart them between tasks. Send tasks via two-Enter pattern into their running TUI.
4. **Builder (claude -p) is invoked per task** — it exits after each task, returning the pane to a shell prompt.
5. **Read .agent/TEAM.md** at the start for the full protocol — this SKILL.md is the orchestration skeleton, TEAM.md has the complete handoff format, deliberation rules, and retry limits.
6. **The handoff file IS the signal** — its existence means the agent is done, its Verdict field determines routing.
7. **Deliberation does not consume a revision round** — it's part of the same round.
8. **Independent 5-round budgets** — UX review and code review each get up to 5 rejections before escalating.
9. **Always verify with /see-terminal** — after every `/tmux-wait` call, use `/see-terminal` to visually confirm the pane is in the expected state. Never assume a pane is ready based solely on tmux-wait returning success. The Team Lead must double-check the tmux session properly before making decisions.
10. **Builder needs --allowedTools** — always use `claude -p --allowedTools 'Edit,Write,Read,Bash,Glob,Grep'` because non-interactive mode denies write operations by default.
11. **Detect TUI crashes** — before sending tasks to Gemini or Codex, verify their TUI is still running. If the pane shows a bare shell, restart the TUI before proceeding.
