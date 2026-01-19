#!/bin/bash

# See Terminal Skill Installation Script for Claude Code
# This script installs the see-terminal skill into Claude Code's skills directory

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Target directory for Claude Code skills
SKILLS_DIR="$HOME/.claude/skills/see-terminal"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}See Terminal Skill Installer${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    echo -e "${YELLOW}⚠ Warning: tmux is not installed${NC}"
    echo "  This skill requires tmux to function."
    echo ""
    echo "  Install tmux with:"
    echo "    Ubuntu/Debian: sudo apt-get install tmux"
    echo "    Fedora/RHEL:   sudo dnf install tmux"
    echo "    Arch Linux:    sudo pacman -S tmux"
    echo "    macOS:         brew install tmux"
    echo ""
fi

# Check if source files exist
if [[ ! -f "$SCRIPT_DIR/commands/SKILL.md" ]]; then
    echo -e "${RED}✗ Error: Skill file not found${NC}"
    echo "  Expected: $SCRIPT_DIR/commands/SKILL.md"
    exit 1
fi

# Check if skill is already installed
if [[ -d "$SKILLS_DIR" ]] && [[ -f "$SKILLS_DIR/SKILL.md" ]]; then
    echo -e "${YELLOW}⚠ Existing installation found${NC}"
    echo "  Location: $SKILLS_DIR"
    echo ""
    read -p "Overwrite existing installation? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Installation cancelled${NC}"
        exit 0
    fi
    echo ""
fi

# Create skills directory if it doesn't exist
echo -e "${BLUE}→${NC} Creating skills directory..."
mkdir -p "$SKILLS_DIR"

# Copy skill file
echo -e "${BLUE}→${NC} Installing see-terminal skill..."
cp "$SCRIPT_DIR/commands/SKILL.md" "$SKILLS_DIR/"

# Verify installation
if [[ -f "$SKILLS_DIR/SKILL.md" ]]; then
    echo -e "${GREEN}✓ Installation successful!${NC}"
    echo ""
    echo -e "${GREEN}Installed files:${NC}"
    ls -lh "$SKILLS_DIR/SKILL.md" | awk '{print "  " $9 " (" $5 ")"}'
    echo ""
    echo -e "${GREEN}Location:${NC}"
    echo "  $SKILLS_DIR"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Start or restart Claude Code with: claude"
    echo "  2. Open tmux with: tmux"
    echo "  3. Ask Claude to check your terminal"
    echo ""
    echo -e "${BLUE}Usage examples:${NC}"
    echo '  "Check my terminal for errors"'
    echo '  "What'"'"'s in pane 1?"'
    echo '  "Show me the last 100 lines from the right pane"'
    echo ""
else
    echo -e "${RED}✗ Installation failed${NC}"
    echo "  Command file was not copied successfully"
    exit 1
fi
