---
name: see-terminal
description: Capture and control tmux pane contents
argument-hint: [pane-target (optional, default: asks user)] [lines (optional, default: 50)]
allowed-tools: Bash(tmux:*)
---

# Tmux Pane Capture & Control

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

# Tmux Pane Content Capture (READ Mode)

## Validate Tmux Session and Parameters

First, verify tmux is running and show available panes.

Use the Bash tool to run:
```bash
tmux list-panes -F '#{pane_index}: #{pane_current_command} (#{pane_width}x#{pane_height})' 2>&1
```

This will show you all available panes. If it fails with "no server running", inform the user that tmux is not active.

## Parameter Validation and Capture

**Step 1: Validate pane parameter**

Provided pane parameter: $1
Provided lines parameter: $2

Check the pane parameter:
- If $1 is **empty** or **not provided**: You must ask the user which pane to capture
  - Present the available panes listed above
  - Ask: "Which pane would you like to capture? Please specify the pane number (e.g., 0, 1, 2) or position (left, right)."
  - Wait for user response and use their selection
- If $1 is **provided and looks valid** (number like 0, 1, 2 or position like {left}, {right}): Use it directly

**Step 2: Determine line count**

- If $2 is **empty** or **not provided**: Use 50 as the default
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
   - Check if output ends with shell prompt (`$`, `#`, or `%`)
   - Use this bash pattern:
   ```bash
   max_polls=300  # 60 seconds timeout (300 * 0.2s)
   poll_count=0
   while ((poll_count++ < max_polls)); do
     output=$(tmux capture-pane -t <pane> -p -S -10)

     # Get last non-empty line
     last_line=$(echo "$output" | sed '/^[[:space:]]*$/d' | tail -1)

     # Check if it ends with a prompt character
     if [[ "$last_line" =~ [$#%][[:space:]]*$ ]]; then
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
- Works with both minimal prompts (`$`) and full prompts (`user@host:~/dir$`)

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
- Custom prompts without `$`, `#`, or `%` suffixes will timeout after 60s
- Workaround: Users can temporarily set PS1 to include standard suffix

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

## Example Workflows

### Workflow 1: Auto-approve GREEN command
User: "Run ls in pane 1"
> Classify: GREEN (read-only)
> Execute immediately: `tmux send-keys -t 1 "ls" Enter`
> Poll for prompt (detected in ~0.2-0.4s for ls command)
> Capture and verify: `tmux capture-pane -t 1 -p -S -50`
> Report: "Here's the directory listing from pane 1: [output]"

### Workflow 2: Request approval for YELLOW command
User: "Install lodash in the right pane"
> Classify: YELLOW (package management)
> Request approval: "I'll run 'npm install lodash' in the right pane. This will install the lodash package and update package.json. Proceed?"
> Wait for user response
> If approved: Execute `tmux send-keys -t {right} "npm install lodash" Enter`
> Wait and verify
> Report results

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
> Wait and verify
> Report: "Sent interrupt signal (Ctrl+C) to pane 1. Server stopped."

### Workflow 5: Fix error after diagnosis
User: "Check pane 1"
> READ mode: Capture and analyze
> Claude: "Error: Module 'lodash' not found"
User: "Fix it"
> CONTROL mode: Classify npm install as YELLOW
> Request approval: "I'll run 'npm install lodash' in pane 1 to fix the missing module. Proceed?"
> User approves
> Execute, wait, verify
> Report: "lodash installed successfully. Error resolved."
