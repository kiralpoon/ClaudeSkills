---
name: see-terminal
description: Capture and control tmux pane contents
argument-hint: [pane-target] [lines]
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

## Validate Tmux Session

First, verify tmux is running and show available panes:

Available panes: !`tmux list-panes -F '#{pane_index}: #{pane_current_command} (#{pane_width}x#{pane_height})' 2>&1`

## Capture Pane Contents

Target pane: $1
Lines to capture: $2

**Note**: For performance reasons, requesting more than 1000 lines may be slow. The default of 50 lines is usually sufficient for most debugging tasks. When invoking this skill, always provide both parameters explicitly (e.g., "0 50" for pane 0 with 50 lines).

Captured output: !`tmux capture-pane -t $1 -p -S -$2 2>&1`

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

When Claude invokes this skill, it can specify:

- **pane-target** (default: 0): Pane number (0, 1, 2...) or relative position ({right}, {left}, etc.)
- **lines** (default: 50): Number of lines to capture from pane history

Examples of what users might request:
- "Check my terminal" → captures pane 0, last 50 lines
- "What's in pane 1?" → captures pane 1, last 50 lines
- "Show me the last 100 lines from the right pane" → captures right pane, 100 lines

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
4. **Wait** 2-3 seconds for command to execute
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

1. **Wait briefly** (2-3 seconds) for command to execute
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

- **Pane number**: `0`, `1`, `2`, `3` (absolute pane indices)
- **Relative position**: `{right}`, `{left}`, `{top}`, `{bottom}`, `{up}`, `{down}`
- **Last active pane**: `!` or `last`

Examples:
- `tmux send-keys -t 1 "npm test" Enter` - Execute in pane 1
- `tmux send-keys -t {right} "npm test" Enter` - Execute in right pane
- `tmux send-keys -t 0 C-c` - Send Ctrl+C to pane 0

## Example Workflows

### Workflow 1: Auto-approve GREEN command
User: "Run ls in pane 1"
> Classify: GREEN (read-only)
> Execute immediately: `tmux send-keys -t 1 "ls" Enter`
> Wait 2 seconds
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
