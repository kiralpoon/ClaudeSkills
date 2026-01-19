#!/bin/bash

# WSL Terminal Skill Uninstallation Script for Claude Code
# This script removes the /see-terminal command from Claude Code's skills directory

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Target directory for Claude Code skills
SKILLS_DIR="$HOME/.claude/skills/wsl-terminal"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}WSL Terminal Skill Uninstaller${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Safety check: Ensure SKILLS_DIR is a valid, safe path
if [[ "$SKILLS_DIR" == "/" ]] || [[ "$SKILLS_DIR" == "$HOME" ]] || [[ -z "$SKILLS_DIR" ]]; then
    echo -e "${RED}✗ Error: Invalid or unsafe target directory${NC}"
    echo "  SKILLS_DIR: $SKILLS_DIR"
    exit 1
fi

# Check if skill is installed
if [[ ! -d "$SKILLS_DIR" ]]; then
    echo -e "${YELLOW}⚠ Skill is not installed${NC}"
    echo "  Directory not found: $SKILLS_DIR"
    exit 0
fi

# Show what will be deleted
echo -e "${YELLOW}This will remove: $SKILLS_DIR${NC}"
echo ""
echo "Files to be deleted:"
ls -lah "$SKILLS_DIR" 2>/dev/null || echo "  (unable to list directory)"
echo ""

# Confirmation prompt
read -p "Are you sure you want to uninstall? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Uninstallation cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}→${NC} Removing skill directory..."
rm -rf "$SKILLS_DIR"

# Verify removal
if [[ ! -d "$SKILLS_DIR" ]]; then
    echo -e "${GREEN}✓ Uninstallation successful!${NC}"
    echo ""
    echo -e "${GREEN}The /see-terminal command has been removed.${NC}"
    echo "  Restart Claude Code to complete the removal."
    echo ""
else
    echo -e "${RED}✗ Uninstallation failed${NC}"
    echo "  Directory still exists: $SKILLS_DIR"
    exit 1
fi
