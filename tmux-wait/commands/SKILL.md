---
name: tmux-wait
description: "USE THIS instead of sleep+polling when waiting for tmux commands, prompts, or specific output"
argument-hint: prompt <pane> [timeout] | output <pane> <text> [timeout] | command <pane> <cmd>
allowed-tools: Bash(tmux:*), Bash(sleep:*), Bash(echo:*), Bash(sed:*), Bash(tail:*), Bash(grep:*)
---

# Tmux Smart Wait

## 🔑 FOR CALLERS: How to Invoke This Skill

**When you need to wait for something in a tmux pane, invoke this skill - don't write your own loops.**

```
# Use the Skill tool to invoke:
/tmux-wait prompt 0 60      # Wait for shell prompt
/tmux-wait output 0 "text"  # Wait for specific text
/tmux-wait command 0 cmd    # Execute and wait
```

**NEVER copy the bash code below into your own scripts. ALWAYS invoke via `/tmux-wait`.**

---

## ⚠️ FOR SKILL EXECUTION: Execute Immediately ⚠️

**(This section is for when the skill has been invoked and Claude is executing it)**

**You MUST execute the bash code below using the Bash tool NOW. Do not just read these instructions.**

Arguments received: `$ARGS`

Parse the arguments:
- **$1** = mode (`command`, `prompt`, or `output`)
- **$2** = pane number (0, 1, 2, etc.)
- **$3+** = additional arguments (depends on mode)

**Based on $1, EXECUTE the corresponding bash script below using the Bash tool:**

---

### If mode is `command`: EXECUTE THIS

```bash
PANE="<$2>"
COMMAND="<$3 and remaining args>"
SIGNAL="cmdwait-${RANDOM}-$$"

echo "Executing in pane $PANE: $COMMAND"
tmux send-keys -t "$PANE" "$COMMAND; tmux wait-for -S $SIGNAL" Enter
tmux wait-for "$SIGNAL"
echo ""
echo "=== Command completed. Output ==="
tmux capture-pane -t "$PANE" -p -S -50
```

---

### If mode is `prompt`: EXECUTE THIS

```bash
PANE="<$2>"
TIMEOUT="${3:-30}"
MAX_POLLS=$((TIMEOUT * 5))

echo "Waiting for prompt in pane $PANE (timeout: ${TIMEOUT}s)..."

poll_count=0
while ((poll_count++ < MAX_POLLS)); do
  output=$(tmux capture-pane -t "$PANE" -p -S -50)
  last_line=$(echo "$output" | sed '/^[[:space:]]*$/d' | tail -1)

  # Check for Claude Code permission prompts (all types)
  if echo "$output" | grep -qF "Do you want"; then
    elapsed=$((poll_count * 2 / 10))
    echo "✓ Permission prompt detected after ${elapsed}s"
    echo ""
    echo "=== Pane output ==="
    tmux capture-pane -t "$PANE" -p -S -50
    exit 0
  fi

  # Check for plan approval prompt and other "Would you like" prompts
  if echo "$output" | grep -qF "Would you like"; then
    elapsed=$((poll_count * 2 / 10))
    echo "✓ Approval prompt detected after ${elapsed}s"
    echo ""
    echo "=== Pane output ==="
    tmux capture-pane -t "$PANE" -p -S -50
    exit 0
  fi

  # Check for confirmation dialogs (Claude folder trust, Codex permission prompts, etc.)
  # Case-insensitive: Claude uses "Enter to confirm", Codex uses "Press enter to confirm"
  if echo "$output" | grep -qi "enter to confirm"; then
    elapsed=$((poll_count * 2 / 10))
    echo "✓ Confirmation prompt detected after ${elapsed}s"
    echo ""
    echo "=== Pane output ==="
    tmux capture-pane -t "$PANE" -p -S -50
    exit 0
  fi

  # Check if Claude Code prompt is present (❯ or ›)
  if [[ "$last_line" =~ (❯|›)[[:space:]]*$ ]] || [[ "$last_line" =~ ^[[:space:]]*(❯|›) ]]; then
    # Claude prompt found - check if still thinking/processing
    # Only check last 5 lines to avoid stale indicators from previous operations
    # IMPORTANT: Only match ACTIVE states. Do NOT add star chars (✻✽✶✢) or
    # completion words (Brewed/Churned/Cooked/thought for) — they persist after
    # Claude finishes and cause false blocking on idle prompts.
    last_5_check=$(echo "$output" | sed '/^[[:space:]]*$/d' | tail -5)
    if echo "$last_5_check" | grep -qE "(Symbioting|Recombobulating|Running.*agents|[Ee]sc to interrupt|⏸ plan mode)"; then
      # Claude is still processing, keep waiting
      sleep 0.2
      continue
    fi

    # Claude prompt present and no thinking indicators - truly ready
    elapsed=$((poll_count * 2 / 10))
    echo "✓ Claude prompt detected after ${elapsed}s"
    echo ""
    echo "=== Pane output ==="
    tmux capture-pane -t "$PANE" -p -S -50
    exit 0
  fi

  # Check if shell prompt is present ($, #, %, >, PS)
  if [[ "$last_line" =~ (\$|#|%|>)[[:space:]]*$ ]] || [[ "$last_line" =~ ^[[:space:]]*([\$#%>]) ]] || [[ "$last_line" =~ ^PS[[:space:]].*\>$ ]]; then
    # Shell prompt found - return immediately (no thinking check needed)
    elapsed=$((poll_count * 2 / 10))
    echo "✓ Shell prompt detected after ${elapsed}s"
    echo ""
    echo "=== Pane output ==="
    tmux capture-pane -t "$PANE" -p -S -50
    exit 0
  fi

  # Check for Gemini TUI idle prompt (interactive mode)
  # Gemini's idle state shows "Type your message" in its input field area
  # and workspace/sandbox info in the bottom status bar
  last_10_lines=$(echo "$output" | tail -10)
  if echo "$last_10_lines" | grep -qF "Type your message"; then
    elapsed=$((poll_count * 2 / 10))
    echo "✓ Gemini TUI prompt detected after ${elapsed}s"
    echo ""
    echo "=== Pane output ==="
    tmux capture-pane -t "$PANE" -p -S -50
    exit 0
  fi

  # Check for Codex TUI idle prompt (interactive mode)
  # Codex's idle state shows model info like "gpt-5.4 default · 88% left · ~/path"
  # at the bottom, with a › prompt somewhere above.
  # IMPORTANT: The gpt- status line appears in BOTH active and idle states.
  # When active, Codex shows "• Working" or "◦ Working" in the last 10 lines.
  # Only return if the status line is present AND no Working indicator found.
  if echo "$last_10_lines" | grep -qE "gpt-.*default.*left"; then
    if echo "$last_10_lines" | grep -qE "[•◦] Working"; then
      # Codex is actively processing, keep waiting
      sleep 0.2
      continue
    fi
    elapsed=$((poll_count * 2 / 10))
    echo "✓ Codex TUI prompt detected after ${elapsed}s"
    echo ""
    echo "=== Pane output ==="
    tmux capture-pane -t "$PANE" -p -S -50
    exit 0
  fi

  # Special case: "? for shortcuts" means prompt might be above the last line
  if [[ "$last_line" =~ (for shortcuts) ]]; then
    last_5_lines=$(echo "$output" | sed '/^[[:space:]]*$/d' | tail -5)

    # Check for Claude prompts first (❯ or ›)
    if echo "$last_5_lines" | grep -qE '^\s*(❯|›)'; then
      # Found Claude prompt - check if still thinking/processing
      # Only check last 5 lines to avoid stale indicators from previous operations
      # IMPORTANT: Only match ACTIVE states — see comment above for rationale
      if echo "$last_5_lines" | grep -qE "(Symbioting|Recombobulating|Running.*agents|[Ee]sc to interrupt|⏸ plan mode)"; then
        # Claude is still processing, keep waiting
        sleep 0.2
        continue
      fi
      # Claude prompt present and no thinking indicators - truly ready
      elapsed=$((poll_count * 2 / 10))
      echo "✓ Claude prompt detected after ${elapsed}s"
      echo ""
      echo "=== Pane output ==="
      tmux capture-pane -t "$PANE" -p -S -50
      exit 0
    fi

    # Check for shell prompts ($, #, %, >, PS)
    if echo "$last_5_lines" | grep -qE '^\s*(\$|#|%|>)' || echo "$last_5_lines" | grep -qE '^PS\s.*>'; then
      # Shell prompt found - return immediately (no thinking check needed)
      elapsed=$((poll_count * 2 / 10))
      echo "✓ Shell prompt detected after ${elapsed}s"
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

---

### If mode is `output`: EXECUTE THIS

```bash
PANE="<$2>"
SEARCH_TEXT="<$3>"
TIMEOUT="${4:-30}"
MAX_POLLS=$((TIMEOUT * 5))

echo "Waiting for text in pane $PANE: \"$SEARCH_TEXT\" (timeout: ${TIMEOUT}s)..."

poll_count=0
while ((poll_count++ < MAX_POLLS)); do
  output=$(tmux capture-pane -t "$PANE" -p -S -50)

  if echo "$output" | grep -qF "$SEARCH_TEXT"; then
    elapsed=$((poll_count * 2 / 10))
    echo "✓ Found text after ${elapsed}s"
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

---

## Reference Documentation

### Permission Requirements

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

### Usage Modes

The skill supports three modes:

1. **command** - Execute a command and wait for completion using `tmux wait-for` (shortcut, skips safety checks)
2. **prompt** - Wait for shell/Claude prompt to return
3. **output** - Wait for specific text to appear in output

### Parameters

Arguments are provided as: `<mode> <pane> [additional args...]`

- **$1 (mode)**: One of `command`, `prompt`, or `output`
- **$2 (pane)**: Pane number (0, 1, 2) or position ({left}, {right}, {top}, {bottom})
- **$3+**: Mode-specific arguments

### Mode Syntax

- **command**: `/tmux-wait command <pane> <command-to-run>`
- **prompt**: `/tmux-wait prompt <pane> [timeout]` (default timeout: 30s)
- **output**: `/tmux-wait output <pane> <search-text> [timeout]` (default timeout: 30s)

## Usage Examples

**Wait for Claude to start:**
```
/tmux-wait prompt 0 60
```

**Wait for permission prompts (all types including tool execution, file edits, and file creation - auto-detected by prompt mode):**
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
- Waiting for Claude Code permission prompts (all types: "Do you want to proceed?", "Do you want to make this edit", "Do you want to create X?" - auto-detected!)
- Waiting for Claude Code confirmation dialogs (folder trust prompt with "Enter to confirm")
- **NEW:** Waiting for Claude Code to finish thinking/processing (Symbioting, plan mode, agent execution)

**Why it's better:**
- Detects when command finishes, regardless of output
- No assumptions about specific success messages
- Works for any command that returns to a prompt
- Automatically detects ALL Claude Code permission prompts (tool execution, file edits, file creation - any prompt starting with "Do you want")
- **NEW:** Automatically detects Claude Code active processing states and waits until truly complete
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

**Note:** The `prompt` mode now automatically detects ALL Claude Code permission prompts by matching "Do you want" (covers "Do you want to proceed?", "Do you want to make this edit", "Do you want to create X?", etc.), so you don't need to use `output` mode for them. This makes the workflow simpler and faster.

### Quick Decision Guide

Ask yourself: "Do I know the EXACT text that will appear?"

- **NO** → Use `prompt` mode, then `/see-terminal` to check results
- **YES, and it's a prompt requiring action** → Use `output` mode

## Important Notes

- All variables are properly quoted to handle special characters
- Signal names use $RANDOM and $$ for uniqueness
- grep uses -F flag for literal string matching (no regex issues)
- Elapsed time calculation uses pure bash arithmetic (no external tools)
- The `tail` command is now in the allowed-tools list

## Supported Shell Prompts

The `prompt` mode detects the following shell prompts:

| Shell / TUI | Prompt Pattern | Example |
|-------------|----------------|---------|
| Bash | `$` | `user@host:~$` |
| Root | `#` | `root@host:~#` |
| Zsh | `%` | `user@host %` |
| Fish/Starship | `❯` or `›` | `~/projects ❯` |
| PowerShell | `>` or `PS ...>` | `PS C:\Users\name>` |
| Claude Code | `❯` | `❯` |
| Gemini CLI | `Type your message` | `*  Type your message or @path/to/file` |
| Codex CLI | `gpt-.*default.*left` | `gpt-5.4 default · 88% left · ~/project` |

**PowerShell Support**: Works with PowerShell running inside tmux panes in WSL. Both standard prompts (`PS C:\>`) and verbose UNC paths (`PS Microsoft.PowerShell.Core\FileSystem::\\wsl.localhost\...>`) are detected.

**Gemini/Codex TUI Support**: Detects idle state for interactive TUI agents used in team-ai pipelines. Gemini shows `Type your message` in its input field; Codex shows a model info line like `gpt-5.4 default · 88% left · ~/path`. Both are checked in the last 10 lines of pane output.

## Claude Code Processing Detection

**NEW:** The `prompt` mode now intelligently detects when Claude Code is actively processing and waits until truly complete, even when the `❯` prompt is visible.

**IMPORTANT:** This check ONLY applies when a **Claude Code prompt** (`❯` or `›`) is detected. Regular shell prompts (`$`, `#`, `%`, `>`, `PS`) return immediately without checking for thinking indicators.

**Detected Active Processing States (Claude prompts only):**
- `Symbioting...` - Claude is actively thinking/processing
- `Recombobulating...` - Claude is actively processing
- `Running.*agents` / `Explore agents` - Parallel agents executing
- `Esc to interrupt` - Active task running
- `⏸ plan mode on` - Plan mode is active

**NOT treated as active (completion indicators):**
- `✻ Brewed for...` / `✻ Churned for...` / `✻ Cooked for...` - These are COMPLETION messages, not active states. They remain visible after Claude finishes and returns to idle prompt.

**How it works:**
1. If a Claude prompt (`❯` or `›`) is detected AND any processing indicator is found in the last 5 non-empty lines, tmux-wait continues waiting
2. If a shell prompt (`$`, `#`, `%`) is detected, returns immediately (no thinking check)
3. Only returns when processing is complete AND prompt is ready
4. Prevents false positives from detecting the Claude prompt symbol while Claude is still thinking

**Note:** The thinking indicator check only scans the last 5 non-empty lines near the prompt, avoiding false positives from stale indicators (e.g. `✻ Cooked for...`) left over from previous operations.

**Example:**
```bash
# Wait for Claude to finish creating a plan
/tmux-wait prompt 2 300

# This will now properly wait through:
# - "Symbioting... (3m 10s)"
# - "Running 3 Explore agents..."
# - "Plan mode on"
# And only return when Claude is truly done
```
