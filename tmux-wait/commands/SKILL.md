---
name: tmux-wait
description: Smart tmux command execution and waiting using event-driven tmux wait-for
argument-hint: <mode> <pane> [args...]
allowed-tools: Bash(tmux:*), Bash(sleep:*), Bash(echo:*), Bash(sed:*), Bash(tail:*), Bash(grep:*)
---

# Tmux Smart Wait

This skill provides event-driven waiting for tmux pane commands using `tmux wait-for`, eliminating the need for polling loops.

## Permission Requirements

**IMPORTANT:** This skill uses complex bash scripts with loops and variables. For it to work without permission prompts, you must add `"Bash"` to your `.claude/settings.local.json` allow list:

```json
{
  "permissions": {
    "allow": [
      "Bash",
      "Skill(tmux-wait)"
    ]
  }
}
```

**Why is this needed?**

Claude Code's permission system uses prefix matching for commands. Patterns like `"Bash(tmux:*)"` only match commands that start with "tmux", but this skill uses multi-line bash scripts with variables, loops, and multiple commands. The general `"Bash"` permission is required for these compound scripts to execute without prompts.

**Note:** If you use `/init-team-ai` skill, this permission will be automatically added to your project's settings.

## Usage Modes

The skill supports three modes:

1. **command** - Execute a command and wait for completion using `tmux wait-for`
2. **prompt** - Wait for shell/Claude prompt to return
3. **output** - Wait for specific text to appear in output

## Parameters

Arguments are provided as: `<mode> <pane> [additional args...]`

- **$1 (mode)**: One of `command`, `prompt`, or `output`
- **$2 (pane)**: Pane number (0, 1, 2) or position ({left}, {right}, {top}, {bottom})
- **$3+**: Mode-specific arguments

## Instructions

Based on the mode ($1), generate the appropriate bash commands:

### Mode: command

**Syntax:** `command <pane> <command-to-run>`

Execute a command in the pane and wait for completion using `tmux wait-for`:

```bash
PANE="$2"
shift 2
COMMAND="$*"
SIGNAL="cmdwait-${RANDOM}-$$"

echo "Executing in pane $PANE: $COMMAND"
tmux send-keys -t "$PANE" "$COMMAND; tmux wait-for -S $SIGNAL" Enter
tmux wait-for "$SIGNAL"
echo ""
echo "=== Command completed. Output ==="
tmux capture-pane -t "$PANE" -p -S -50
```

### Mode: prompt

**Syntax:** `prompt <pane> [timeout]`

Wait for shell prompt or Claude prompt to return:

```bash
PANE="$2"
TIMEOUT="${3:-30}"
MAX_POLLS=$((TIMEOUT * 5))

echo "Waiting for prompt in pane $PANE (timeout: ${TIMEOUT}s)..."

poll_count=0
while ((poll_count++ < MAX_POLLS)); do
  output=$(tmux capture-pane -t "$PANE" -p -S -10)
  last_line=$(echo "$output" | sed '/^[[:space:]]*$/d' | tail -1)
  second_last=$(echo "$output" | sed '/^[[:space:]]*$/d' | tail -2 | head -1)

  # Check last line for prompt
  if [[ "$last_line" =~ (\$|#|%|❯|›)[[:space:]]*$ ]]; then
    elapsed_decisecs=$((poll_count * 2))
    elapsed_secs=$((elapsed_decisecs / 10))
    elapsed_tenths=$((elapsed_decisecs % 10))
    echo "✓ Prompt detected after ${elapsed_secs}.${elapsed_tenths} seconds"
    echo ""
    echo "=== Pane output ==="
    tmux capture-pane -t "$PANE" -p -S -50
    exit 0
  fi

  # Also check second-to-last line (for Claude Code which shows "? for shortcuts" after prompt)
  if [[ "$second_last" =~ (\$|#|%|❯|›)[[:space:]]*$ ]] && [[ "$last_line" =~ (for shortcuts|Try) ]]; then
    elapsed_decisecs=$((poll_count * 2))
    elapsed_secs=$((elapsed_decisecs / 10))
    elapsed_tenths=$((elapsed_decisecs % 10))
    echo "✓ Prompt detected after ${elapsed_secs}.${elapsed_tenths} seconds"
    echo ""
    echo "=== Pane output ==="
    tmux capture-pane -t "$PANE" -p -S -50
    exit 0
  fi

  sleep 0.2
done

echo "✗ Timeout after $TIMEOUT seconds"
echo ""
echo "=== Pane output ==="
tmux capture-pane -t "$PANE" -p -S -50
exit 1
```

### Mode: output

**Syntax:** `output <pane> <search-text> [timeout]`

Wait for specific text to appear in pane output:

```bash
PANE="$2"
SEARCH_TEXT="$3"
TIMEOUT="${4:-30}"
MAX_POLLS=$((TIMEOUT * 5))

echo "Waiting for text in pane $PANE: \"$SEARCH_TEXT\" (timeout: ${TIMEOUT}s)..."

poll_count=0
while ((poll_count++ < MAX_POLLS)); do
  output=$(tmux capture-pane -t "$PANE" -p -S -50)

  # Use grep -F for fixed string matching (no regex interpretation)
  if echo "$output" | grep -qF "$SEARCH_TEXT"; then
    elapsed_decisecs=$((poll_count * 2))
    elapsed_secs=$((elapsed_decisecs / 10))
    elapsed_tenths=$((elapsed_decisecs % 10))
    echo "✓ Found text after ${elapsed_secs}.${elapsed_tenths} seconds"
    echo ""
    echo "=== Pane output ==="
    echo "$output"
    exit 0
  fi

  sleep 0.2
done

echo "✗ Timeout after $TIMEOUT seconds - text not found"
echo ""
echo "=== Pane output ==="
tmux capture-pane -t "$PANE" -p -S -50
exit 1
```

## Usage Examples

**Wait for Claude to start:**
```
/tmux-wait prompt 0 60
```

**Execute command and wait:**
```
/tmux-wait command 1 npm test
```

**Wait for specific output:**
```
/tmux-wait output 0 "Team AI Initialization Complete" 60
```

**Monitor for permission prompt:**
```
/tmux-wait output 0 "Do you want to proceed?" 10
```

## Implementation Logic

When invoked with arguments, parse $1 to determine the mode, then execute the corresponding bash commands shown above using the Bash tool. Use only the pre-approved commands listed in the allowed-tools field.

## Important Notes

- All variables are properly quoted to handle special characters
- Signal names use $RANDOM and $$ for uniqueness
- grep uses -F flag for literal string matching (no regex issues)
- Elapsed time calculation uses pure bash arithmetic (no external tools)
- The `tail` command is now in the allowed-tools list
