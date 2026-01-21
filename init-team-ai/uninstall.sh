#!/bin/bash

# Uninstallation script for init-team-ai skill
# This script removes the skill from Claude Code

set -e

SKILL_NAME="init-team-ai"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
SKILL_PATH="$CLAUDE_SKILLS_DIR/$SKILL_NAME"

echo "Uninstalling $SKILL_NAME skill..."

if [ -L "$SKILL_PATH" ] || [ -d "$SKILL_PATH" ]; then
    rm -rf "$SKILL_PATH"
    echo "✓ $SKILL_NAME skill uninstalled successfully!"
else
    echo "⚠ $SKILL_NAME skill is not installed."
    exit 1
fi

echo ""
echo "The skill has been removed from Claude Code."
echo "Note: This does not remove any files created by the skill in your projects."
echo ""
