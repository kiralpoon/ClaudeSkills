# Local Claude Code Preferences

This file contains personal preferences for Claude Code that are specific to this repository and should not be committed to version control.

## Git Commit Preferences

**DO NOT include "Co-Authored-By: Claude" credit in commit messages.**

When creating commits:
- Write clear, descriptive commit messages
- Do NOT append any co-author lines
- Keep commits focused and concise
- Follow the existing commit message style in the repository

## Agent Workflow

Always read and follow the guidelines in:
- `Agents.md` (root of project) - Core agent behavior and ExecPlan usage
- `.agent/PLANS.md` - Detailed ExecPlan authoring guidelines

## Pre-Approved Commands

The `.claude/settings.local.json` file includes pre-approved permissions for safe, read-only commands and essential tmux operations:

**File operations**: ls, cat, pwd, cd, find, head, tail
**Git operations**: git status, git log, git diff, git show, git branch
**System info**: which, whereis, date, whoami, hostname, ps
**Text processing**: echo, grep, sed
**Tmux operations**: tmux (for see-terminal skill)
**Utilities**: sleep (for polling/monitoring)

These permissions enable smooth operation of skills like `/see-terminal` without repeatedly asking for approval.

## Usage

Claude Code should read this file at the start of each session to understand local preferences and workflow requirements.
