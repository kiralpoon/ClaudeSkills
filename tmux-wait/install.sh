#!/bin/bash

# Tmux Smart Wait Skill Installer
# Uses tmux wait-for for event-driven command completion monitoring

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills/tmux-wait"

echo "Installing tmux-wait skill..."
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
    echo "The /tmux-wait skill is now available in Claude Code."
    echo ""
    echo "Usage:"
    echo "  /tmux-wait command <pane> <command>         - Execute and wait"
    echo "  /tmux-wait prompt <pane> [timeout]          - Wait for prompt"
    echo "  /tmux-wait output <pane> <text> [timeout]   - Wait for text"
    echo ""
    echo "Examples:"
    echo "  /tmux-wait command 0 npm test"
    echo "  /tmux-wait prompt 0 60"
    echo "  /tmux-wait output 0 'Build succeeded'"
    echo ""
    echo "This skill uses tmux wait-for for event-driven waiting,"
    echo "eliminating permission prompts when used with /init-team-ai."
else
    echo "✗ Installation failed - SKILL.md not found in target directory"
    exit 1
fi
