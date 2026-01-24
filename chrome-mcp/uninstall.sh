#!/bin/bash

# chrome-mcp Skill Uninstaller

set -e

SKILLS_DIR="$HOME/.claude/skills/chrome-mcp"

echo "Uninstalling chrome-mcp skill..."
echo "Target: $SKILLS_DIR"

# Check if skill is installed
if [[ ! -d "$SKILLS_DIR" ]]; then
    echo "Skill is not installed (directory not found)"
    exit 0
fi

# Remove the skill directory
echo "Removing skill directory..."
rm -rf "$SKILLS_DIR"

# Verify removal
if [[ ! -d "$SKILLS_DIR" ]]; then
    echo ""
    echo "Uninstallation successful!"
    echo ""
    echo "The /chrome-mcp skill has been removed from Claude Code."
    echo ""
    echo "Note: This does not remove the Chrome DevTools MCP configuration."
    echo "To remove the MCP, run: claude mcp remove chrome-devtools"
else
    echo "Uninstallation failed - directory still exists"
    exit 1
fi
