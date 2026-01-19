# See Terminal Skill for Claude Code

A Claude Code skill that enables Claude to see and analyze the contents of tmux panes in your terminal.

## Platform Compatibility

**Tested on**: Windows WSL (Windows Subsystem for Linux)
**Likely works on**: Native Linux systems
**Not tested on**: macOS, other Unix-like systems

This skill was developed and tested specifically for Windows WSL environments. While it should work on native Linux systems running tmux, it has not been tested on those platforms. Use on non-WSL systems at your own discretion.

## Overview

This skill enables Claude to capture and analyze tmux pane contents on demand. When you ask Claude to check your terminal output or analyze errors, Claude can use this skill to fetch the contents from any tmux pane and provide insights. Perfect for debugging, reviewing build output, or understanding error messages.

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

The skill is automatically invoked by Claude when you ask about terminal content. You can request terminal analysis in natural language:

### Basic requests

```
"Check my terminal for errors"
"What's in pane 1?"
"Show me the output from the right pane"
```

### Specify details

```
"Capture the last 100 lines from pane 0"
"What does the error in pane 1 mean?"
"Did the build in the right pane succeed?"
```

### How it works

When you make a request, Claude uses the skill behind the scenes to:
1. Capture the specified tmux pane content (default: pane 0, last 50 lines)
2. Analyze the output
3. Provide insights, explanations, or suggestions

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

### Analyze build output
```
# In right pane
npm run build

# In Claude Code, ask:
"Check the right pane - did the build succeed?"

# Claude captures the output and analyzes it
```

### Debug errors
```
# In right pane
python script.py
# (some error occurs)

# In Claude Code, ask:
"What's the error in pane 1?"

# Claude captures, reads, and explains the error
```

### Review test results
```
# In right pane
pytest

# In Claude Code, ask:
"Did all tests pass in the right pane?"

# Claude reviews and summarizes the test results
```

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
