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
  output=$(tmux capture-pane -t "$PANE" -p -S -50)
  last_line=$(echo "$output" | sed '/^[[:space:]]*$/d' | tail -1)

  # Check for Claude Code permission prompts FIRST (before regular prompts)
  # Permission dialogs can have prompt characters in them that would cause false positives
  if echo "$output" | grep -qF "Do you want to proceed?"; then
    elapsed_decisecs=$((poll_count * 2))
    elapsed_secs=$((elapsed_decisecs / 10))
    elapsed_tenths=$((elapsed_decisecs % 10))
    echo "✓ Permission prompt detected after ${elapsed_secs}.${elapsed_tenths} seconds"
    echo ""
    echo "=== Pane output ==="
    tmux capture-pane -t "$PANE" -p -S -50
    exit 0
  fi

  # Check last line for prompt (at end OR at beginning of line)
  if [[ "$last_line" =~ (\$|#|%|❯|›)[[:space:]]*$ ]] || [[ "$last_line" =~ ^[[:space:]]*(❯|›|\$|#|%) ]]; then
    elapsed_decisecs=$((poll_count * 2))
    elapsed_secs=$((elapsed_decisecs / 10))
    elapsed_tenths=$((elapsed_decisecs % 10))
    echo "✓ Prompt detected after ${elapsed_secs}.${elapsed_tenths} seconds"
    echo ""
    echo "=== Pane output ==="
    tmux capture-pane -t "$PANE" -p -S -50
    exit 0
  fi

  # Check if last line is "? for shortcuts" - if so, look for prompt in last 5 lines
  if [[ "$last_line" =~ (for shortcuts) ]]; then
    # Get last 5 non-empty lines and check if any starts with a prompt character
    last_5_lines=$(echo "$output" | sed '/^[[:space:]]*$/d' | tail -5)
    if echo "$last_5_lines" | grep -qE '^\s*(❯|›|\$|#|%)'; then
      elapsed_decisecs=$((poll_count * 2))
      elapsed_secs=$((elapsed_decisecs / 10))
      elapsed_tenths=$((elapsed_decisecs % 10))
      echo "✓ Prompt detected after ${elapsed_secs}.${elapsed_tenths} seconds"
      echo ""
      echo "=== Pane output ==="
      tmux capture-pane -t "$PANE" -p -S -50
      exit 0
    fi
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

**Wait for permission prompts (auto-detected by prompt mode):**
```
/tmux-wait prompt 0 60
```

**Execute command and wait:**
```
/tmux-wait command 1 npm test
```

**Wait for specific output:**
```
/tmux-wait output 0 "Build complete" 60
```

## Proper Workflow: When to Use Each Mode

**CRITICAL: Choose the right mode for the right situation.**

### Use `prompt` mode (DEFAULT - MOST COMMON)

This is your **default choice** after executing any command:

```
/tmux-wait prompt <pane> 60
```

**When to use:**
- After executing any command in a pane
- After approving permissions
- After starting applications (like Claude)
- Any time you need to know "is the command done?"
- Waiting for Claude Code permission prompts (auto-detected!)

**Why it's better:**
- Detects when command finishes, regardless of output
- No assumptions about specific success messages
- Works for any command that returns to a prompt
- Automatically detects Claude Code permission prompts
- Fast and reliable

**Then check what happened:**
```
/see-terminal <pane>        # Check with 50 lines (default)
/see-terminal <pane> 100    # Use 100 if you need more context
```

### Use `output` mode (SPECIFIC CASES ONLY)

Only use this when you need to detect **specific text that you KNOW will appear**:

```
/tmux-wait output <pane> "<exact-text>" <timeout>
```

**When to use:**
- User input prompts: `/tmux-wait output 0 "Enter password:" 30`
- Specific error patterns: `/tmux-wait output 0 "Build failed" 60`
- Waiting for very specific text that's not a standard prompt

**When NOT to use:**
- ❌ Completion messages that may vary or not exist
- ❌ Success messages that are optional
- ❌ Any text you're not 100% certain will appear

### Common Mistakes to Avoid

**❌ WRONG - Searching for completion text that may not exist:**
```
# These assume specific success messages and waste time if they don't appear
/tmux-wait output 0 "Team AI Initialization Complete" 60
/tmux-wait output 0 "Build succeeded" 60
/tmux-wait output 0 "Installation complete" 60
```

**✅ CORRECT - Wait for prompt, then check what happened:**
```
# Wait for command to finish
/tmux-wait prompt 0 60

# Check what actually happened
/see-terminal 0
```

### Complete Example: Testing a Claude Skill

```bash
# 1. Execute the skill
tmux send-keys -t 0 "/init-team-ai" Enter
sleep 1
tmux send-keys -t 0 Enter

# 2. Wait for permission prompt (prompt mode auto-detects it!)
/tmux-wait prompt 0 60

# 3. Approve permission
tmux send-keys -t 0 Enter

# 4. Wait for command to finish
/tmux-wait prompt 0 60

# 5. Check what actually happened
/see-terminal 0
# If you need more context:
/see-terminal 0 100
```

**Note:** The `prompt` mode now automatically detects Claude Code permission prompts ("Do you want to proceed?"), so you don't need to use `output` mode for them. This makes the workflow simpler and faster.

### Quick Decision Guide

Ask yourself: "Do I know the EXACT text that will appear?"

- **NO** → Use `prompt` mode, then `/see-terminal` to check results
- **YES, and it's a prompt requiring action** → Use `output` mode

## Implementation Logic

When invoked with arguments, parse $1 to determine the mode, then execute the corresponding bash commands shown above using the Bash tool. Use only the pre-approved commands listed in the allowed-tools field.

## Important Notes

- All variables are properly quoted to handle special characters
- Signal names use $RANDOM and $$ for uniqueness
- grep uses -F flag for literal string matching (no regex issues)
- Elapsed time calculation uses pure bash arithmetic (no external tools)
- The `tail` command is now in the allowed-tools list
