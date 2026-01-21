# See Terminal Skill for Claude Code

A Claude Code skill that enables Claude to capture, analyze, and control tmux panes in your terminal.

## Platform Compatibility

**Tested on**: Windows WSL (Windows Subsystem for Linux)
**Likely works on**: Native Linux systems
**Not tested on**: macOS, other Unix-like systems

This skill was developed and tested specifically for Windows WSL environments. While it should work on native Linux systems running tmux, it has not been tested on those platforms. Use on non-WSL systems at your own discretion.

## Overview

This skill enables Claude to capture, analyze, and control tmux pane contents on demand. When you ask Claude to check your terminal output or analyze errors, Claude can use this skill to fetch the contents from any tmux pane and provide insights. Claude can also execute commands in panes to fix errors, run builds, or perform other tasks. Perfect for debugging, reviewing build output, understanding error messages, and automating terminal workflows.

## 🚨 CRITICAL: No Sleep Commands

**NEVER use `sleep` commands before or after invoking this skill.**

The skill is designed to capture pane state immediately and efficiently. Adding sleep delays:
- Defeats the purpose of using the skill
- Adds unnecessary wait time
- Violates the intended usage pattern

**❌ WRONG - Adding sleep before skill:**
```bash
tmux send-keys -t 0 "claude" Enter
sleep 2                              # NEVER DO THIS!
# Then invoke /see-terminal 0 50
```

**✅ CORRECT - Invoke skill immediately:**
```bash
tmux send-keys -t 0 "claude" Enter
# Immediately invoke /see-terminal 0 50 (no sleep needed)
```

**If you need to wait for a command to complete:**
- Call `/see-terminal` multiple times in sequence
- The skill will show current pane state each time
- No sleep delays are ever necessary

**Key Patterns for Automation:**
- Monitoring: Always use `/see-terminal` (never `sleep` + `tmux capture-pane`)
- Permission approval: `tmux send-keys -t 0 Down Enter` (not typing "2")
- Slash commands: Press Enter **twice** with 1 second delay (`/command` Enter, sleep 1, Enter)

## Control Capabilities

Beyond just viewing terminal output, this skill now allows Claude to:

- **Execute commands** in any tmux pane
- **Fix errors automatically** by running the appropriate commands
- **Interrupt processes** with Ctrl+C and other signals
- **Restart failed builds** or tests
- **Install dependencies** when missing modules are detected

### Safety Features

Claude will classify all commands by risk level:

- **GREEN (Auto-approve)**: Read-only commands like `ls`, `cat`, `git status` - executed immediately
- **YELLOW (Request approval)**: Commands with side effects like `npm install`, `git commit` - asks first
- **RED (Extra warning)**: Destructive operations like `rm -rf`, `sudo` - requires explicit confirmation

All commands are automatically verified after execution, with Claude capturing the pane output to confirm success or identify errors.

### Smart Completion Detection

Commands complete detection uses intelligent prompt polling instead of fixed delays:

- **Quick commands**: Detected in 0.2-0.5 seconds (4-15x faster than fixed waits)
- **Long commands**: Waits for actual completion, not arbitrary timeouts
- **Early failures**: Detects errors immediately when prompt returns
- **Efficient**: Polls every 0.2s checking for shell prompt ($, #, %)

This ensures fast feedback for simple commands while reliably waiting for long-running operations to complete.

## Requirements

- tmux must be installed and running
- WSL (Windows Subsystem for Linux) or Linux
- Claude Code

## Installation

### Quick Install (Recommended)

Run the installation script from this directory:

```bash
cd /path/to/see_terminal
./install.sh
```

Replace `/path/to/see_terminal` with the actual path where you cloned or extracted this skill.

The script will:
- Create the Claude Code skills directory if needed (`~/.claude/skills/`)
- Copy the skill files to `~/.claude/skills/see-terminal/`
- Verify the installation

### Manual Installation

If you prefer to install manually:

```bash
# Create skills directory if it doesn't exist
mkdir -p ~/.claude/skills/see-terminal

# Copy the skill file
cp commands/SKILL.md ~/.claude/skills/see-terminal/
```

### Development Mode (Symlink)

For development, you can symlink instead of copying:

```bash
# Create skills directory if it doesn't exist
mkdir -p ~/.claude/skills

# Create symlink to this directory (run from see_terminal directory)
ln -s "$(pwd)" ~/.claude/skills/see-terminal
```

This creates a symbolic link so any changes you make to the skill files are immediately reflected without reinstalling.

### Verify Installation

Check that the skill files are in place:

```bash
ls -la ~/.claude/skills/see-terminal/
```

You should see `SKILL.md` in the directory. The skill will be available in your next Claude Code session.

## Usage

The skill is automatically invoked by Claude when you ask about terminal content or request command execution. You can interact with your terminal in natural language or use the direct `/see-terminal` command.

### Direct Invocation (Optional)

You can invoke the skill directly with optional parameters:

```
/see-terminal                    # Shows available panes, asks which to capture, uses 50 lines
/see-terminal 0                  # Captures pane 0, last 50 lines
/see-terminal 1 100              # Captures pane 1, last 100 lines
/see-terminal {right} 200        # Captures right pane, last 200 lines
```

**Parameters:**
- **pane-target** (optional): Pane number (0, 1, 2...) or position ({left}, {right}, etc.)
  - If omitted, Claude will show available panes and ask you to select one
- **lines** (optional): Number of lines to capture (default: 50)
  - Recommended to keep under 1000 for performance

### View terminal output (READ mode)

```
"Check my terminal for errors"
"What's in pane 1?"
"Show me the output from the right pane"
"Capture the last 100 lines from pane 0"
"Did the build in the right pane succeed?"
```

### Execute commands (CONTROL mode)

```
"Run ls in pane 1"
"Install lodash in the right pane"
"Restart the build in pane 0"
"Stop the server in pane 1"
"Send Ctrl+C to the right pane"
```

### Multi-step takeover workflows

```
"Takeover pane 0, run claude, test /init-team-ai, approve all permissions"
"See terminal 0, clear the pane, start the dev server, monitor until ready"
"Control pane 1, kill the process, install dependencies, restart the build"
```

Claude will:
1. Execute each command step-by-step
2. **Use `/see-terminal` for ALL monitoring** (not manual sleep)
3. Auto-approve permissions when you say "approve all permissions"
4. Report progress and final results

See "Multi-Step Takeover Example" below for detailed workflow.

### Fix errors automatically

```
# Claude detects missing dependency
"Check the terminal"
> Claude: "Error: Module 'express' not found"

"Fix it"
> Claude: "I'll run 'npm install express' in pane 0. Proceed?"
> You: "yes"
> Claude executes, verifies, and reports success
```

### How it works

**READ mode** - When you request terminal analysis:
1. Capture the specified tmux pane content (default: pane 0, last 50 lines)
2. Analyze the output
3. Provide insights, explanations, or suggestions

**CONTROL mode** - When you request command execution:
1. Classify the command by risk level (GREEN/YELLOW/RED)
2. Request approval if needed (YELLOW/RED commands)
3. Execute the command in the specified pane
4. Poll every 0.2s for prompt return (detects completion instantly)
5. Capture pane output to verify results
6. Report success or errors to you

**Multi-Step CONTROL mode** - When you request complex takeover workflows:
1. Break down the request into individual steps
2. Execute each step sequentially (clear, start claude, run skill, etc.)
3. **Use `/see-terminal` for monitoring between steps** (not manual sleep)
4. Auto-approve permissions when instructed (using `Down Enter` navigation)
5. Continue monitoring until all steps complete
6. Verify final results and report comprehensive status

## Workflow

1. Open PowerShell
2. Launch WSL: `wsl`
3. Start tmux: `tmux`
4. Split panes: `Ctrl+b %` (vertical split)
5. Left pane: Run `claude`
6. Right pane: Run your commands (build, test, etc.)
7. In Claude Code, ask naturally:
   - "What happened in the right pane?"
   - "Check the terminal for errors"
   - "Is the build successful?"

## Examples

### Analyze build output (READ mode)
```
# In right pane
npm run build

# In Claude Code, ask:
"Check the right pane - did the build succeed?"

# Claude captures the output and analyzes it
```

### Debug errors (READ mode)
```
# In right pane
python script.py
# (some error occurs)

# In Claude Code, ask:
"What's the error in pane 1?"

# Claude captures, reads, and explains the error
```

### Review test results (READ mode)
```
# In right pane
pytest

# In Claude Code, ask:
"Did all tests pass in the right pane?"

# Claude reviews and summarizes the test results
```

### Fix missing dependencies (CONTROL mode)
```
# Claude detects error in pane 1
"Check pane 1"
> Claude: "Error: Cannot find module 'lodash'"

# Ask Claude to fix it
"Fix it"
> Claude: "I'll run 'npm install lodash' in pane 1. This will install the package. Proceed?"
> You: "yes"
> Claude executes, waits, captures output
> Claude: "lodash@4.17.21 installed successfully. Error resolved."
```

### Restart failed builds (CONTROL mode)
```
# Build failed in right pane
"The build failed. Run it again in the right pane"
> Claude: "I'll run 'npm run build' in the right pane. Proceed?"
> You: "yes"
> Claude executes and monitors
> Claude: "Build completed successfully. No errors."
```

### Interrupt processes (CONTROL mode)
```
# Server is running in pane 0, need to stop it
"Stop the server in pane 0"
> Claude classifies as interrupt signal (special case)
> User intent is clear, executes immediately
> Claude: "Sent interrupt signal (Ctrl+C) to pane 0. Server stopped."
```

### Run tests after fixes (CONTROL mode)
```
# After fixing code
"Run npm test in the bottom pane"
> Claude: "I'll run 'npm test' in the bottom pane. Proceed?"
> You: "yes"
> Claude executes and analyzes results
> Claude: "All 47 tests passed. No failures."
```

### Multi-step takeover (CONTROL mode)
```
"Takeover pane 0, start claude, test /init-team-ai, approve all permissions"

> Claude executes step by step:
> - Clears pane, starts claude
> - Monitors with /see-terminal (not sleep)
> - Executes slash command with Enter, sleep 1, Enter (twice with delay!)
> - Approves permissions with Down Enter (not "2")
> - Continues monitoring until complete
> - Reports: "init-team-ai completed in 43s. All files created."
```

## Safety Information

### Command Classification

All commands are automatically classified into three safety levels:

**GREEN (Auto-approve)** - Read-only, no side effects:
- File viewing: `ls`, `cat`, `head`, `tail`, `grep`
- Navigation: `pwd`, `cd`, `which`
- Information: `echo`, `date`, `whoami`
- Git read-only: `git status`, `git log`, `git diff`

These commands execute immediately without asking for permission.

**YELLOW (Request approval)** - Side effects but generally safe:
- Package management: `npm install`, `pip install`, `cargo build`
- Build/test: `make`, `npm run build`, `npm test`, `pytest`
- Git write: `git add`, `git commit`, `git push`
- File operations: `cp`, `mv`, `mkdir`

Claude will explain what these commands do and wait for your approval before executing.

**RED (Extra warning)** - Destructive or high-risk:
- Destructive deletions: `rm -rf`, `dd`
- System changes: `sudo` commands, `chmod 777`
- Force flags: `--force`, `--hard`, `--production`
- Remote execution: `curl | bash`, `wget | sh`

Claude will show a strong warning, explain irreversible consequences, and require explicit confirmation.

### Safety Guarantees

1. **No command executes without proper authorization**
   - GREEN commands are safe by definition (read-only)
   - YELLOW/RED commands require your explicit approval

2. **All commands are echoed before execution**
   - You always know exactly what will run
   - Command, pane target, and effect are clearly stated

3. **Automatic result verification**
   - Claude captures pane output after every command
   - Success/failure is detected and reported
   - Errors are identified and explained

4. **Clear command visibility**
   - Commands appear in your terminal as if you typed them
   - You can see the execution in real-time
   - Terminal history is preserved

## Sharing with Others

### Via Git

1. Commit your ClaudeSkills directory:
   ```bash
   git add .
   git commit -m "Add See Terminal skill"
   git push
   ```

2. Others can clone and install:
   ```bash
   git clone https://github.com/kiralpoon/ClaudeSkills
   cd ClaudeSkills/see_terminal
   ./install.sh
   ```

### Via Direct Copy

1. Copy the `see_terminal` directory to another PC
2. Install the skill:
   ```bash
   cd /path/to/see_terminal
   ./install.sh
   ```

## Troubleshooting

**"no server running" error**
- Make sure you're running the command from within a tmux session
- Start tmux: `tmux`

**"can't find pane: X" error**
- List available panes: `tmux list-panes`
- Use a valid pane number (usually 0, 1, 2, etc.)

**Skill not working**
- Verify installation: `ls -la ~/.claude/skills/see-terminal/`
- Check that `SKILL.md` exists (not `see-terminal.md`)
- Reinstall: `cd /path/to/see_terminal && ./install.sh`
- Restart Claude Code to load the skill

## License

MIT
