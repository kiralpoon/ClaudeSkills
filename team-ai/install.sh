#!/bin/bash

# Team AI Skill Installer
# Multi-agent build/review pipeline orchestration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills/team-ai"

echo "Installing team-ai skill..."
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
    echo "The /team-ai skill is now available in Claude Code."
    echo ""
    echo "Usage:"
    echo "  /team-ai \"add input validation\"    — Mode A: build/review pipeline"
    echo "  /team-ai review src/auth.py         — Mode B: multi-perspective review"
    echo ""
    echo "Prerequisites:"
    echo "  1. Run /init-team-ai in your project first"
    echo "  2. Install Codex CLI: https://github.com/openai/codex"
    echo "  3. Install Gemini CLI: https://github.com/google-gemini/gemini-cli"
    echo ""
else
    echo "✗ Installation failed - SKILL.md not found in target directory"
    exit 1
fi
