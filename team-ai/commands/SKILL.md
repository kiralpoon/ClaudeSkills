---
name: team-ai
description: Run the team AI pipeline — multi-agent build/review/fix loop or multi-perspective review
argument-hint: "<task description>" or "review <subject>"
allowed-tools: Read(*), Write(*), Edit(*), Bash(*), Glob(*), Grep(*), Skill(tmux-wait), Skill(see-terminal)
---

# Team AI Pipeline

## 🚫 CRITICAL: ALWAYS USE Skill("tmux-wait") — NEVER INLINE THE POLL LOOP 🚫

**Every time you need to wait for a tmux pane, STOP and invoke the Skill tool. Do NOT copy-paste the bash poll loop.**

| ❌ NEVER DO THIS | ✅ ALWAYS DO THIS |
|------------------|-------------------|
| Copy-paste the poll loop bash from tmux-wait docs | `Skill("tmux-wait", "prompt %41 300")` |
| `while ((poll_count++ < MAX_POLLS)); do ...` | `Skill("tmux-wait", "prompt $PANE 300")` |
| `sleep N && tmux capture-pane` | `Skill("tmux-wait", ...)` then `Skill("see-terminal", ...)` |

**This applies to ALL wait operations in Mode A and Mode B — every stage, every agent pane.**

Anywhere this SKILL.md shows:
```
/tmux-wait prompt $PANE 300
```
That means: **invoke the Skill tool** → `Skill("tmux-wait", "prompt $PANE 300")` — not a shell command.

---

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

## Division of Responsibility: Team Lead vs. Monitor

`scripts/monitor.sh` runs continuously in the Monitor pane and acts as an automatic STATUS.json updater. Understanding what it owns vs. what the Team Lead owns prevents conflicts:

| Responsibility | Owner |
|----------------|-------|
| `build_verdict`, `ux_verdict`, `review_verdict`, `devil_verdict`, `builder_verdict` | **monitor.sh** — set automatically when handoff files appear |
| `stage`, `activity_state`, `active_agent`, `loop_round` | **Team Lead** — set manually at each pipeline transition |
| `pipeline.log` entries for handoff arrivals | **monitor.sh** |
| `pipeline.log` entries for decisions, routing, overrides | **Team Lead** |

Active verdict fields by mode:
- **Mode A**: `build_verdict`, `ux_verdict`, `review_verdict`
- **Mode B**: `ux_verdict` (from ux-findings.md), `review_verdict` (from arch-findings.md), `devil_verdict`, `builder_verdict`

The Team Lead reads verdict fields from STATUS.json or the handoff files for routing decisions. It does **not** write verdict fields.

---

## Session Health Check (Both Modes)

### Step 1: Ensure tmux team-ai layout exists

`start-team.sh` creates either a window named `team-ai` inside the current session (when already in tmux) or a standalone session named `team-ai`. Check for both:

```bash
# Check for team-ai as a window in any session, OR as a standalone session
tmux list-windows -a -F '#{window_name}' 2>/dev/null | grep -q '^team-ai$' || \
tmux has-session -t team-ai 2>/dev/null
```

If both fail, run `bash scripts/start-team.sh` and wait 5 seconds for CLIs to start.

### Step 2: Read SESSION.json

Read `.agent/pipeline/SESSION.json` and extract pane IDs into variables:

- `BUILDER_PANE` = panes.builder
- `UX_PANE` = panes.ux
- `REVIEWER_PANE` = panes.reviewer
- `MONITOR_PANE` = panes.monitor

If SESSION.json is missing or corrupt:

```
team-ai layout is running but SESSION.json is missing.
Kill it with: tmux kill-window -t team-ai  (or tmux kill-session -t team-ai if standalone)
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

> **Monitor pane:** `start-team.sh` automatically starts `scripts/monitor.sh` in the Monitor pane. It runs `bash scripts/monitor.sh` and needs no further action from the Team Lead. If the Monitor pane is missing or crashed, re-run `start-team.sh` to restore it.

### Step 5: Check pane readiness

For each worker pane, check if busy:

```bash
tmux display-message -p -t "$PANE_ID" '#{pane_current_command}'
```

If the result is not a shell (`bash`, `zsh`, `sh`, `fish`) AND not `claude`, `codex`, or `gemini` (the persistent TUI agents — all run as `node` process), the pane is busy with a previous task. Use `/tmux-wait prompt PANE_ID 60` to wait.

**IMPORTANT**: All three agents (Claude Builder, Gemini, Codex) run persistently in interactive mode. They do NOT need to be restarted between tasks. Send tasks via two-Enter pattern into their running TUI.

**TUI Crash Detection**: If any agent pane is running a bare shell (`bash`, `zsh`, `sh`, `fish`) instead of the expected TUI, the agent has crashed or exited. Restart it:

- **Builder crashed**: `tmux send-keys -t "$BUILDER_PANE" "claude" Enter` then `/tmux-wait prompt $BUILDER_PANE 60`
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

> **Tip:** The pipeline makes many file edits (STATUS.json, task files, handoffs). To reduce
> permission confirmation fatigue, suggest the user enable `acceptEdits` mode (Shift+Tab to cycle
> permission modes) before starting. Alternatively, ensure `.claude/settings.local.json` has
> broad `"Bash"` and `"Write"` permissions.

## Step A1: Clean Pipeline State

Deletes all handoff and task files from any previous run. Step A3 immediately recreates the task files for the new task — this cleanup ensures `scripts/monitor.sh` doesn't re-detect stale handoffs from prior runs and write stale verdict values.

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

**Send to Builder pane (interactive TUI — two-Enter pattern, do NOT paste file content):**

Tell the agent to read the task file itself (pasting raw content via `$(cat)` breaks TUI input due to special characters like `{}`, `$`, backticks):

Round 1:
```bash
tmux send-keys -t "$BUILDER_PANE" "Read and follow all instructions in .agent/pipeline/.build-task.md" Enter
sleep 1
tmux send-keys -t "$BUILDER_PANE" Enter
```

Round > 1:
```bash
tmux send-keys -t "$BUILDER_PANE" "Read and follow all instructions in .agent/pipeline/.fix-task.md" Enter
sleep 1
tmux send-keys -t "$BUILDER_PANE" Enter
```

**Log:** `[timestamp] Build task sent to Builder (round LOOP_ROUND). Pane: BUILDER_PANE`

**Wait:**
```
/tmux-wait prompt $BUILDER_PANE 600
```

**Verify pane state:** Always check the terminal after waiting to confirm the agent actually finished:
```
/see-terminal $BUILDER_PANE 100
```

**Check handoff:** If `.agent/pipeline/01-build.md` missing, set activity_state=error, log, and re-send by using the two-Enter pattern again into the running Builder TUI (do NOT restart claude).

**Mark complete:** Update STATUS.json: activity_state=completed. (`build_verdict` is set automatically by monitor.sh when `01-build.md` appears.)

Log: `[timestamp] Build complete (round LOOP_ROUND). Handing off to UI/UX Reviewer.`

### Stage 2: UI/UX Review

> **Parallel option:** Stages 2 and 3 (UX Review and Code Review) are independent — both read
> `01-build.md` but do not depend on each other's output. You MAY run them in parallel by sending
> both tasks before waiting, then waiting for both sequentially. Sequential execution (as written
> below) is the default because it is simpler to debug. **Note:** If run in parallel, the Code
> Reviewer won't have `02-ux-review.md` available — this is acceptable since its review-task.md
> lists that file as context, not a hard requirement.

**Clean stale handoff:**
```bash
rm -f .agent/pipeline/02-ux-review.md
```

**Update STATUS.json:** stage=ux_review, activity_state=active, active_agent=ux

**Send to Gemini pane (interactive TUI — two-Enter pattern, do NOT paste file content):**

Tell the agent to read the task file itself (pasting raw content via `$(cat)` breaks TUI input due to special characters like `{}`, `$`, backticks):

```bash
tmux send-keys -t "$UX_PANE" "Read and follow all instructions in .agent/pipeline/.ux-task.md" Enter
sleep 1
tmux send-keys -t "$UX_PANE" Enter
```

**Log:** `[timestamp] UI/UX review sent to Gemini (round LOOP_ROUND). Pane: UX_PANE`

**Wait (with race-condition guard):**

TUI agents (Gemini, Codex) need time to receive input and begin processing. The first tmux-wait poll can catch the pane in its previous idle state before the agent starts, causing a false 0s return.

```bash
sleep 5  # Let TUI receive input and start processing
```
```
/tmux-wait prompt $UX_PANE 300
```

**Verify handoff exists (re-wait if race condition hit):**
```bash
test -f .agent/pipeline/02-ux-review.md
```
If the file does NOT exist, the agent is still working — re-invoke tmux-wait:
```
/tmux-wait prompt $UX_PANE 300
```
Repeat up to 2 more times (3 total waits: 1 initial + 2 retries). After the final wait, verify with `/see-terminal`:
```
/see-terminal $UX_PANE 100
```

**Check handoff:** If `.agent/pipeline/02-ux-review.md` is STILL missing after re-waits:
1. Use `/see-terminal $UX_PANE 200` to capture the agent's full text output
2. If the agent completed its analysis (findings visible in terminal), extract the review verdict and issues, then construct `.agent/pipeline/02-ux-review.md` yourself using the handoff format from TEAM.md
3. Log: `[timestamp] Handoff file missing from Gemini — constructed from terminal output`
4. If the terminal shows no useful output (agent crashed or empty response), THEN set activity_state=error, log, and re-send the task

**Parse verdict:** Read `02-ux-review.md`, extract `Verdict:` field.

> **Note:** `scripts/monitor.sh` has already written `ux_verdict` to STATUS.json automatically when the handoff file appeared. You are reading the verdict for routing logic — do NOT overwrite it.

**Update STATUS.json:** activity_state=completed (stage and verdict are already set by monitor).

Log: `[timestamp] UI/UX review complete (round LOOP_ROUND). Verdict: VERDICT.`

### Stage 3: Code Review

**Clean stale handoff:**
```bash
rm -f .agent/pipeline/03-code-review.md
```

**Update STATUS.json:** stage=code_review, activity_state=active, active_agent=reviewer

**Send to Codex pane (interactive TUI — two-Enter pattern, do NOT paste file content):**

Tell the agent to read the task file itself (pasting raw content via `$(cat)` breaks TUI input due to special characters):

```bash
tmux send-keys -t "$REVIEWER_PANE" "Read and follow all instructions in .agent/pipeline/.review-task.md" Enter
sleep 1
tmux send-keys -t "$REVIEWER_PANE" Enter
```

**Log:** `[timestamp] Code review sent to Codex (round LOOP_ROUND). Pane: REVIEWER_PANE`

**Wait (with race-condition guard):**

```bash
sleep 5  # Let TUI receive input and start processing
```
```
/tmux-wait prompt $REVIEWER_PANE 300
```

**Verify handoff exists (re-wait if race condition hit):**
```bash
test -f .agent/pipeline/03-code-review.md
```
If the file does NOT exist, the agent is still working — re-invoke tmux-wait:
```
/tmux-wait prompt $REVIEWER_PANE 300
```
Repeat up to 2 more times (3 total waits: 1 initial + 2 retries). After the final wait, verify with `/see-terminal`:
```
/see-terminal $REVIEWER_PANE 100
```

**Check handoff:** If `.agent/pipeline/03-code-review.md` is STILL missing after re-waits:
1. Use `/see-terminal $REVIEWER_PANE 200` to capture the agent's full text output
2. If the agent completed its analysis (findings visible in terminal), extract the review verdict and issues, then construct `.agent/pipeline/03-code-review.md` yourself using the handoff format from TEAM.md
3. Log: `[timestamp] Handoff file missing from Codex — constructed from terminal output`
4. If the terminal shows no useful output (agent crashed or empty response), THEN set activity_state=error, log, and re-send the task

**Parse verdict:** Read `03-code-review.md`, extract `Verdict:` field.

> **Note:** `scripts/monitor.sh` has already written `review_verdict` to STATUS.json automatically when the handoff file appeared. You are reading the verdict for routing logic — do NOT overwrite it.

**Update STATUS.json:** activity_state=completed (stage and verdict are already set by monitor).

Log: `[timestamp] Code review complete (round LOOP_ROUND). Verdict: VERDICT.`

### Stage 4: Evaluate

**Update STATUS.json:** stage=evaluating, active_agent=lead

**Read both review files and collect all issues.**

> **Note:** `scripts/monitor.sh` automatically updates `ux_verdict` and `review_verdict` in STATUS.json as soon as handoff files arrive. Read the verdict fields from STATUS.json (or directly from the handoff files) for routing — do NOT write these fields yourself, as you would overwrite the monitor's values.

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
- Devil's advocate is always Claude (runs in Builder pane)

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

If ux_agent = "gemini" (interactive TUI — do NOT paste file content, it breaks TUI input):
```bash
tmux send-keys -t "$UX_PANE" "Read and follow all instructions in .agent/pipeline/.ux-task.md" Enter
sleep 1
tmux send-keys -t "$UX_PANE" Enter
```

If ux_agent = "claude" (fallback, interactive two-Enter pattern):
```bash
tmux send-keys -t "$UX_PANE" "Read and follow all instructions in .agent/pipeline/.ux-task.md" Enter
sleep 1
tmux send-keys -t "$UX_PANE" Enter
```

**Send Architecture task to Codex pane:**

If arch_agent = "codex" (interactive TUI — do NOT paste file content, it breaks TUI input):
```bash
tmux send-keys -t "$REVIEWER_PANE" "Read and follow all instructions in .agent/pipeline/.arch-task.md" Enter
sleep 1
tmux send-keys -t "$REVIEWER_PANE" Enter
```

If arch_agent = "claude" (fallback, interactive two-Enter pattern):
```bash
tmux send-keys -t "$REVIEWER_PANE" "Read and follow all instructions in .agent/pipeline/.arch-task.md" Enter
sleep 1
tmux send-keys -t "$REVIEWER_PANE" Enter
```

**Wait for both (sequential waits, parallel execution, with race-condition guard):**

TUI agents need time to receive the two-Enter input and begin processing. Without a delay, the first tmux-wait poll catches the previous idle state and returns 0s.

```bash
sleep 5  # Let both TUIs receive input and start processing
```

Wait for the likely-slower agent first (Gemini > Codex heuristic):
```
/tmux-wait prompt $UX_PANE 300
```

**Verify UX findings file exists (re-wait if race condition hit):**
```bash
test -f .agent/pipeline/ux-findings.md
```
If the file does NOT exist, the agent is still working — re-invoke tmux-wait:
```
/tmux-wait prompt $UX_PANE 300
```

Now wait for the other agent:
```
/tmux-wait prompt $REVIEWER_PANE 300
```

**Verify arch findings file exists (re-wait if race condition hit):**
```bash
test -f .agent/pipeline/arch-findings.md
```
If the file does NOT exist, re-invoke tmux-wait:
```
/tmux-wait prompt $REVIEWER_PANE 300
```

**Verify pane state with /see-terminal (MANDATORY):**

After file verification, you MUST visually verify each pane completed properly:
```
/see-terminal $UX_PANE 100
/see-terminal $REVIEWER_PANE 100
```
Do NOT skip this step. Check that each agent actually processed the task and wrote meaningful output. A file existing does not guarantee the content is correct — the agent may have written a partial or malformed file before crashing.

**For each STILL missing findings file:**
1. Use `/see-terminal <PANE> 200` to capture the agent's full text output
2. Extract the perspective findings from the terminal text
3. Write the findings file yourself (e.g., `.agent/pipeline/ux-findings.md`)
4. Log which files were constructed from terminal output
5. If the terminal shows no useful output (agent crashed), re-send the task

## Step B6: Run Devil's Advocate

Read `ux-findings.md` and `arch-findings.md`.

Read `.agent/templates/perspective-devil.md`, replace `{{SUBJECT}}`, `{{UX_FINDINGS}}`, `{{ARCH_FINDINGS}}`, write to `.agent/pipeline/.devil-task.md`.

**Send to Builder pane (Claude interactive TUI — two-Enter pattern):**

The Builder pane has Claude running idle during Mode B. Use it for the devil's advocate to get a genuinely independent perspective — do NOT write the devil's findings yourself.

```bash
tmux send-keys -t "$BUILDER_PANE" "Read and follow all instructions in .agent/pipeline/.devil-task.md" Enter
sleep 1
tmux send-keys -t "$BUILDER_PANE" Enter
```

**Log:** `[timestamp] Devil's advocate task sent to Builder. Pane: BUILDER_PANE`

**Wait (with race-condition guard):**

```bash
sleep 5  # Let TUI receive input and start processing
```
```
/tmux-wait prompt $BUILDER_PANE 300
```

**Verify handoff exists (re-wait if race condition hit):**
```bash
test -f .agent/pipeline/devil-findings.md
```
If the file does NOT exist, re-invoke tmux-wait:
```
/tmux-wait prompt $BUILDER_PANE 300
```

**Verify pane state (MANDATORY):**
```
/see-terminal $BUILDER_PANE 100
```
Check that the Builder actually completed the devil's advocate analysis. If the file is still missing after verification, construct it from terminal output.

## Step B7: Synthesize

> **Note:** `scripts/monitor.sh` automatically writes `ux_verdict`, `review_verdict`, `devil_verdict`, and `builder_verdict` to STATUS.json as each findings file appears. Mode B findings use `## Overall * Verdict` headings (not a bare `Verdict:` line) — the monitor parses both formats. You do not need to parse or set these fields manually.

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
2. **Update STATUS.json after every state change** — stage, activity_state, active_agent, and timestamps. Verdict fields (`build_verdict`, `ux_verdict`, `review_verdict`, etc.) are owned by `scripts/monitor.sh` and updated automatically — do not write them manually.
3. **All agents run persistently in interactive mode** — do NOT restart them between tasks. Send tasks via two-Enter pattern into their running TUI.
4. **Builder (Claude) runs interactively** — like Gemini and Codex, it stays running between tasks. Send build/fix instructions via two-Enter pattern.
5. **Read .agent/TEAM.md** at the start for the full protocol — this SKILL.md is the orchestration skeleton, TEAM.md has the complete handoff format, deliberation rules, and retry limits.
6. **The handoff file IS the signal** — its existence means the agent is done, its Verdict field determines routing.
7. **Deliberation does not consume a revision round** — it's part of the same round.
8. **Independent 5-round budgets** — UX review and code review each get up to 5 rejections before escalating.
9. **Always verify with /see-terminal** — after every `/tmux-wait` call, use `/see-terminal` to visually confirm the pane is in the expected state. Never assume a pane is ready based solely on tmux-wait returning success. The Team Lead must double-check the tmux session properly before making decisions.
10. **Builder runs interactively** — Claude runs in the Builder pane like Gemini/Codex. Send tasks via the two-Enter pattern. The Builder's permission mode should be set to `acceptEdits` (Shift+Tab) or have broad permissions in settings.
11. **Detect TUI crashes** — before sending tasks to Gemini or Codex, verify their TUI is still running. If the pane shows a bare shell, restart the TUI before proceeding.
12. **Guard against TUI race conditions** — after sending a task to Gemini or Codex via the two-Enter pattern, always `sleep 5` before invoking `/tmux-wait`. TUI agents need time to process input and begin showing active indicators. Without this delay, tmux-wait's first poll catches the previous idle state and returns 0s. After tmux-wait returns, always check if the expected output file exists. If it doesn't, the agent is still working — re-invoke tmux-wait. This verify-or-re-wait loop (up to 2 retries) is mandatory for Gemini and Codex panes.
13. **ALWAYS use `Skill("tmux-wait", ...)` — never inline the bash poll loop.** Every `/tmux-wait` reference in this file means a Skill tool invocation, not a shell command. Inlining the loop defeats the skill system, bloats the context, and bypasses timeout handling. No exceptions.
