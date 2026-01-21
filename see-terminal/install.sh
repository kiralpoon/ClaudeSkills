#!/bin/bash

# see-terminal Skill Installer
# Tmux pane capture and control using /tmux-wait for waiting operations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills/see-terminal"

echo "Installing see-terminal skill..."
echo "Source: $SCRIPT_DIR"
echo "Target: $SKILLS_DIR"

# Check if source SKILL.md exists
if [[ ! -f "$SCRIPT_DIR/commands/SKILL.md" ]]; then
    echo "Error: SKILL.md not found at $SCRIPT_DIR/commands/SKILL.md"
    exit 1
fi

# Create skills directory
echo "Creating skills directory..."
mkdir -p "$SKILLS_DIR"

# Copy SKILL.md
echo "Installing skill definition..."
cp "$SCRIPT_DIR/commands/SKILL.md" "$SKILLS_DIR/"

# Verify installation
if [[ -f "$SKILLS_DIR/SKILL.md" ]]; then
    echo ""
    echo "✓ Installation successful!"
    echo ""
    echo "The /see-terminal skill is now available in Claude Code."
    echo ""
    echo "Usage:"
    echo "  /see-terminal                    - List panes and ask which to capture"
    echo "  /see-terminal <pane>             - Capture pane (default 50 lines)"
    echo "  /see-terminal <pane> <lines>     - Capture specific number of lines"
    echo ""
    echo "Examples:"
    echo "  /see-terminal 0                  - Capture pane 0"
    echo "  /see-terminal 1 100              - Capture 100 lines from pane 1"
    echo "  /see-terminal {right}            - Capture right pane"
    echo ""
    echo "This skill uses /tmux-wait for all waiting operations,"
    echo "eliminating permission prompts when used with /init-team-ai."
else
    echo "✗ Installation failed - SKILL.md not found in target directory"
    exit 1
fi
