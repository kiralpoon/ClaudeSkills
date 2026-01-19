#!/bin/bash

# WSL Terminal Skill Installation Script for Claude Code
# This script installs the /see-terminal command into Claude Code's skills directory

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
SKILLS_DIR="$HOME/.claude/skills/wsl-terminal"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}WSL Terminal Skill Installer${NC}"
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
if [[ ! -f "$SCRIPT_DIR/commands/see-terminal.md" ]]; then
    echo -e "${RED}✗ Error: Command file not found${NC}"
    echo "  Expected: $SCRIPT_DIR/commands/see-terminal.md"
    exit 1
fi

# Check if skill is already installed
if [[ -d "$SKILLS_DIR" ]] && [[ -f "$SKILLS_DIR/see-terminal.md" ]]; then
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

# Copy command file
echo -e "${BLUE}→${NC} Installing /see-terminal command..."
cp "$SCRIPT_DIR/commands/see-terminal.md" "$SKILLS_DIR/"

# Verify installation
if [[ -f "$SKILLS_DIR/see-terminal.md" ]]; then
    echo -e "${GREEN}✓ Installation successful!${NC}"
    echo ""
    echo -e "${GREEN}Installed files:${NC}"
    ls -lh "$SKILLS_DIR/see-terminal.md" | awk '{print "  " $9 " (" $5 ")"}'
    echo ""
    echo -e "${GREEN}Location:${NC}"
    echo "  $SKILLS_DIR"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Start or restart Claude Code"
    echo "  2. Open tmux with: tmux"
    echo "  3. Use the command: /see-terminal"
    echo ""
    echo -e "${BLUE}Usage examples:${NC}"
    echo "  /see-terminal           # Capture pane 0, last 50 lines"
    echo "  /see-terminal 1         # Capture pane 1"
    echo "  /see-terminal 0 100     # Capture 100 lines"
    echo "  /see-terminal {right}   # Capture pane to the right"
    echo ""
else
    echo -e "${RED}✗ Installation failed${NC}"
    echo "  Command file was not copied successfully"
    exit 1
fi
