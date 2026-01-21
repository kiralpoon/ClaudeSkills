#!/bin/bash

# Installation script for init-team-ai skill
# This script installs the skill into Claude Code

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Target directory for Claude Code skills (CRITICAL: must be ~/.claude/skills/)
SKILLS_DIR="$HOME/.claude/skills/init-team-ai"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Init Team AI Skill Installer${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

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
echo -e "${BLUE}→${NC} Installing init-team-ai skill..."
cp "$SCRIPT_DIR/commands/SKILL.md" "$SKILLS_DIR/"

# Copy templates directory
echo -e "${BLUE}→${NC} Installing templates..."
cp -r "$SCRIPT_DIR/templates" "$SKILLS_DIR/"

# Verify installation
if [[ -f "$SKILLS_DIR/SKILL.md" ]] && [[ -d "$SKILLS_DIR/templates" ]]; then
    echo -e "${GREEN}✓ Installation successful!${NC}"
    echo ""
    echo -e "${GREEN}Installed files:${NC}"
    echo "  SKILL.md"
    echo "  templates/"
    echo "    ├── Agents.md"
    echo "    ├── Claude.local.md"
    echo "    ├── PLANS.md"
    echo "    └── settings.local.json"
    echo ""
    echo -e "${GREEN}Location:${NC}"
    echo "  $SKILLS_DIR"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Start or restart Claude Code with: claude"
    echo "  2. Use the skill to initialize a project"
    echo ""
    echo -e "${BLUE}Usage examples:${NC}"
    echo "  /init-team-ai              - Initialize current directory"
    echo "  /init-team-ai /path/to/dir - Initialize specific directory"
    echo ""
    echo -e "${BLUE}This will create:${NC}"
    echo "  - Agents.md (core agent behavior & ExecPlan usage)"
    echo "  - Claude.local.md (local preferences)"
    echo "  - .claude/settings.local.json (hooks & permissions)"
    echo "  - .agent/PLANS.md (detailed ExecPlan guidelines)"
    echo "  - .gitignore (updated with local files)"
    echo ""
else
    echo -e "${RED}✗ Installation failed${NC}"
    echo "  Skill file was not copied successfully"
    exit 1
fi
