# Tmux Smart Wait Skill

Event-driven command waiting for tmux panes using `tmux wait-for` instead of polling loops.

## Why This Skill?

**The Problem:**
- Smart polling loops require permission approval every time
- Fixed `sleep` delays waste time and are unreliable
- Complex bash loops are hard to maintain and error-prone

**The Solution:**
- Uses `tmux wait-for` for event-driven waiting (zero CPU, instant completion detection)
- Pre-approved commands (no permission prompts when using `/init-team-ai`)
- Simple skill invocation instead of complex bash scripts

## Installation

```bash
cd /home/kiral/ClaudeSkills/tmux-wait
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
cd /home/kiral/ClaudeSkills/tmux-wait
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
# Stage 1: Check for permission prompts FIRST (prevents false positives)
grep -qF "Do you want to proceed?"

# Stage 2: Check for prompt patterns at line start OR line end:
$ # %     # Shell prompts (bash, zsh, sh, root)
❯ ›       # Claude Code prompts

# Stage 3: Special handling for Claude Code idle state:
# When "? for shortcuts" is detected, searches last 5 lines
# for any prompt character - handles dynamic suggestion text
```

**Key improvements:**
- 50-line capture (up from 10) ensures permission prompts are detected even with lots of output above them
- Permission check happens BEFORE prompt check to avoid false positives from `❯` characters in permission dialogs

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
