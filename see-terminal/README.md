# See-Terminal Skill

Capture and control tmux pane contents - the default tool for all tmux operations.

## Why This Skill?

**The Problem:**
- Manually running `tmux capture-pane` commands is repetitive
- Controlling panes requires remembering complex tmux syntax
- Waiting for commands needs proper synchronization

**The Solution:**
- Single skill for both reading (capture) and controlling (execute) tmux panes
- Integrates with `/tmux-wait` for reliable command completion
- Pre-approved permissions when using `/init-team-ai`

## Installation

```bash
cd /home/kiral/ClaudeSkills/see-terminal
./install.sh
```

## Usage

The skill has two modes: **READ** (capture pane output) and **CONTROL** (execute commands).

### READ Mode - Capture Pane Output

View terminal output from any tmux pane:

```bash
/see-terminal [pane] [lines]
```

**Examples:**
```bash
/see-terminal          # Shows available panes, asks which to capture, uses 50 lines
/see-terminal 0        # Captures pane 0, last 50 lines
/see-terminal 1 100    # Captures pane 1, last 100 lines
```

**Parameters:**
- `pane` (optional): Pane number (0, 1, 2) or position ({left}, {right}, etc.)
  - If omitted, skill will list panes and ask which to capture
- `lines` (optional): Number of lines to capture (default: 50)

### CONTROL Mode - Execute Commands

Execute commands in tmux panes with safety checks:

**Command Execution:**
```bash
# Skill detects user intent and executes commands
# Example user requests:
# "Run npm test in pane 1"
# "Stop the server in pane 0"
# "Install lodash in the right pane"
```

**Safety Levels:**
- **GREEN** (auto-approve): Read-only commands (ls, cat, git status, etc.)
- **YELLOW** (ask first): Side effects (npm install, git commit, etc.)
- **RED** (warn strongly): Destructive operations (rm -rf, sudo, etc.)

## Integration with /tmux-wait

For waiting operations, this skill delegates to `/tmux-wait`:

**Wait for prompt to return:**
```bash
/tmux-wait prompt 0 60
```

**Wait for specific text:**
```bash
/tmux-wait output 0 "Build succeeded" 30
```

**Execute and wait automatically:**
```bash
/tmux-wait command 1 npm test
```

See `/tmux-wait` skill documentation for full details.

## Real-World Examples

### Testing a Claude Skill

```bash
# Step 1: Start Claude
tmux send-keys -t 0 "claude" Enter
/tmux-wait prompt 0 60
/see-terminal 0 80

# Step 2: Execute skill (two-Enter pattern)
tmux send-keys -t 0 "/init-team-ai" Enter
sleep 1
tmux send-keys -t 0 Enter

# Step 3: Monitor execution
/tmux-wait output 0 "Do you want to proceed?" 10
tmux send-keys -t 0 Down Enter  # Approve with option 2

# Step 4: Wait for completion
/tmux-wait output 0 "Team AI Initialization Complete" 60
/see-terminal 0 100  # Verify results

# Step 5: Exit Claude
tmux send-keys -t 0 "/exit" Enter
sleep 1
tmux send-keys -t 0 Enter
```

### Debugging Build Errors

```bash
# Check build output
/see-terminal 1

# If errors found, fix and rebuild
tmux send-keys -t 1 "npm run build" Enter
/tmux-wait prompt 1 120
/see-terminal 1  # Check if build succeeded
```

### Monitoring Multiple Panes

```bash
# Check left pane (server logs)
/see-terminal {left} 100

# Check right pane (test output)
/see-terminal {right} 50
```

## Key Features

### Automatic Mode Detection
- Analyzes user request to determine READ vs CONTROL mode
- "check pane 1" → READ mode
- "run tests in pane 1" → CONTROL mode

### Smart Pane Selection
- If pane not specified, lists available panes and asks user
- Supports pane numbers (0, 1, 2) and positions ({left}, {right})
- Default line count: 50 (optimized for most use cases)

### Safety Protocol
- Auto-approves read-only commands
- Requests approval for commands with side effects
- Warns strongly about destructive operations
- Never skips git hooks or uses force flags without explicit user request

### Claude Slash Command Support
- Special two-Enter pattern for all Claude `/` commands
- Automatic verification that commands executed
- Permission approval navigation with Down arrow
- Full workflow automation support

## Integration with /init-team-ai

The `/init-team-ai` skill creates `.claude/settings.local.json` with pre-approved permissions:
- `Bash(tmux:*)` - All tmux commands
- `Skill(tmux-wait:*)` - All tmux-wait operations

This makes both `/see-terminal` and `/tmux-wait` completely frictionless!

## Technical Details

### Two-Enter Pattern for Claude Slash Commands

**CRITICAL:** All Claude slash commands require TWO separate Enters:

```bash
# First Enter: Trigger autocomplete
tmux send-keys -t 0 "/command" Enter

# Wait for autocomplete to load
sleep 1

# Second Enter: Execute command
tmux send-keys -t 0 Enter
```

**Why:** Claude Code's autocomplete needs time to load before execution.

### Permission Approval Navigation

Use Down arrow to navigate permission menus (not typing numbers):

```bash
# Option 1 (default): Just Enter
tmux send-keys -t 0 Enter

# Option 2: Down once, then Enter
tmux send-keys -t 0 Down Enter

# Option 3: Down twice, then Enter
tmux send-keys -t 0 Down Down Enter
```

## Uninstallation

```bash
cd /home/kiral/ClaudeSkills/see-terminal
./uninstall.sh
```

## See Also

- `/tmux-wait` - Event-driven waiting for tmux panes
- `/init-team-ai` - Sets up pre-approved permissions

## Architecture

This skill is the **primary interface** for all tmux pane operations:
- Reading pane contents
- Executing commands in panes
- Delegates waiting operations to `/tmux-wait`
- Provides high-level, user-friendly tmux automation

The design separates concerns:
- `/see-terminal` - Reading and controlling panes
- `/tmux-wait` - Waiting for completion and monitoring

Together, they provide a complete tmux automation toolkit.
