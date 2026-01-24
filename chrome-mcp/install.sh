#!/bin/bash

# chrome-mcp Skill Installer
# Setup and launch Chrome DevTools MCP for browser automation in WSL

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills/chrome-mcp"

echo "Installing chrome-mcp skill..."
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
    echo "Installation successful!"
    echo ""
    echo "The /chrome-mcp skill is now available in Claude Code."
    echo ""
    echo "Usage:"
    echo "  /chrome-mcp              - Start Chrome with default port 9222"
    echo "  /chrome-mcp <port>       - Start Chrome with custom port"
    echo ""
    echo "Examples:"
    echo "  /chrome-mcp              - Use default debugging port"
    echo "  /chrome-mcp 9223         - Use port 9223"
    echo ""
    echo "What this skill does:"
    echo "  1. Installs Chrome DevTools MCP if not present"
    echo "  2. Finds Chrome on your Windows system"
    echo "  3. Splits the tmux pane (Chrome on top, Claude below)"
    echo "  4. Starts Chrome with remote debugging enabled"
    echo "  5. Verifies the connection is ready"
    echo ""
    echo "After running /chrome-mcp, you can ask Claude to:"
    echo "  - 'Go to google.com and take a screenshot'"
    echo "  - 'Navigate to example.com and click the first link'"
    echo "  - 'Fill out the search form and submit'"
else
    echo "Installation failed - SKILL.md not found in target directory"
    exit 1
fi
