---
name: see-terminal
description: Capture and control tmux pane contents
argument-hint: [pane-target (optional, default: asks user)] [lines (optional, default: 50)]
allowed-tools: Bash(command:*)
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
- Smart polling and monitoring
- Claude slash command execution
- Permission approval workflows

**There is NO valid reason to use tmux commands outside this skill.**

---

## CRITICAL USAGE NOTE

**NEVER use `sleep` commands before invoking this skill.**

When you need to check terminal output after sending commands to a tmux pane, call this skill IMMEDIATELY - do not add delays:

**❌ WRONG - Adding sleep before skill invocation:**
```bash
tmux send-keys -t 0 "claude" Enter
sleep 2  # NEVER DO THIS!
# Then invoke /see-terminal skill
```

**✅ CORRECT - Invoke skill immediately:**
```bash
tmux send-keys -t 0 "claude" Enter
# Immediately invoke /see-terminal skill (no sleep needed)
```

The skill will capture the current pane state. If you need to wait for a command to complete, capture multiple times in sequence rather than using sleep delays. The skill is designed to be called repeatedly and efficiently.

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

## Smart Polling for Monitoring

**CRITICAL: Always use smart polling when monitoring panes in CONTROL mode.**

When you need to wait for a command to complete or monitor for specific output:

1. **Use smart polling** - Check pane output every 0.2 seconds
2. **Look for prompts** - Shell prompts (`$`, `#`, `%`) or Claude prompts (`❯`, `›`)
3. **Look for patterns** - Permission prompts, completion messages, error patterns
4. **Never use fixed sleep** - Polling is more reliable and responsive

**Example smart polling pattern:**
```bash
max_polls=150  # 30 seconds timeout
poll_count=0
while ((poll_count++ < max_polls)); do
  output=$(tmux capture-pane -t <pane> -p -S -50)

  # Check for what you're looking for
  if echo "$output" | grep -q "expected pattern"; then
    break
  fi

  sleep 0.2
done
```

After polling completes, **always** use the /see-terminal skill to capture and analyze the final state.

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
4. **Wait intelligently** for command to complete using prompt detection:
   - Poll pane every 0.2 seconds
   - Check if output ends with shell prompt (`$`, `#`, `%`) or Claude prompt (`❯`, `›`)
   - Use this bash pattern:
   ```bash
   max_polls=300  # 60 seconds timeout (300 * 0.2s)
   poll_count=0
   while ((poll_count++ < max_polls)); do
     output=$(tmux capture-pane -t <pane> -p -S -10)

     # Get last non-empty line
     last_line=$(echo "$output" | sed '/^[[:space:]]*$/d' | tail -1)

     # Check if it ends with a prompt character (shell or Claude)
     if [[ "$last_line" =~ (\$|#|%|❯|›)[[:space:]]*$ ]]; then
       # Prompt detected - command complete
       break
     fi

     sleep 0.2
   done
   ```
   - If timeout reached (60s), note that command may still be running
5. **Verify** results by auto-capturing pane:
   ```bash
   tmux capture-pane -t <pane> -p -S -50
   ```
6. **Report** results to user:
   - If successful: Confirm completion and summarize outcome
   - If failed: Identify error and suggest solutions
   - If still running: Note that command is in progress

## Post-Execution Verification

After sending any command, automatically verify the results:

1. **Wait for completion** using intelligent prompt detection (see Command Execution Pattern step 4 above)
   - Fast commands complete in ~0.2-0.5 seconds
   - Long commands are detected when they finish (up to 60s timeout)
   - More reliable than fixed delays
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

## Smart Polling Implementation Notes

The prompt detection polling works as follows:

**How it works:**
1. After sending command, immediately start polling
2. Capture last 10 lines of pane every 200ms (optimized for performance)
3. Filter out empty lines to get the last non-empty line
4. Check if it ends with common shell prompt characters: `$`, `#`, or `%`
5. When detected, command is complete

**Prompt patterns detected:**
- `$` followed by optional whitespace - Standard bash/sh user prompt
- `#` followed by optional whitespace - Root prompt
- `%` followed by optional whitespace - Zsh prompt
- `❯` followed by optional whitespace - Claude Code prompt
- `›` followed by optional whitespace - Alternative Claude Code prompt
- Works with both minimal prompts (`$`) and full prompts (`user@host:~/dir$`)
- Works with Claude Code prompts in any state (ready, working, etc.)

**Edge cases handled:**
- Multi-line prompts: Filters empty lines to find actual prompt line
- Commands that output `$` in results: Only matches if `$#%` is at line end
- Very long commands: 60-second timeout prevents infinite loops
- Commands with no output: Still detects prompt return
- First command in fresh pane: Detects the prompt correctly

**Performance:**
- Average detection time for quick commands: 0.2-0.5 seconds (vs 2-3s with sleep)
- Long-running commands: Detected when they finish (not after arbitrary timeout)
- CPU overhead: Minimal (captures only 10 lines every 200ms = ~50 lines/sec while waiting)
- 5x more efficient than capturing 50 lines per poll

**Known limitations:**
- Custom prompts without `$`, `#`, `%`, `❯`, or `›` suffixes will timeout after 60s
- Workaround: Users can temporarily set PS1 to include standard suffix
- Note: Claude Code prompts (`❯`, `›`) are fully supported

**Timeout behavior:**
After 60 seconds (300 polls):
- Stop polling
- Capture final pane state
- Report to user that command may still be running or completed without returning to prompt

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
- Skills: `/init-team-ai`, `/see-terminal`
- Built-in commands: `/exit`, `/init`, `/help`, `/clear`
- Any command starting with `/`

**CRITICAL: Add robustness check after second Enter:**

After pressing Enter the second time, immediately check if it executed:

```bash
# After the second Enter, capture pane to verify
tmux capture-pane -t <pane> -p -S -50
```

Check the captured output:
- If you still see the autocomplete menu (lines like `/init-team-ai    Initialize a new project...` or `/exit    Exit Claude Code`), the Enter didn't go through
- If the autocomplete menu is gone and you see command execution starting (or Claude exiting for /exit), it worked

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

# Step 2: Wait for Claude to start using smart polling
max_polls=50; poll_count=0
while ((poll_count++ < max_polls)); do
  output=$(tmux capture-pane -t 0 -p -S -10)
  last_line=$(echo "$output" | sed '/^[[:space:]]*$/d' | tail -1)
  if [[ "$last_line" =~ (❯|›)[[:space:]]*$ ]]; then
    break
  fi
  sleep 0.2
done

# Invoke /see-terminal to check Claude is ready
# (Skill tool with skill: "see-terminal", args: "0 80")

# Step 3: Execute the skill (TWO separate Enters with 1 second delay)
tmux send-keys -t 0 "/init-team-ai" Enter
sleep 1
tmux send-keys -t 0 Enter

# Step 4: Verify skill started executing using smart polling
# Wait a moment for autocomplete to disappear and skill to start
max_polls=50; poll_count=0
while ((poll_count++ < max_polls)); do
  output=$(tmux capture-pane -t 0 -p -S -50)
  # Check if autocomplete menu is gone (no lines with /init-team-ai followed by description)
  if ! echo "$output" | grep -q "/init-team-ai.*Initialize"; then
    break
  fi
  # If still showing autocomplete, press Enter again
  if ((poll_count % 5 == 0)); then
    tmux send-keys -t 0 Enter
  fi
  sleep 0.2
done

# Invoke /see-terminal to verify skill is executing
# (Skill tool with skill: "see-terminal", args: "0 100")

# Step 5: Monitor for permission prompts using smart polling
max_polls=150; poll_count=0
while ((poll_count++ < max_polls)); do
  output=$(tmux capture-pane -t 0 -p -S -50)
  # Check for permission prompt pattern
  if echo "$output" | grep -q "Do you want to proceed?"; then
    # Permission prompt detected - approve it
    tmux send-keys -t 0 Down Enter
    sleep 0.5
  fi
  # Check if skill completed (look for completion message or prompt return)
  if echo "$output" | grep -q "Team AI Initialization Complete"; then
    break
  fi
  sleep 0.2
done

# Step 6: Verify completion
# Invoke /see-terminal to check final results
# (Skill tool with skill: "see-terminal", args: "0 100")

# Step 7: Exit Claude (using proper two-Enter pattern)
tmux send-keys -t 0 "/exit" Enter
sleep 1
tmux send-keys -t 0 Enter
```

## Example Workflows

### Workflow 1: Auto-approve GREEN command
User: "Run ls in pane 1"
> Classify: GREEN (read-only)
> Execute immediately: `tmux send-keys -t 1 "ls" Enter`
> Smart poll for prompt:
```bash
max_polls=300; poll_count=0
while ((poll_count++ < max_polls)); do
  output=$(tmux capture-pane -t 1 -p -S -10)
  last_line=$(echo "$output" | sed '/^[[:space:]]*$/d' | tail -1)
  if [[ "$last_line" =~ (\$|#|%|❯|›)[[:space:]]*$ ]]; then
    break
  fi
  sleep 0.2
done
```
> Use /see-terminal skill to capture and analyze: Invoke Skill tool with skill: "see-terminal", args: "1"
> Report: "Here's the directory listing from pane 1: [output]"

### Workflow 2: Request approval for YELLOW command
User: "Install lodash in the right pane"
> Classify: YELLOW (package management)
> Request approval: "I'll run 'npm install lodash' in the right pane. This will install the lodash package and update package.json. Proceed?"
> Wait for user response
> If approved: Execute `tmux send-keys -t {right} "npm install lodash" Enter`
> Smart poll for completion:
```bash
max_polls=300; poll_count=0
while ((poll_count++ < max_polls)); do
  output=$(tmux capture-pane -t {right} -p -S -10)
  last_line=$(echo "$output" | sed '/^[[:space:]]*$/d' | tail -1)
  if [[ "$last_line" =~ (\$|#|%|❯|›)[[:space:]]*$ ]]; then
    break
  fi
  sleep 0.2
done
```
> Use /see-terminal skill to verify and analyze results
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
> Smart poll for prompt return:
```bash
max_polls=50; poll_count=0
while ((poll_count++ < max_polls)); do
  output=$(tmux capture-pane -t 1 -p -S -10)
  last_line=$(echo "$output" | sed '/^[[:space:]]*$/d' | tail -1)
  if [[ "$last_line" =~ (\$|#|%|❯|›)[[:space:]]*$ ]]; then
    break
  fi
  sleep 0.2
done
```
> Use /see-terminal skill to verify server stopped
> Report: "Sent interrupt signal (Ctrl+C) to pane 1. Server stopped."

### Workflow 5: Fix error after diagnosis
User: "Check pane 1"
> READ mode: Use /see-terminal skill to capture and analyze
> Claude: "Error: Module 'lodash' not found"
User: "Fix it"
> CONTROL mode: Classify npm install as YELLOW
> Request approval: "I'll run 'npm install lodash' in pane 1 to fix the missing module. Proceed?"
> User approves
> Execute: `tmux send-keys -t 1 "npm install lodash" Enter`
> Smart poll for completion:
```bash
max_polls=300; poll_count=0
while ((poll_count++ < max_polls)); do
  output=$(tmux capture-pane -t 1 -p -S -10)
  last_line=$(echo "$output" | sed '/^[[:space:]]*$/d' | tail -1)
  if [[ "$last_line" =~ (\$|#|%|❯|›)[[:space:]]*$ ]]; then
    break
  fi
  sleep 0.2
done
```
> Use /see-terminal skill to verify installation
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

**Step 3: Monitor Claude startup using smart polling**
```bash
max_polls=50; poll_count=0
while ((poll_count++ < max_polls)); do
  output=$(tmux capture-pane -t 0 -p -S -10)
  last_line=$(echo "$output" | sed '/^[[:space:]]*$/d' | tail -1)
  if [[ "$last_line" =~ (❯|›)[[:space:]]*$ ]]; then
    break
  fi
  sleep 0.2
done
```
Then use /see-terminal skill to verify Claude is ready (Skill tool with skill: "see-terminal", args: "0 80")

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

**Step 5: Verify skill started and monitor for permission prompts using smart polling**
```bash
max_polls=150; poll_count=0
while ((poll_count++ < max_polls)); do
  output=$(tmux capture-pane -t 0 -p -S -50)

  # Check for permission prompt
  if echo "$output" | grep -q "Do you want to proceed?"; then
    # Permission detected - approve with option 2
    tmux send-keys -t 0 Down Enter
    sleep 0.5
  fi

  # Check if skill completed
  if echo "$output" | grep -q "Team AI Initialization Complete"; then
    break
  fi

  sleep 0.2
done
```

**Step 6: Verify completion**
Use /see-terminal skill to check final results and verify all files were created correctly (Skill tool with skill: "see-terminal", args: "0 100")

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
- ✅ Use smart polling with Claude prompt detection (`❯`, `›`) for all monitoring
- ✅ Use /see-terminal skill after polling to capture and analyze final state
- ✅ Never use fixed sleep delays - always use smart polling instead
- ✅ Sequential permission approval for "don't ask again" option
