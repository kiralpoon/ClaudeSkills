---
name: see-terminal
description: "Primary interface for ALL tmux pane interactions - viewing contents and executing commands"
argument-hint: <pane> [lines] - view pane | use /tmux-wait for waiting operations
allowed-tools: Bash(tmux:*), Skill(tmux-wait:*)
---

# Tmux Pane Capture & Control

## 🚫 CRITICAL: NO MANUAL WAITING LOOPS 🚫

**BEFORE writing ANY bash code that waits for something, STOP and use the `/tmux-wait` skill instead.**

| ❌ NEVER DO THIS | ✅ ALWAYS DO THIS |
|------------------|-------------------|
| `while ... do sleep ... done` | `/tmux-wait prompt <pane> 60` |
| `sleep 5 && tmux capture-pane` | `/tmux-wait prompt <pane>` then `/see-terminal <pane>` |
| Any bash polling loop | Invoke `/tmux-wait` skill |

**This is mandatory. Use the Skill tool to invoke `/tmux-wait` for ALL waiting operations.**

**Exception:** Short `sleep 1` delays for UI timing (e.g., between two Enters for slash commands) are OK - those are NOT waiting loops.

---

## ⚠️ EXECUTE IMMEDIATELY ⚠️

**You MUST execute the appropriate action NOW based on the context. Do not just read these instructions.**

Arguments received: `$ARGS`
- **$1** = pane target (0, 1, 2, {left}, {right}, etc.) - optional
- **$2** = lines to capture (default: 50) - optional

### Step 1: Determine Mode

**READ Mode** (user wants to view/analyze):
- "check my terminal", "what's the error?", "show me the output"
- → Go to Step 2A

**CONTROL Mode** (user wants to execute commands):
- "run npm test", "fix the error", "stop the server"
- → Go to Step 2B

---

### Step 2A: READ Mode - EXECUTE THIS

**If $1 (pane) is provided:**
```bash
tmux capture-pane -t <$1> -p -S -<$2 or 50>
```

**If $1 (pane) is NOT provided:**
```bash
tmux list-panes -F '#{pane_index}: #{pane_current_command} (#{pane_width}x#{pane_height})'
```
Then ask user which pane to capture.

After capturing, analyze the output and report to user.

---

### Step 2B: CONTROL Mode - EXECUTE THIS

1. **Classify command risk:**
   - GREEN (auto-approve): `ls`, `cat`, `git status`, `pwd`
   - YELLOW (ask user): `npm install`, `git commit`, `make`
   - RED (strong warning): `rm -rf`, `sudo`, `--force`

2. **If approved, execute:**
```bash
tmux send-keys -t <pane> "<command>" Enter
```

3. **Wait for completion - invoke /tmux-wait:**
```
/tmux-wait prompt <pane> 60
```

4. **Capture and verify results:**
```bash
tmux capture-pane -t <pane> -p -S -50
```

5. **Report results to user.**

---

## Reference Documentation

### Primary Interface

This skill is the PRIMARY interface for ALL tmux pane interactions.

**Rules:**
- ✅ Use `/see-terminal` for ANY tmux pane interaction
- ✅ Use for both READ and CONTROL operations
- ❌ Never use direct `tmux` commands outside this skill

**Capabilities:**
- Reading pane contents (READ mode)
- Executing commands in panes (CONTROL mode)
- Waiting for completion (delegates to /tmux-wait)
- Claude slash command execution
- Permission approval workflows

### Using /tmux-wait for Waiting

**Always use /tmux-wait skill for waiting operations:**

```
/tmux-wait prompt 0 60      # Wait for prompt
/tmux-wait output 0 "text"  # Wait for specific text
/tmux-wait command 0 npm test  # Execute + wait (shortcut)
```

**Never write manual polling loops.**

### Workflow Pattern

After executing a command in CONTROL mode:
1. `/tmux-wait prompt <pane> 60` - Wait for completion
2. `/see-terminal <pane>` - Capture and analyze results
3. Report to user

---

## READ Mode Details

### Analysis Instructions

After capturing pane output, analyze with focus on:
1. **Current State**: What is the terminal showing?
2. **Output Analysis**: Errors, build results, logs
3. **Context**: What was happening?
4. **Next Steps**: Suggest relevant actions
5. **Error Detection**: Flag any issues

### Error Handling

- **"can't find pane: X"** → Pane doesn't exist
- **"no server running"** → No tmux session active
- **Invalid numeric values** → Line count must be positive integer

### Parameters

- **pane-target** (optional): Pane number (0, 1, 2) or position ({right}, {left})
- **lines** (optional): Number of lines to capture (default: 50)

---

## CONTROL Mode Details

## Command Execution

To execute commands in a tmux pane, use `tmux send-keys`:

**Basic command execution**:
```bash
tmux send-keys -t <pane> "<command>" Enter
```

**Special key sequences**:
- `C-c` - Send interrupt signal (Ctrl+C)
- `C-d` - Send EOF signal (Ctrl+D)
- `C-z` - Suspend process (Ctrl+Z)

**Literal text (without executing)**:
```bash
tmux send-keys -t <pane> -l "<text>"
```

## Safety Protocol

Before executing any command, classify it by risk level:

### GREEN Commands (Auto-approve)
Read-only commands with no side effects - execute immediately without asking:
- **File viewing**: `ls`, `cat`, `head`, `tail`, `less`, `more`
- **Navigation**: `pwd`, `cd`, `which`, `whereis`
- **Information**: `echo`, `printf`, `date`, `whoami`, `hostname`
- **Git read-only**: `git status`, `git log`, `git diff`, `git show`, `git branch`
- **Process info**: `ps`, `top`, `htop` (read-only)
- **Search**: `grep`, `find` (without `-delete`)

### YELLOW Commands (Request approval)
Commands with side effects but generally safe - ask user first:
- **Package management**: `npm install`, `pip install`, `cargo build`, `apt install`
- **Build/test**: `make`, `npm run build`, `npm test`, `pytest`, `cargo test`
- **Git write operations**: `git add`, `git commit`, `git push`, `git pull`, `git checkout`
- **File modifications**: `cp`, `mv`, `mkdir`, `touch`, `ln`
- **Editor commands**: `vim`, `nano`, `code`

**Approval format for YELLOW commands**:
1. State what you'll do: "I'll run 'npm install lodash' in pane 1"
2. Explain the effect: "This will install the lodash package and update package.json"
3. Wait for user confirmation
4. Execute only if approved

### RED Commands (Extra warning)
Destructive or high-risk operations - require strong warning:
- **Destructive deletions**: `rm -rf`, `dd`, `mkfs`, `fdisk`
- **System changes**: `sudo` (any command), `chmod 777`, `chown`
- **Force flags**: Any command with `--force`, `-f`, `--hard`, `--production` flags
- **Remote execution**: `curl | bash`, `wget | sh`, `eval`
- **Process termination**: `kill -9`, `killall`

**Approval format for RED commands**:
1. **WARNING** prefix in bold
2. Explain exactly what will be destroyed/changed
3. State that this is irreversible
4. Ask for explicit confirmation: "Are you absolutely sure?"
5. Execute only after strong affirmative response

### Special Case: Interrupt Signals
Sending interrupt signals (Ctrl+C, Ctrl+Z, etc.) terminates or suspends processes:
- **Classification**: Special case - not GREEN (has side effects) but less risky than RED
- **Handling**: Use judgment based on context
  - If user explicitly requests "stop the server" or "kill process" - execute immediately
  - If interrupting a long-running build/test - briefly confirm intent
  - If interrupting critical processes (databases, system services) - ask for confirmation
- **Note**: Interrupted processes may leave cleanup work incomplete

## Command Execution Pattern

When executing any command:

1. **Classify** the command (GREEN/YELLOW/RED)
2. **Request approval** if needed (YELLOW/RED)
3. **Execute** the command:
   ```bash
   tmux send-keys -t <pane> "<command>" Enter
   ```
4. **Wait for completion** using /tmux-wait skill:
   ```
   /tmux-wait prompt <pane> 60
   ```
   This replaces manual polling and provides reliable completion detection.

5. **Verify** results by capturing pane:
   ```bash
   tmux capture-pane -t <pane> -p -S -50
   ```
6. **Report** results to user:
   - If successful: Confirm completion and summarize outcome
   - If failed: Identify error and suggest solutions
   - If still running: Note that command is in progress

## Post-Execution Verification

After sending any command, automatically verify the results:

1. **Wait for completion** using `/tmux-wait prompt`:
   ```
   /tmux-wait prompt <pane> 60
   ```
   - Fast commands complete in ~0.2-0.5 seconds
   - Long commands are detected when they finish (up to 60s timeout)
   - More reliable than fixed delays or manual polling

2. **Capture pane** to check results:
   ```bash
   tmux capture-pane -t <pane> -p -S -50
   ```

3. **Analyze output**:
   - Check for error messages
   - Verify expected success indicators
   - Look for prompts or waiting states

4. **Report to user**:
   - "Command completed successfully"
   - "Error occurred: [error details]"
   - "Command is still running..."

## Pane Targeting

Support multiple target formats:

- **Pane number**: 0, 1, 2, 3 (absolute pane indices)
- **Relative position**: {right}, {left}, {top}, {bottom}, {up}, {down}
- **Last active pane**: ! or last

Examples:
```bash
tmux send-keys -t 1 "npm test" Enter    # Execute in pane 1
tmux send-keys -t {right} "npm test" Enter    # Execute in right pane
tmux send-keys -t 0 C-c    # Send Ctrl+C to pane 0
```

## Sending Input to Claude Code in Controlled Panes

**CRITICAL: Special handling required for ALL input to Claude Code**

When controlling a pane running Claude Code, **ALL input** (slash commands AND regular text prompts) requires special handling.

### The Two-Enter Pattern

**CRITICAL REQUIREMENT:** ALL input to Claude Code requires **TWO SEPARATE send-keys commands with a 1-second delay between them** - never combine them!

```bash
# STEP 1: Send the text/command with first Enter
tmux send-keys -t <pane> "your input here" Enter

# STEP 2: Wait 1 second for autocomplete/UI to process
sleep 1

# STEP 3: Send second Enter to submit
tmux send-keys -t <pane> Enter
```

**Why this pattern is required:**
1. First Enter: Types the input and triggers Claude's autocomplete/input system
2. Sleep 1 second: Gives the UI time to process and display
3. Second Enter: Submits the input for processing

**This applies to ALL input types:**
- Slash commands: `/init-team-ai`, `/exit`, `/init`, `/help`, `/clear`, `/compact`
- Regular text prompts: "What does this code do?", "Fix the bug", etc.
- Any text you send to Claude Code

**CRITICAL: Verify execution after second Enter:**

After pressing Enter the second time, immediately check if it executed:

```bash
# After the second Enter, capture pane to verify
tmux capture-pane -t <pane> -p -S -50
```

Check the captured output:
- If you still see the autocomplete menu (lines like `/init-team-ai    Initialize a new project...`), the Enter didn't go through
- If the autocomplete menu is gone and you see command execution starting, it worked

**If Enter didn't go through, press it again:**
```bash
tmux send-keys -t <pane> Enter
```

Then capture again to verify. Repeat until the command executes.

**❌ WRONG - DO NOT DO THIS:**
```bash
# NEVER combine both Enters in one command - this will NOT work!
tmux send-keys -t <pane> "/exit" Enter Enter

# NEVER skip the sleep - autocomplete needs time to load!
tmux send-keys -t <pane> "/init-team-ai" Enter
tmux send-keys -t <pane> Enter  # Too fast!
```

**✅ CORRECT - ALWAYS DO THIS:**
```bash
# Example 1: Executing a skill
tmux send-keys -t <pane> "/init-team-ai" Enter
sleep 1
tmux send-keys -t <pane> Enter

# Example 2: Exiting Claude
tmux send-keys -t <pane> "/exit" Enter
sleep 1
tmux send-keys -t <pane> Enter

# Example 3: Sending a regular text prompt
tmux send-keys -t <pane> "What does Claude.local.md say about commits?" Enter
sleep 1
tmux send-keys -t <pane> Enter

# Then immediately verify it executed (use /see-terminal skill)
```

**Remember:**
1. You MUST use two separate Bash tool calls for ANY input to Claude Code
2. You MUST add `sleep 1` between them
3. You MUST verify the input was submitted after the second Enter
4. If the input is still in the text field, press Enter again

### Approving Claude Permissions

When Claude shows permission prompts during skill execution:

```
Do you want to proceed?
❯ 1. Yes
  2. Yes, and don't ask again for similar commands
  3. No
```

**CRITICAL: Use arrow navigation, NOT typing numbers**

```bash
# ❌ WRONG - Typing "2" doesn't select option 2
tmux send-keys -t <pane> "2" Enter

# ✅ CORRECT - Navigate with Down arrow
tmux send-keys -t <pane> Down Enter  # Selects option 2
```

**Navigation pattern:**
- Option 1 (default): Just `Enter`
- Option 2: `Down Enter` (move down once, then confirm)
- Option 3: `Down Down Enter` (move down twice, then confirm)

### Complete Claude Skill Testing Workflow

Example: Testing `/init-team-ai` skill in pane 0

```bash
# Step 1: Start Claude in the pane
tmux send-keys -t 0 "claude" Enter
```

Wait for Claude to start using `/tmux-wait`:
```
/tmux-wait prompt 0 60
```

Verify Claude is ready:
```
/see-terminal 0 80
```

```bash
# Step 2: Execute the skill (TWO separate Enters with 1 second delay)
tmux send-keys -t 0 "/init-team-ai" Enter
sleep 1
tmux send-keys -t 0 Enter
```

Verify skill started executing (capture to check autocomplete is gone):
```bash
tmux capture-pane -t 0 -p -S -50
```

If autocomplete still showing, press Enter again.

Wait for permission prompt or completion (prompt mode auto-detects both):
```
/tmux-wait prompt 0 60
```

Check what happened:
```
/see-terminal 0 100
```

If permission prompt shown, approve it:
```bash
tmux send-keys -t 0 Down Enter
```

Wait for skill to complete:
```
/tmux-wait prompt 0 60
```

Verify completion:
```
/see-terminal 0 100
```

```bash
# Step 3: Exit Claude (using proper two-Enter pattern)
tmux send-keys -t 0 "/exit" Enter
sleep 1
tmux send-keys -t 0 Enter
```

**Key points:**
- ✅ Two Enters for ALL input to Claude Code (slash commands AND regular prompts)
- ✅ Sleep 1 second between the two Enters for UI to process
- ✅ Down arrow navigation for permission selection
- ✅ Use `/tmux-wait` for all waiting operations (no manual polling!)
- ✅ Use `/see-terminal` to capture and analyze final state
- ✅ Sequential permission approval for "don't ask again" option

## Example Workflows

### Workflow 1: Auto-approve GREEN command
User: "Run ls in pane 1"
> Classify: GREEN (read-only)
> Execute immediately: `tmux send-keys -t 1 "ls" Enter`
> Wait for prompt: `/tmux-wait prompt 1`
> Capture and analyze: `/see-terminal 1`
> Report: "Here's the directory listing from pane 1: [output]"

### Workflow 2: Request approval for YELLOW command
User: "Install lodash in the right pane"
> Classify: YELLOW (package management)
> Request approval: "I'll run 'npm install lodash' in the right pane. This will install the lodash package and update package.json. Proceed?"
> Wait for user response
> If approved: Execute `tmux send-keys -t {right} "npm install lodash" Enter`
> Wait for completion: `/tmux-wait prompt {right} 60`
> Verify and analyze: `/see-terminal {right}`
> Report results with summary of what was installed

### Workflow 3: Extra warning for RED command
User: "Delete node_modules in pane 0"
> Classify: RED (destructive deletion)
> Strong warning: "**WARNING**: This will run 'rm -rf node_modules' which permanently deletes the entire node_modules directory. This cannot be undone. Are you absolutely sure?"
> Wait for explicit confirmation
> If confirmed: Execute and verify
> Report results

### Workflow 4: Interrupt running process
User: "Stop the server in pane 1"
> Classify: Special case (interrupt signal)
> User explicitly requested, context is clear (stopping server)
> Execute immediately: `tmux send-keys -t 1 C-c`
> Wait for prompt return: `/tmux-wait prompt 1 10`
> Verify server stopped: `/see-terminal 1`
> Report: "Sent interrupt signal (Ctrl+C) to pane 1. Server stopped."

### Workflow 5: Fix error after diagnosis
User: "Check pane 1"
> READ mode: `/see-terminal 1`
> Claude: "Error: Module 'lodash' not found"
User: "Fix it"
> CONTROL mode: Classify npm install as YELLOW
> Request approval: "I'll run 'npm install lodash' in pane 1 to fix the missing module. Proceed?"
> User approves
> Execute: `tmux send-keys -t 1 "npm install lodash" Enter`
> Wait for completion: `/tmux-wait prompt 1 60`
> Verify installation: `/see-terminal 1`
> Report: "lodash installed successfully. Error resolved."

### Workflow 6: Testing Claude Skills
User: "takeover pane 0, start claude, test /init-team-ai, approve all permissions"
> CONTROL mode: Multi-step workflow with Claude skill execution

**Step 1: Capture initial state**
```bash
tmux capture-pane -t 0 -p -S -50
```
Report current pane state.

**Step 2: Start Claude**
```bash
tmux send-keys -t 0 "claude" Enter
```

**Step 3: Wait for Claude to start**
```
/tmux-wait prompt 0 60
```
Then verify Claude is ready:
```
/see-terminal 0 80
```

**Step 4: Execute skill (TWO SEPARATE send-keys commands!)**
```bash
# First command: Send skill name with first Enter
tmux send-keys -t 0 "/init-team-ai" Enter

# MUST use sleep between the two Enters
sleep 1

# Second command: Send second Enter to execute
tmux send-keys -t 0 Enter
```
**CRITICAL:** These MUST be two separate Bash tool calls, NOT combined in one command!

**Step 5: Wait for permission prompt or completion**
```
/tmux-wait prompt 0 60
```

Check what happened:
```
/see-terminal 0 100
```

If permission prompt shown, approve with option 2:
```bash
tmux send-keys -t 0 Down Enter
```

Wait for skill to complete:
```
/tmux-wait prompt 0 60
```

**Step 6: Verify completion**
```
/see-terminal 0 100
```
Check final results and verify all files were created correctly.

**Step 7: Exit Claude (using proper two-Enter pattern)**
```bash
tmux send-keys -t 0 "/exit" Enter
sleep 1
tmux send-keys -t 0 Enter
```
Or wait for user to manually exit.

**Key learnings applied:**
- ✅ Two Enters for ALL input to Claude Code (slash commands AND regular prompts)
- ✅ Sleep 1 second between the two Enters for UI to process
- ✅ Down arrow navigation for permission selection
- ✅ Use `/tmux-wait` for all waiting operations - NO manual polling loops!
- ✅ Use `/see-terminal` after waiting to capture and analyze final state
- ✅ Sequential permission approval for "don't ask again" option
