# Claude Skills Architecture Documentation

## Overview

This document describes the architecture and relationship between the tmux-related skills.

---

## Design Decision: Command Execution

Both skills can execute commands in tmux panes. This is intentional.

| Skill | Can Execute Commands? | Primary Use |
|-------|----------------------|-------------|
| `/see-terminal` | Yes (CONTROL mode) | Preferred entry point for all tmux operations |
| `/tmux-wait command` | Yes | Shortcut for simple execute-and-wait |

### When to Use Each

**Use `/see-terminal` (preferred):**
- Complex workflows with multiple steps
- When you need safety classification (GREEN/YELLOW/RED)
- When you need to analyze output after execution
- When controlling Claude Code in another pane

**Use `/tmux-wait command` (shortcut):**
- Simple one-liner commands
- When you just need execute + wait, nothing else
- Automated scripts where safety classification isn't needed

### Example: Two Ways to Run `npm test`

**Way 1: Via /see-terminal (full workflow)**
```
/see-terminal  →  classifies as YELLOW  →  requests approval
               →  sends: tmux send-keys -t 0 "npm test" Enter
               →  calls: /tmux-wait prompt 0 60
               →  captures output and analyzes
```

**Way 2: Via /tmux-wait command (shortcut)**
```
/tmux-wait command 0 npm test  →  sends command + waits
                                →  returns output directly
```

---

## Skill Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                      User Request                            │
│         (e.g., "check pane 0", "run tests in pane 1")       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     /see-terminal                            │
│              (Primary Entry Point - Preferred)               │
│                                                              │
│  Purpose: ALL tmux pane interactions                         │
│  Modes: READ (view pane) or CONTROL (execute commands)       │
│                                                              │
│  Features:                                                   │
│    - Safety classification (GREEN/YELLOW/RED)                │
│    - Output analysis                                         │
│    - Claude Code special handling                            │
│                                                              │
│  allowed-tools:                                              │
│    - Bash(tmux:*)                                            │
│    - Skill(tmux-wait:*)  ← Can invoke tmux-wait             │
└─────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┴───────────────────┐
          │ (delegates waiting)                   │ (OR use directly)
          ▼                                       ▼
┌─────────────────────────────────────────────────────────────┐
│                      /tmux-wait                              │
│              (Waiting Utility + Command Shortcut)            │
│                                                              │
│  Modes:                                                      │
│    - prompt: Wait for shell/Claude prompt                    │
│    - output: Wait for specific text                          │
│    - command: Execute + wait (shortcut, skips safety check)  │
│                                                              │
│  allowed-tools:                                              │
│    - Bash(tmux:*)                                            │
│    - Bash(sleep:*)                                           │
│    - Bash(echo:*)                                            │
│    - Bash(sed:*)                                             │
│    - Bash(tail:*)                                            │
│    - Bash(grep:*)                                            │
└─────────────────────────────────────────────────────────────┘
```

---

## /see-terminal Skill

### Purpose
The primary and ONLY interface for all tmux pane interactions. Users should never need to use raw tmux commands.

### Modes

#### READ Mode
Triggered when user wants to view/analyze terminal output.

**Trigger phrases:**
- "check my terminal"
- "what's the error in pane 1?"
- "show me the last 100 lines"

**Flow:**
```
1. Validate pane parameter ($1)
   - If provided: use directly
   - If not provided: list panes, ask user to select

2. Determine line count ($2)
   - If provided: use specified number
   - If not provided: default to 50

3. Execute capture:
   tmux capture-pane -t <pane> -p -S -<lines>

4. Analyze and report the output
```

#### CONTROL Mode
Triggered when user wants to execute commands in a pane.

**Trigger phrases:**
- "run npm install in pane 1"
- "fix the error"
- "stop the server"

**Flow:**
```
1. Classify command risk level:
   - GREEN: Read-only, auto-approve (ls, cat, git status)
   - YELLOW: Side effects, request approval (npm install, git commit)
   - RED: Destructive, strong warning (rm -rf, sudo)

2. Request approval if needed (YELLOW/RED)

3. Execute command:
   tmux send-keys -t <pane> "<command>" Enter

4. Wait for completion (delegate to /tmux-wait):
   /tmux-wait prompt <pane> 60

5. Capture and verify results:
   tmux capture-pane -t <pane> -p -S -50

6. Report results to user
```

### Special Case: Claude Slash Commands
When controlling a pane running Claude Code, slash commands require special handling:

```
# Two-Enter Pattern (required for autocomplete)
tmux send-keys -t <pane> "/command" Enter
sleep 1
tmux send-keys -t <pane> Enter
```

### Permission Approval Navigation
```
# Option 1 (default): Enter
# Option 2: Down Enter
# Option 3: Down Down Enter
```

---

## /tmux-wait Skill

### Purpose
Specialized utility for waiting operations. Can be:
1. Called by `/see-terminal` when waiting is needed
2. Used directly as a shortcut for simple execute-and-wait operations

### Modes

#### 1. command Mode (Shortcut)
Execute a command AND wait using tmux's event-driven `wait-for`. This is a **shortcut** that bypasses `/see-terminal`'s safety classification.

**Syntax:** `/tmux-wait command <pane> <command-to-run>`

**How it works:**
```bash
# Append wait-for signal to command, then block until signaled
tmux send-keys -t "$PANE" "$COMMAND; tmux wait-for -S $SIGNAL" Enter
tmux wait-for "$SIGNAL"  # Blocks until command completes
```

**Pros:** Zero CPU usage while waiting, instant detection
**Cons:** Only works for shell commands (not Claude prompts), no safety classification

**Note:** This mode is a shortcut. For full workflow with safety checks, use `/see-terminal` instead.

#### 2. prompt Mode
Poll until a shell prompt (`$`, `#`, `%`) or Claude prompt (`❯`, `›`) appears.

**Syntax:** `/tmux-wait prompt <pane> [timeout]`

**How it works:**
```bash
# Poll every 0.2 seconds, check last line for prompt characters
while ((poll_count++ < MAX_POLLS)); do
  output=$(tmux capture-pane -t "$PANE" -p -S -50)
  last_line=$(echo "$output" | sed '/^[[:space:]]*$/d' | tail -1)

  # Also detects "Do you want to proceed?" permission prompts
  if [prompt detected]; then
    exit 0
  fi
  sleep 0.2
done
```

**Use for:**
- After starting Claude
- After approving permissions
- Any time you need to know "is it done?"

#### 3. output Mode
Poll until specific text appears in the pane output.

**Syntax:** `/tmux-wait output <pane> <search-text> [timeout]`

**How it works:**
```bash
# Poll every 0.2 seconds, grep for specific text
while ((poll_count++ < MAX_POLLS)); do
  output=$(tmux capture-pane -t "$PANE" -p -S -50)
  if echo "$output" | grep -qF "$SEARCH_TEXT"; then
    exit 0
  fi
  sleep 0.2
done
```

**Use for:**
- Waiting for specific prompts ("Enter password:")
- Detecting specific error messages
- Any text you KNOW will appear

---

## Current Problem

### Issue: Skills Don't Self-Execute

When a skill is invoked (e.g., `/tmux-wait prompt 0 60`):

1. The Skill tool loads the SKILL.md content
2. Claude reads the instructions
3. **Problem:** Claude treats bash code blocks as documentation/examples, not as code to execute immediately
4. Claude may ask for permission or hesitate instead of executing

### Root Cause

The instruction language is ambiguous:
- Current: "Based on the mode ($1), generate the appropriate bash commands"
- This sounds like guidance, not a command to execute

### Evidence

When I tried to run `/tmux-wait prompt 0 60`:
1. Skill loaded successfully
2. I saw the bash script for prompt mode
3. Instead of executing it, I tried to run it manually
4. This triggered a permission prompt because it was a "new" command

---

## Proposed Fix

### Goal
Make it unambiguous that after loading a skill, Claude MUST immediately execute the appropriate bash code.

### Strategy
Add an **"IMMEDIATE EXECUTION"** section at the very top of each skill (right after frontmatter) that:

1. Parses the arguments
2. States clearly: "EXECUTE this code NOW using the Bash tool"
3. Shows the exact bash code to run based on mode/arguments

### Structure Change

**Before:**
```
---
frontmatter
---
# Title
[explanation paragraphs]
[permission requirements]
[usage modes explanation]
[parameters explanation]
## Instructions
[bash code blocks]
[examples]
```

**After:**
```
---
frontmatter
---
# Title

## EXECUTE IMMEDIATELY

Arguments received: $ARGS

Based on arguments, EXECUTE this bash script NOW using the Bash tool:

[bash code block for the specific mode]

---

## Reference Documentation

[All the existing documentation moved here, unchanged]
```

### Key Principles

1. **Execution first, documentation second** - Claude sees "EXECUTE NOW" before any explanatory text
2. **Nothing removed** - All existing docs preserved as reference
3. **Unambiguous language** - "EXECUTE" not "generate" or "use"

---

## Workflow Examples

### Example 1: User asks to check pane 0

```
User: "check pane 0"

1. Claude invokes: /see-terminal 0
2. see-terminal loads with args: "0"
3. see-terminal EXECUTES: tmux capture-pane -t 0 -p -S -50
4. Claude analyzes output and reports to user
```

### Example 2: User asks to run tests in pane 1

```
User: "run npm test in pane 1"

1. Claude invokes: /see-terminal 1 (CONTROL mode)
2. see-terminal classifies: YELLOW (test command)
3. Claude requests approval
4. User approves
5. see-terminal EXECUTES: tmux send-keys -t 1 "npm test" Enter
6. see-terminal invokes: /tmux-wait prompt 1 60
7. tmux-wait EXECUTES polling script
8. tmux-wait returns when prompt detected
9. see-terminal EXECUTES: tmux capture-pane -t 1 -p -S -50
10. Claude reports results
```

### Example 3: Direct tmux-wait usage

```
User needs to wait for prompt in pane 0

1. Claude invokes: /tmux-wait prompt 0 60
2. tmux-wait loads with args: "prompt 0 60"
3. tmux-wait EXECUTES the prompt-mode polling script
4. Script returns when prompt detected (or timeout)
5. Claude continues with next action
```

---

## File Locations

### Repository (source)
- `see-terminal/commands/SKILL.md` - Primary tmux skill
- `tmux-wait/commands/SKILL.md` - Waiting utility skill
- `init-team-ai/commands/SKILL.md` - Project initialization skill

### Installed (after running install.sh)
- `~/.claude/skills/see-terminal/SKILL.md`
- `~/.claude/skills/tmux-wait/SKILL.md`
- `~/.claude/skills/init-team-ai/SKILL.md`

---

## Permission Requirements

For these skills to work without prompts, the project needs:

```json
{
  "permissions": {
    "allow": [
      "Bash",
      "Skill(see-terminal)",
      "Skill(tmux-wait)"
    ]
  }
}
```

The `"Bash"` permission is needed because the skills use complex multi-line scripts with loops and variables that don't match simple prefix patterns like `Bash(tmux:*)`.

The `/init-team-ai` skill automatically adds these permissions when initializing a project.
