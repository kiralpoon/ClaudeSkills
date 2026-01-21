# Init Team AI Skill

A Claude Code skill for initializing new projects with team AI collaboration configuration.

## What It Does

This skill sets up a new project directory with all the necessary configuration files for effective team AI collaboration:

1. **Agents.md** - Core agent behavior and ExecPlan usage guidelines (gitignored)
2. **Claude.local.md** - Local preferences file (gitignored)
3. **.claude/settings.local.json** - Local settings with SessionStart hooks and safe command permissions
4. **.agent/PLANS.md** - Detailed ExecPlan authoring guidelines (gitignored)
5. **.gitignore** - Updated to exclude local AI configuration files

## Why Use This?

When working with multiple developers on a project, each person may have different preferences for how Claude Code behaves. This skill creates local configuration files that:

- Stay on each developer's machine (gitignored)
- Allow personal customization without team conflicts
- Provide consistent agent collaboration guidelines via PLANS.md
- Set up safe command permissions by default

## Installation

From this directory, run:

```bash
./install.sh
```

Or manually create a symlink:

```bash
ln -s "$(pwd)" "$HOME/.config/claude/skills/init-team-ai"
```

## Usage

### Initialize Current Directory

In any project directory within Claude Code:

```
/init-team-ai
```

### Initialize Specific Directory

```
/init-team-ai /path/to/your/project
```

## What Gets Created

### 1. Claude.local.md

Personal preferences for Claude Code behavior. Default configuration:
- Disables "Co-Authored-By: Claude" in git commits
- Can be customized per developer

### 2. .claude/settings.local.json

Local Claude Code settings including:

**Permissions:**
- `"Bash"` - Allows all bash commands (required for complex skills like tmux-wait)
- Individual command permissions for documentation: `ls`, `cat`, `pwd`, `echo`
- Git commands: `git status`, `git log`, `git diff`, `git branch`
- Information commands: `which`, `whereis`, `date`, `whoami`
- Search commands: `grep`, `find`
- Tmux commands: `tmux` (for terminal control skills)

**Why `"Bash"` permission?**

Skills like `tmux-wait` and `see-terminal` use complex bash scripts with loops, variables, and multiple commands. Claude Code's permission system uses prefix matching (e.g., `"Bash(tmux:*)"` only matches commands starting with "tmux"). For compound bash scripts to execute without prompts, the general `"Bash"` permission is required.

**SessionStart Hooks:**
- Displays Claude.local.md content at session start
- Notifies about .agent/PLANS.md availability

### 3. .agent/PLANS.md

Comprehensive guidelines for creating execution plans (ExecPlans) that agents can follow. This file teaches agents how to:
- Create self-contained, novice-friendly execution plans
- Structure milestones and track progress
- Document decisions and discoveries
- Ensure plans are reproducible

### 4. .gitignore

Automatically updated to ignore:
- `.claude/` directory
- `*.local.json` files
- `Claude.local.md`
- `.agent/` directory

## Customization

After initialization, you can customize any of the created files:

### Add More Permissions

Edit `.claude/settings.local.json` and add to the `permissions.allow` array:

```json
{
  "permissions": {
    "allow": [
      "Bash(npm install:*)",
      "Bash(npm test:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)"
    ]
  }
}
```

### Modify Local Preferences

Edit `Claude.local.md` to add your workflow preferences:

```markdown
## My Preferences

- Always run tests before committing
- Use conventional commit messages
- Prefer TypeScript over JavaScript
```

### Customize Agent Guidelines

While `.agent/PLANS.md` provides comprehensive guidelines, you can add project-specific notes at the top of the file.

## Example Workflow

1. Create a new project:
   ```bash
   mkdir my-new-project
   cd my-new-project
   git init
   ```

2. Initialize Claude Code:
   ```bash
   claude
   ```

3. Run the skill:
   ```
   /init-team-ai
   ```

4. Customize your local preferences:
   ```bash
   # Edit Claude.local.md, .claude/settings.local.json as needed
   ```

5. Start a new Claude session to load the configuration:
   ```bash
   exit
   claude
   ```

6. Your local preferences are loaded automatically!

## Team Collaboration

Each team member can:
- Run `/init-team-ai` in their local clone
- Customize their own `Claude.local.md` preferences
- Share the `.agent/PLANS.md` guidelines (if desired, by removing it from .gitignore)
- Work with consistent agent collaboration patterns

The key insight: **Local files stay local, guidelines can be shared.**

## Files Not Committed

These files are automatically gitignored:
- `Claude.local.md` - Personal preferences
- `.claude/` - Local Claude Code settings
- `.agent/` - Agent collaboration guidelines (optional)
- `*.local.json` - Any local JSON configuration

## Features

✓ **No Configuration Conflicts** - Each developer has their own preferences
✓ **Safe Defaults** - Read-only commands approved by default
✓ **Agent-Ready** - PLANS.md guides effective agent collaboration
✓ **Quick Setup** - One command initializes everything (3-5 seconds)
✓ **Customizable** - Easy to modify for your workflow
✓ **Gitignored** - Won't accidentally commit local preferences
✓ **Idempotent** - Safe to run multiple times, preserves your customizations
✓ **Smart Merging** - Automatically adds SessionStart hooks to existing settings.local.json without manual editing

## Technical Details

- **No external dependencies** - Uses Python 3 (built-in on most systems) for JSON merging
- **Automatic hook merging** - If settings.local.json exists without SessionStart hooks, they're automatically added
- **Preserves existing settings** - Your custom permissions and configurations are never overwritten
- **Fast execution** - Completes in 3-5 seconds using efficient Write tool for file creation

## License

MIT License - See LICENSE file in the repository root.

## Contributing

To improve this skill:

1. Fork the repository
2. Make your changes in the `init-team-ai/` directory
3. Test the skill in a new project
4. Submit a pull request

## Testing

For developers testing or improving this skill, see **[TESTING-GUIDE.md](./TESTING-GUIDE.md)** for:

- Efficient monitoring patterns using `/see-terminal` skill
- How to approve Claude permission prompts programmatically
- Testing workflow best practices
- Verification checklist for created files

**Key Testing Lessons:**
- ✅ Use `/see-terminal 0 100` instead of manual `sleep` commands
- ✅ Use `tmux send-keys -t 0 Down Enter` to select option 2 (not typing "2")
- ✅ Press Enter TWICE when executing skills (`/init-team-ai` then `Enter`)

## Support

For issues or questions:
- Open an issue in the ClaudeSkills repository
- Check existing issues for solutions
- Refer to Claude Code documentation

## Version History

- **1.0.1** (2026-01-21) - Permission system improvements
  - Added `"Bash"` permission to templates for complex skill support
  - Updated documentation about permission matching in Claude Code
  - Enabled tmux-wait and other compound bash script skills without prompts
  - Fixed prompt detection for Claude Code's "? for shortcuts" display

- **1.0.0** (2026-01-20) - Initial release
  - Claude.local.md creation with local preferences
  - settings.local.json with SessionStart hooks and safe permissions
  - .agent/PLANS.md with comprehensive agent collaboration guidelines
  - Automatic .gitignore updates
  - Idempotent design - safe to run multiple times
  - Automatic SessionStart hooks merging using Python (no jq required)
  - Performance optimized - completes in 3-5 seconds
