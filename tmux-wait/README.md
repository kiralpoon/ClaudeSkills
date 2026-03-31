# Tmux Smart Wait Skill

Event-driven command waiting for tmux panes using `tmux wait-for` instead of polling loops.

## Why This Skill?

Claude Code's built-in hook system (`PreToolUse`, `PostToolUse`, `SessionStart`, etc.) handles events *within* a session — reacting to tool calls, file edits, and lifecycle events. But there's no mechanism for **cross-session orchestration**: launching Claude in a tmux pane, sending it commands, waiting for it to become idle, and approving permissions from another session.

tmux-wait fills that gap by detecting Claude's UI states from outside the process via terminal capture. It solves problems that hooks fundamentally cannot:

- **Detecting when Claude is ready** — idle prompt, thinking, or showing a permission dialog
- **Coordinating between sessions** — one Claude instance testing skills in another
- **Waiting for shell commands** — in panes that aren't running Claude at all

It also replaces fragile alternatives:
- Polling loops that require permission approval every time
- Fixed `sleep` delays that waste time and are unreliable
- Complex bash scripts that are hard to maintain

See [EDGE_CASES.md](EDGE_CASES.md) for known detection issues and workarounds.

## Installation

```bash
cd tmux-wait
./install.sh
```

## Usage

The skill has three modes:

### 1. Execute Command and Wait

Execute a command in a pane and wait for completion using `tmux wait-for`:

```bash
/tmux-wait command <pane> <command>
```

**Examples:**
```bash
/tmux-wait command 0 npm test
/tmux-wait command 1 git status
/tmux-wait command {right} python script.py
```

**How it works:**
- Sends command to pane with automatic signal appended
- Blocks until command completes
- Captures and shows output

### 2. Wait for Prompt Return

Wait for shell or Claude prompt to return:

```bash
/tmux-wait prompt <pane> [timeout]
```

**Examples:**
```bash
/tmux-wait prompt 0          # Wait up to 30s for prompt
/tmux-wait prompt 1 60       # Wait up to 60s for prompt
```

**Detects:**
- Shell prompts: `$`, `#`, `%`
- Claude prompts: `❯`, `›`
- Claude Code permission prompts (auto-detected!)
- **NEW:** Claude Code processing states (Symbioting, plan mode, agents running)

**Claude Code Processing Detection:**
When a **Claude Code prompt** (`❯` or `›`) is detected, the skill intelligently checks if Claude is still actively processing before returning. This prevents false positives where the prompt appears but Claude is still working.

Detected processing states:
- `Symbioting...` - Claude is thinking/processing
- `Running.*agents` - Parallel agent execution
- `⏸ plan mode on` - Plan mode is active
- Background task indicators

**Note:** This check ONLY applies to Claude Code prompts. Regular shell prompts (`$`, `#`, `%`) return immediately without checking for thinking indicators.

**Implementation:** The skill checks only the last 5 non-empty lines near the prompt for thinking indicators, avoiding false positives from stale indicators (e.g. `✻ Cooked for...`) left over from previous operations.

**Note:** The prompt mode captures 50 lines and checks for permission prompts BEFORE checking for regular prompts, ensuring reliable detection even when permission dialogs have prompt characters in them.

### 3. Wait for Output Text

Wait for specific text to appear in pane output:

```bash
/tmux-wait output <pane> <search-text> [timeout]
```

**Examples:**
```bash
/tmux-wait output 0 "Do you want to proceed?"
/tmux-wait output 1 "Build succeeded" 60
/tmux-wait output 0 "Team AI Initialization Complete"
```

## Real-World Examples

### Testing a Skill

```bash
# Start Claude
tmux send-keys -t 0 "claude" Enter
/tmux-wait prompt 0 60

# Execute skill (two-Enter pattern)
tmux send-keys -t 0 "/init-team-ai" Enter
sleep 1
tmux send-keys -t 0 Enter

# Wait for permission prompt (auto-detected!)
/tmux-wait prompt 0 60

# Approve it
tmux send-keys -t 0 Enter

# Wait for command to finish
/tmux-wait prompt 0 60

# Check what happened (use /see-terminal for full context)
/see-terminal 0
```

**Key improvement:** Using `prompt` mode for everything is more reliable than searching for specific completion text. Permission prompts are now auto-detected!

### Running Tests

```bash
# Simple: execute and wait automatically
/tmux-wait command 1 npm test

# Or monitor manually
tmux send-keys -t 1 "npm test" Enter
/tmux-wait prompt 1 120
```

### Monitoring Permission Prompts

```bash
# After sending a command, prompt mode auto-detects permission prompts!
/tmux-wait prompt 0 60

# Auto-approve with option 2 (don't ask again)
tmux send-keys -t 0 Down Enter

# Wait for next step
/tmux-wait prompt 0 60
```

**Note:** No need to use `output` mode for permission prompts anymore! The `prompt` mode now detects them automatically by checking for "Do you want to proceed?" BEFORE checking for regular prompts.

## Multi-CLI Support

The `prompt` mode auto-detects which CLI is running in a pane and applies CLI-specific prompt detection. Detection happens once at the start of each wait by scanning pane content for fingerprint patterns.

### CLI Fingerprint Chart

| CLI | Fingerprint Patterns | Prompt Char | Status Bar | Processing Indicators |
|-----|---------------------|-------------|-----------|----------------------|
| **Codex** | `gpt-`, `OpenAI Codex`, `% left` | `›` | `gpt-X.X default · NN% left · path` | `•`/`◦` `Working` (bullet alternates) |
| **Gemini** | `Gemini CLI`, `/model`, `gemini-api-key`, `Gemini [0-9]` | `> ` or `* ` (YOLO) | `workspace ... branch ... sandbox ... /model` | Braille spinners: `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏` |
| **Claude** | `for shortcuts`, `claude`, `Esc to interrupt` | `❯` or `›` | `? for shortcuts` | `✻✽✶✢`, `Symbioting`, `Churned`, `Recombobulating`, `Running.*agents`, `thought for`, `⏸ plan mode` |
| **Shell** | none of the above | `$`, `#`, `%`, `>`, `PS` | N/A | N/A |

All three TUI CLIs have status bars **below** their input prompts. The script uses two scan ranges:
- **Permission prompts** (e.g., "Do you want", "Action Required"): checked against the **full 50-line capture** — never missed
- **Prompt characters** (`$`, `›`, `❯`, `> `, `* `): checked against the **last 10 non-empty lines** — sufficient because prompts are always near the bottom

### Permission Prompt Detection

Permission prompts are detected across all CLIs and trigger immediate return:

| CLI | Permission Pattern | UI Style |
|-----|-------------------|----------|
| **Claude** | `"Do you want"`, `"Would you like"` | Numbered list with `❯` selector, Down/Up + Enter |
| **Codex** | `"Would you like"`, `"Do you want"` | Numbered list with keyboard shortcuts (y/p/a/d/n/Esc) |
| **Gemini** | `"Action Required"` | Boxed prompt with `●` bullet, Down + Enter |

**Note:** Codex `--full-auto` auto-approves within workspace sandbox, so permission prompts rarely appear in pipeline use. Codex `--yolo` bypasses all prompts entirely.

### Gemini `-y` Mode (YOLO vs Auto-Edit)

Gemini's `-y` flag behavior depends on folder trust level:

- **Trusted folder** → YOLO mode: status bar shows `YOLO Ctrl+Y`, prompt changes to ` * `, auto-approves ALL tool calls including shell execution. No "Action Required" prompts appear.
- **Non-trusted/override** → auto-edit mode: status bar shows `auto-accept edits`, prompt stays ` > `, auto-approves file edits only, still prompts for shell/MCP commands.

In auto-edit mode, shell commands trigger "Action Required" on first use — and approval is **per root command composition**, not per tool category. For example, approving `ls > file` does NOT cover `wc > file` or `rm`. Each distinct command pipeline needs separate approval. The caller must:

1. Detect the "Action Required" prompt (tmux-wait does this automatically)
2. Approve with "Allow for this session" — `tmux send-keys -t PANE Down Enter` (option 2)
3. Subsequent uses of the **exact same command root** are auto-approved for the session

**Gemini permission prompt format:**
```
╭──────────────────────────────────────────╮
│ Action Required                           │
│                                           │
│ ?  Shell <command> [current working dir]  │
│                                           │
│ Allow execution of: '<tool list>'?        │
│                                           │
│ ● 1. Allow once                          │
│   2. Allow for this session              │
│   3. No, suggest changes (esc)           │
╰──────────────────────────────────────────╯
```

Codex `--full-auto` truly auto-approves everything — no priming needed.

### Two-Enter Pattern (All TUI CLIs)

When sending input to any interactive TUI (Claude, Codex, Gemini) via tmux, you **must** use the two-Enter pattern:

```bash
tmux send-keys -t <pane> "your text here" Enter   # Types text + first Enter
sleep 1                                             # Wait for autocomplete/UI
tmux send-keys -t <pane> Enter                     # Second Enter to submit
```

Single-Enter works for bare shell commands but NOT for TUI input. This applies to all input types: slash commands, text prompts, task instructions.

### Shell Fallback

If a CLI pane returns to a shell prompt (CLI exited), the shell prompt is detected regardless of the initial CLI type. This handles cases where an agent crashes or exits unexpectedly.

## Benefits

### Event-Driven (command mode)
- `tmux wait-for` blocks until signal sent
- Zero CPU usage while waiting
- Instant detection when command completes
- No permission prompts needed

### Smart Polling (prompt/output modes)
- Efficient 0.2s polling intervals
- Detects completion patterns reliably
- Flexible timeout configuration
- All polling logic in one place (the skill)

### No Permission Hassle
When using `/init-team-ai` to set up projects, this skill uses only pre-approved commands:
- `Bash(tmux:*)`
- `Bash(sleep:*)`
- `Bash(echo:*)`

No more repetitive permission approvals!

## Integration with `/init-team-ai`

The `/init-team-ai` skill creates `.claude/settings.local.json` with pre-approved permissions for:
- All tmux commands
- Sleep (for polling)
- Common read-only commands

This makes `/tmux-wait` completely frictionless - no permission prompts!

## Comparison to Old Approach

**Old Way (polling loop):**
```bash
# Requires permission approval every time!
max_polls=150
poll_count=0
while ((poll_count++ < max_polls)); do
  output=$(tmux capture-pane -t 0 -p -S -50)
  if echo "$output" | grep -q "pattern"; then
    break
  fi
  sleep 0.2
done
```

**New Way (skill):**
```bash
# No permission needed!
/tmux-wait output 0 "pattern" 30
```

**Even Better (wait-for):**
```bash
# Event-driven, instant detection!
/tmux-wait command 0 npm test
```

## Uninstallation

```bash
cd tmux-wait
./uninstall.sh
```

## Technical Details

### Tmux wait-for Pattern

For simple commands:
```bash
# The skill does this internally:
tmux send-keys -t PANE "command; tmux wait-for -S signal" Enter
tmux wait-for signal  # Blocks until signal sent
```

### Prompt Detection

Uses intelligent multi-stage detection with 50-line capture:

```bash
# Stage 1: Check full 50-line capture for permission prompts (all CLIs)
grep -qF "Do you want"        # Claude
grep -qF "Action Required"    # Gemini

# Stage 2: Check last 10 non-empty lines for CLI-specific prompts
# Codex: ^\s*› (with • Working check to avoid false idle)
# Gemini: ^ [>*]  (with spinner check ⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏)
# Claude: ^\s*(❯|›) (with processing indicator check)
# Shell:  $ # % > (last line only)

# Stage 3: Shell fallback for all CLI types (agent exited)
```

**Key design decisions:**
- Permission prompts checked against **full 50-line capture** (never missed)
- Prompt characters checked against **last 10 non-empty lines** (TUI status bars sit below prompts)
- Each CLI has its own processing detection to prevent premature idle return
- Detection order (Codex → Gemini → Claude → Shell) prevents fingerprint overlaps

### Codex Processing Detection

Codex displays the `›` prompt even while actively processing. The script checks for `[•◦] Working` in the last 10 lines to distinguish idle from processing (the bullet alternates between filled `•` and hollow `◦`):

```
# While processing (› visible but NOT idle):
◦ Working (42s • esc to interrupt)
› <suggestion text>
  gpt-5.4 default · 99% left · path

# Truly idle (no Working indicator):
› <suggestion text>
  gpt-5.4 default · 99% left · path
```

### Codex Startup Prompts

Codex may show trust directory or update prompts at startup that use the `›` selector character — the same character as the idle input prompt. The script checks last 10 lines for `Press enter to continue` to distinguish startup prompts from idle state, and returns immediately so the caller can handle them (typically by pressing Enter).

### Fingerprint Overlap

`? for shortcuts` appears in **all three CLIs** (Codex, Gemini, Claude) — it is NOT a reliable single-CLI fingerprint. The detection order (Codex → Gemini → Claude → Shell) prevents misidentification:
- Codex is caught by `gpt-` or `% left` first
- Gemini is caught by `/model` or `Gemini [0-9]` first
- Claude's `for shortcuts` fingerprint only triggers if neither matched

### Output Monitoring

Uses `grep -q` for efficient text matching:
```bash
tmux capture-pane -t PANE -p -S -50 | grep -q "search text"
```

## See Also

- `/see-terminal` - For reading and controlling tmux panes
- `/init-team-ai` - Sets up pre-approved permissions

## Sources

Based on research into tmux event-driven automation:
- [Tmux Hooks Documentation](https://devel.tech/tips/n/tMuXz2lj/the-power-of-tmux-hooks/)
- [Tmux wait-for and signaling](https://github.com/tmux/tmux/issues/832)
- [Tmux Scripting Tutorial](https://www.peterdebelak.com/blog/tmux-scripting/)
- [Fun with tmux](https://www.manniwood.com/2021_08_02/fun_with_tmux.html)
