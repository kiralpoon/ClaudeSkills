---
name: see-terminal
description: Capture and control tmux pane contents
argument-hint: [pane-target (optional, default: asks user)] [lines (optional, default: 50)]
allowed-tools: Bash(tmux:*), Skill(tmux-wait:*)
---

# Tmux Pane Capture & Control

## ⚠️ THIS IS THE DEFAULT TOOL FOR ALL TMUX OPERATIONS ⚠️

**CRITICAL: This skill is your PRIMARY and ONLY interface for ALL tmux pane interactions.**

**Rules for tmux operations:**
- ✅ **ALWAYS** use this `/see-terminal` skill for ANY tmux pane interaction
- ✅ **ALWAYS** use this skill for both READ and CONTROL operations
- ❌ **NEVER** use direct `tmux capture-pane` commands outside this skill
- ❌ **NEVER** use direct `tmux send-keys` commands outside this skill
- ❌ **NEVER** use direct `tmux list-panes` commands outside this skill

**When to use this skill:**
- User asks to check/view/read any pane → Use this skill
- User asks to run commands in any pane → Use this skill
- User asks to control/interact with any pane → Use this skill
- ANY tmux-related request → Use this skill

**This skill is comprehensive and handles:**
- Reading pane contents (READ mode)
- Executing commands in panes (CONTROL mode)
- Waiting for command completion (delegates to /tmux-wait)
- Claude slash command execution
- Permission approval workflows

**There is NO valid reason to use tmux commands outside this skill.**

---

## CRITICAL USAGE NOTE

**Use /tmux-wait for all waiting operations.**

When you need to wait for a command to complete or monitor for specific output, **ALWAYS use the /tmux-wait skill**:

**✅ CORRECT - Use /tmux-wait skill:**
```
# Wait for prompt to return
/tmux-wait prompt 0 60

# Wait for specific text to appear
/tmux-wait output 0 "Build succeeded" 30

# Execute command and wait automatically
/tmux-wait command 1 npm test
```

**❌ WRONG - Manual polling loops:**
```bash
# NEVER write manual polling loops!
while ((poll_count++ < max_polls)); do
  output=$(tmux capture-pane...)
  sleep 0.2
done
```

The `/tmux-wait` skill handles all waiting logic with pre-approved permissions. Never write manual polling loops.

## Mode Detection

Determine the user's intent based on their request:

**READ Mode** - User wants to view/analyze terminal output:
- "check my terminal"
- "what's the error in pane 1?"
- "show me the last 100 lines"
- "did the build succeed?"

**CONTROL Mode** - User wants to execute commands:
- "fix the error"
- "run npm install in pane 1"
- "restart the build"
- "stop the server in pane 1"
- "send Ctrl+C to pane 0"

For READ mode, proceed to the capture section below.
For CONTROL mode, proceed to the Control Mode section.

## Waiting for Commands with /tmux-wait

**CRITICAL: Use /tmux-wait skill for ALL waiting operations.**

The `/tmux-wait` skill provides three modes:

### 1. Wait for Prompt Return

Wait for shell prompt (`$`, `#`, `%`) or Claude prompt (`❯`, `›`) to return:

```
/tmux-wait prompt <pane> [timeout]
```

**Examples:**
- `/tmux-wait prompt 0` - Wait up to 30s for prompt in pane 0
- `/tmux-wait prompt 1 60` - Wait up to 60s for prompt in pane 1

**Use this after:**
- Sending any command that you need to wait for
- Starting Claude Code
- Running tests or builds

### 2. Wait for Specific Output

Wait for specific text to appear in pane output:

```
/tmux-wait output <pane> <search-text> [timeout]
```

**Examples:**
- `/tmux-wait output 0 "Do you want to proceed?" 10` - Wait for permission prompt
- `/tmux-wait output 1 "Build succeeded" 60` - Wait for build completion
- `/tmux-wait output 0 "Team AI Initialization Complete"` - Wait for skill completion

**Use this for:**
- Permission prompts
- Completion messages
- Error messages
- Any specific pattern you're monitoring

### 3. Execute Command and Wait

Execute a command and automatically wait for completion:

```
/tmux-wait command <pane> <command>
```

**Examples:**
- `/tmux-wait command 1 npm test` - Run tests and wait
- `/tmux-wait command 0 ls -la` - List files and wait

**Use this for:**
- Simple commands where you want to execute and wait in one step
- Commands with predictable completion

### Why Use /tmux-wait?

✅ **No permission prompts** - All tools pre-approved when using `/init-team-ai`
✅ **Event-driven** - `command` mode uses `tmux wait-for` (zero CPU, instant detection)
✅ **Reliable** - Consistent timeout handling and error reporting
✅ **Clean** - One line instead of 10+ line polling loops
✅ **Maintainable** - All waiting logic in one place

## Proper Workflow After Executing Commands

**CRITICAL: After executing any command or skill, follow this pattern:**

### The Correct Pattern

After executing a command and approving any permissions:

1. **Wait for prompt return** (indicates command completed):
   ```
   /tmux-wait prompt <pane> 60
   ```

2. **Capture and analyze the actual output** (start with 50 lines):
   ```
   /see-terminal <pane>
   ```
   Or if you need more context:
   ```
   /see-terminal <pane> 100
   ```

3. **Determine success/failure** based on what actually happened in the output

**Why this pattern:**
- The prompt return tells you the command finished
- You then check WHAT actually happened
- You're not making assumptions about specific success messages
- 50 lines is usually enough; only use 100+ if you need more context

### When to Use Each /tmux-wait Mode

**Use `prompt` mode (MOST COMMON):**
- After executing any command - default choice
- After approving permissions
- Any time you need to know "is it done?"
- Example: `/tmux-wait prompt 0 60`

**Use `output` mode (SPECIFIC CASES ONLY):**
- Detecting permission prompts: `/tmux-wait output 0 "Do you want to proceed?" 10`
- Waiting for specific user input prompts
- Detecting specific error patterns you need to act on immediately
- Example: `/tmux-wait output 0 "Build failed" 30`

**❌ WRONG - Don't search for completion text that may not exist:**
```
# This assumes specific success text will appear and wastes time if it doesn't
/tmux-wait output 0 "Team AI Initialization Complete" 60
/tmux-wait output 0 "Build succeeded" 60
```

**✅ CORRECT - Wait for completion, then check what happened:**
```
# Wait for prompt (command finished)
/tmux-wait prompt 0 60

# Check what actually happened (start with 50 lines)
/see-terminal 0

# If 50 lines wasn't enough, try 100
/see-terminal 0 100
```

**Example: Testing a Claude skill**
```bash
# Execute skill
tmux send-keys -t 0 "/init-team-ai" Enter
sleep 1
tmux send-keys -t 0 Enter

# Wait for permission prompt (specific text we know will appear)
/tmux-wait output 0 "Do you want to proceed?" 10

# Approve it
tmux send-keys -t 0 Enter

# Wait for command to finish (use prompt mode)
/tmux-wait prompt 0 60

# Check what happened (start with 50 lines)
/see-terminal 0

# If you need more context, use 100 lines
/see-terminal 0 100
```

# Tmux Pane Content Capture (READ Mode)

## Parameter Validation and Capture

**Step 1: Validate pane parameter**

Provided pane parameter: $1
Provided lines parameter: $2

Check the pane parameter:
- If $1 is **provided and looks valid** (number like 0, 1, 2 or position like {left}, {right}):
  - Use it directly - **skip pane listing**
- If $1 is **empty** or **not provided**:
  - First, list available panes using: `tmux list-panes -F '#{pane_index}: #{pane_current_command} (#{pane_width}x#{pane_height})' 2>&1`
  - Present the available panes to the user
  - Ask: "Which pane would you like to capture? Please specify the pane number (e.g., 0, 1, 2) or position (left, right)."
  - Wait for user response and use their selection

**Step 2: Determine line count**

- If $2 is **empty** or **not provided**: **Automatically use 50 as the default** (no permission needed)
- If $2 is **provided**: Use the specified number

**Note**: For performance reasons, requesting more than 1000 lines may be slow. The default of 50 lines is usually sufficient for most debugging tasks.

**Step 3: Capture the pane**

Once you have validated the pane target and line count, use the Bash tool to capture the pane:

```bash
tmux capture-pane -t <pane> -p -S -<lines> 2>&1
```

Replace `<pane>` with the validated pane target (from user or $1).
Replace `<lines>` with the line count (from $2 or default 50).

After running the capture command, analyze the output below.

## Analysis Instructions

If the above capture succeeded (no error message):

Analyze the captured terminal output with focus on:

1. **Current State**: What is the terminal showing? What command was run?

2. **Output Analysis**:
   - If there are errors, identify them clearly
   - If it's build output, summarize results
   - If it's logs, highlight key events
   - If it's command output, explain what it means

3. **Context**: What was likely happening in this terminal session?

4. **Next Steps**: Based on the output, suggest relevant actions or provide insights

5. **Error Detection**: Flag any errors, warnings, or issues visible in the output

## Error Handling

If the capture command failed (error message present):

Common errors and solutions:

- **"can't find pane: X"** → The pane number/ID doesn't exist
  - Check the available panes listed above
  - Try a different pane number (0, 1, 2, etc.)

- **"no server running"** → No tmux session is active
  - Start a tmux session first with `tmux`
  - Or run this command from within a tmux session

- **Invalid numeric values** → If you see errors about invalid line numbers
  - The line count parameter must be a positive integer
  - Ask the user to request a valid number of lines

- **Other errors** → Show the error and suggest troubleshooting

## Parameters

Both parameters are **optional**:

- **pane-target** (optional): Pane number (0, 1, 2...) or relative position ({right}, {left}, etc.)
  - If not provided or invalid, Claude will show available panes and ask user to select one
  - Default behavior: Ask user for pane selection

- **lines** (optional): Number of lines to capture from pane history
  - If not provided, defaults to 50 lines
  - Can be explicitly specified for more/less context

Examples of what users might request:
- "/see-terminal" → Shows panes, asks which to capture, uses 50 lines
- "/see-terminal 0" → Captures pane 0, last 50 lines
- "/see-terminal 1 100" → Captures pane 1, last 100 lines
- "Check my terminal" → Shows panes, asks which to capture, uses 50 lines
- "What's in pane 1?" → Captures pane 1, last 50 lines
- "Show me the last 100 lines from the right pane" → Captures right pane, 100 lines

---

# Tmux Pane Control (CONTROL Mode)

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

## Executing Claude Slash Commands in Controlled Panes

**CRITICAL: Special handling required for ALL Claude Code slash commands**

When controlling a pane running Claude Code to execute ANY slash command (like `/init-team-ai`, `/exit`, `/init`, etc.):

### The Two-Enter Pattern

**CRITICAL REQUIREMENT:** ALL slash commands in Claude Code require **TWO SEPARATE send-keys commands with a 1-second delay between them** - never combine them!

```bash
# STEP 1: Send the slash command with first Enter
tmux send-keys -t <pane> "/command" Enter

# STEP 2: Wait 1 second for autocomplete to load
sleep 1

# STEP 3: Send second Enter to execute
tmux send-keys -t <pane> Enter
```

**Why this pattern is required:**
1. First Enter: Types the command and triggers Claude's autocomplete system
2. Sleep 1 second: Gives autocomplete UI time to load and display
3. Second Enter: Executes the command after autocomplete is shown

**This applies to ALL slash commands:**
- Skills: `/init-team-ai`, `/see-terminal`, `/tmux-wait`
- Built-in commands: `/exit`, `/init`, `/help`, `/clear`
- Any command starting with `/`

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

# Then immediately verify it executed (use /see-terminal skill)
```

**Remember:**
1. You MUST use two separate Bash tool calls for ANY slash command
2. You MUST add `sleep 1` between them
3. You MUST verify the command started executing after the second Enter
4. If autocomplete is still showing, press Enter again

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

Monitor for permission prompts and completion:
```
/tmux-wait output 0 "Do you want to proceed?" 10
```

If permission prompt found, approve it:
```bash
tmux send-keys -t 0 Down Enter
```

Wait for skill completion:
```
/tmux-wait output 0 "Team AI Initialization Complete" 60
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
- ✅ Two Enters for ALL slash commands (skills, /exit, /init, etc.)
- ✅ Sleep 1 second between the two Enters for autocomplete to load
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

**Step 5: Monitor for permission prompts and completion**
Wait for permission prompt:
```
/tmux-wait output 0 "Do you want to proceed?" 10
```

If found, approve with option 2:
```bash
tmux send-keys -t 0 Down Enter
```

Wait for skill completion:
```
/tmux-wait output 0 "Team AI Initialization Complete" 60
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
- ✅ Two Enters for ALL slash commands (skills, /exit, /init, etc.)
- ✅ Sleep 1 second between the two Enters for autocomplete to load
- ✅ Down arrow navigation for permission selection
- ✅ Use `/tmux-wait` for all waiting operations - NO manual polling loops!
- ✅ Use `/see-terminal` after waiting to capture and analyze final state
- ✅ Sequential permission approval for "don't ask again" option
