# WSL Terminal Skill for Claude Code

A Claude Code skill that enables Claude to see and analyze the contents of tmux panes in your WSL terminal.

## Platform Compatibility

**Tested on**: Windows WSL (Windows Subsystem for Linux)
**Likely works on**: Native Linux systems
**Not tested on**: macOS, other Unix-like systems

This skill was developed and tested specifically for Windows WSL environments. While it should work on native Linux systems running tmux, it has not been tested on those platforms. Use on non-WSL systems at your own discretion.

## Overview

This skill provides the `/see-terminal` command, which captures the output from any tmux pane and sends it to Claude for analysis. Perfect for getting Claude's opinion on terminal output, errors, build logs, or any command results.

## Requirements

- tmux must be installed and running
- WSL (Windows Subsystem for Linux) or Linux
- Claude Code

## Installation

### Quick Install (Recommended)

Run the installation script from this directory:

```bash
cd /path/to/WSL_Terminal
./install.sh
```

Replace `/path/to/WSL_Terminal` with the actual path where you cloned or extracted this skill.

The script will:
- Create the Claude Code skills directory if needed (`~/.claude/skills/`)
- Copy the skill files to `~/.claude/skills/wsl-terminal/`
- Verify the installation

### Manual Installation

If you prefer to install manually:

```bash
# Create skills directory if it doesn't exist
mkdir -p ~/.claude/skills/wsl-terminal

# Copy the command file
cp commands/see-terminal.md ~/.claude/skills/wsl-terminal/
```

### Development Mode (Symlink)

For development, you can symlink instead of copying:

```bash
# Create skills directory if it doesn't exist
mkdir -p ~/.claude/skills

# Create symlink to this directory (run from WSL_Terminal directory)
ln -s "$(pwd)" ~/.claude/skills/wsl-terminal
```

This creates a symbolic link so any changes you make to the skill files are immediately reflected without reinstalling.

### Verify Installation

Check that the skill files are in place:

```bash
ls -la ~/.claude/skills/wsl-terminal/
```

You should see `see-terminal.md` in the directory. The `/see-terminal` command will be available in your next Claude Code session.

## Usage

### Basic usage

```bash
/see-terminal           # Capture last 50 lines from pane 0
```

### Specify a pane

```bash
/see-terminal 1         # Capture from pane 1
/see-terminal {right}   # Capture from pane to the right
```

### Get more context

```bash
/see-terminal 0 100     # Capture last 100 lines from pane 0
/see-terminal 1 200     # Capture last 200 lines from pane 1
```

## Workflow

1. Open PowerShell
2. Launch WSL: `wsl`
3. Start tmux: `tmux`
4. Split panes: `Ctrl+b %` (vertical split)
5. Left pane: Run `claude-code`
6. Right pane: Run your commands (build, test, etc.)
7. In Claude Code: `/see-terminal {right}` to see what happened in the right pane
8. Ask Claude: "What does this error mean?" or "Is the build successful?"

## Examples

### Analyze build output
```
# In right pane
npm run build

# In Claude Code pane
/see-terminal {right}
# Claude analyzes the build output and reports status
```

### Debug errors
```
# In right pane
python script.py
# (some error occurs)

# In Claude Code pane
/see-terminal 1
"What's wrong with this error?"
# Claude explains the error and suggests fixes
```

### Review test results
```
# In right pane
pytest

# In Claude Code pane
/see-terminal {right}
"Did all tests pass?"
# Claude summarizes test results
```

## Sharing with Others

### Via Git

1. Commit your ClaudeSkills directory:
   ```bash
   git add .
   git commit -m "Add WSL Terminal skill"
   git push
   ```

2. Others can clone and install:
   ```bash
   git clone https://github.com/kiralpoon/ClaudeSkills
   cd ClaudeSkills/WSL_Terminal
   ./install.sh
   ```

### Via Direct Copy

1. Copy the `WSL_Terminal` directory to another PC
2. Install the skill:
   ```bash
   cd /path/to/WSL_Terminal
   ./install.sh
   ```

## Troubleshooting

**"no server running" error**
- Make sure you're running the command from within a tmux session
- Start tmux: `tmux`

**"can't find pane: X" error**
- List available panes: `tmux list-panes`
- Use a valid pane number (usually 0, 1, 2, etc.)

**Command not found: `/see-terminal`**
- Verify installation: `ls -la ~/.claude/skills/wsl-terminal/`
- Reinstall: `cd /path/to/WSL_Terminal && ./install.sh`
- Restart Claude Code to pick up the new skill

## License

MIT
