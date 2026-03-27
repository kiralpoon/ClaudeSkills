#!/bin/bash

# Team AI Skill Uninstaller

set -e

SKILLS_DIR="$HOME/.claude/skills/team-ai"

echo "Uninstalling team-ai skill..."
echo "Target: $SKILLS_DIR"

# Check if skill is installed
if [[ ! -d "$SKILLS_DIR" ]]; then
    echo "✓ Skill is not installed (directory not found)"
    exit 0
fi

# Remove the skill directory
echo "Removing skill directory..."
rm -rf "$SKILLS_DIR"

# Verify removal
if [[ ! -d "$SKILLS_DIR" ]]; then
    echo ""
    echo "✓ Uninstallation successful!"
    echo ""
    echo "The /team-ai skill has been removed from Claude Code."
else
    echo "✗ Uninstallation failed - directory still exists"
    exit 1
fi
