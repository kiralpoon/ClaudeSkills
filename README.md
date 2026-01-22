# ClaudeSkills

A collection of custom skills for Claude Code that extend its capabilities with specialized commands and workflows.

## About

This repository contains skills for [Claude Code](https://claude.ai/download), Anthropic's official CLI tool. Skills extend Claude's capabilities by providing specialized workflows that Claude automatically invokes when relevant to your task.

**Platform**: Primarily developed for Windows WSL (Windows Subsystem for Linux), but most skills should work on native Linux systems as well.

## Available Skills

### 🖥️ [See Terminal](./see-terminal/)

**Skill**: `see-terminal`

Enables Claude to capture, analyze, and control tmux pane contents directly. Perfect for debugging, reviewing build output, fixing errors automatically, and getting Claude's insights on terminal activity.

**Key Features**:
- Capture output from any tmux pane
- **Efficient monitoring**: Use `/see-terminal` for ALL pane monitoring (no manual sleep commands)
- Execute commands with safety classification (auto-approve safe, request approval for risky)
- Smart completion detection (0.2-0.5s for quick commands, waits for long ones)
- Multi-step takeover workflows with continuous monitoring
- Flexible pane targeting (by number or relative position)
- Adjustable history depth (default 50 lines)
- Automatic error detection and early failure detection

**Use Cases**:
- Ask Claude to check your terminal output for errors
- Request analysis of build or test results from another pane
- Get explanations of error messages visible in your terminal
- Have Claude fix errors by executing commands (with approval for risky operations)
- Restart failed builds or tests automatically
- Interrupt running processes with keyboard signals

[📖 Full Documentation →](./see-terminal/README.md)

### ⏱️ [Tmux Wait](./tmux-wait/)

**Skill**: `tmux-wait`

Event-driven waiting for tmux pane commands using `tmux wait-for`, eliminating the need for polling loops. Works seamlessly with `/see-terminal` for complete tmux automation.

**Key Features**:
- Event-driven command completion using `tmux wait-for` (zero CPU, instant detection)
- Smart prompt detection for shell and Claude Code prompts (~0.2s detection)
- Wait for specific text to appear in pane output
- Pre-approved permissions when using `/init-team-ai`
- Three modes: command execution, prompt waiting, and output monitoring

**Use Cases**:
- Wait for commands to complete without fixed delays
- Monitor for permission prompts during skill execution
- Detect Claude Code startup and readiness
- Wait for build/test completion
- Automated workflow synchronization

[📖 Full Documentation →](./tmux-wait/README.md)

### 🚀 [Init Team AI](./init-team-ai/)

**Skill**: `init-team-ai`

Quickly initialize new projects with team AI collaboration configuration. Creates local configuration files that stay on each developer's machine (gitignored) while providing consistent agent collaboration guidelines.

**Key Features**:
- One-command setup for team AI projects
- Creates Claude.local.md with personal preferences (gitignored)
- Sets up .claude/settings.local.json with SessionStart hooks
- Includes safe command permissions by default
- Creates .agent/PLANS.md with agent collaboration guidelines
- Automatically updates .gitignore to exclude local files

**What Gets Created**:
- `Claude.local.md` - Personal preferences for Claude Code behavior
- `.claude/settings.local.json` - Local settings with hooks and safe permissions
- `.agent/PLANS.md` - Comprehensive agent collaboration guidelines
- `.gitignore` - Updated to exclude local AI configuration files

**Use Cases**:
- Starting a new project with team AI support
- Setting up consistent agent behavior across team members
- Ensuring local preferences don't cause team conflicts
- Providing guidelines for execution plan creation

[📖 Full Documentation →](./init-team-ai/README.md)

## Quick Start

### Prerequisites

- [Claude Code](https://claude.ai/download) installed
- Git for cloning this repository
- WSL or Linux environment (for most skills)

### Recommended Installation (via Claude)

**Why this method?** Installing skills via Claude ensures proper permission handling. The skills use complex bash scripts that require pre-approved permissions - letting Claude install them avoids repeated permission prompts during usage.

1. **Clone the repository**:
   ```bash
   git clone https://github.com/kiralpoon/ClaudeSkills.git
   ```

2. **Start Claude Code**:
   ```bash
   claude
   ```

3. **Ask Claude to install the skills**:
   ```
   Install all skills from ~/Projects/ClaudeSkills (or wherever you cloned it)
   ```

   Claude will run each `install.sh` script and handle any permission prompts.

4. **Initialize your project with proper permissions**:
   ```
   /init-team-ai
   ```

   This creates `.claude/settings.local.json` with pre-approved permissions for the tmux skills, eliminating permission prompts during normal usage.

### Alternative: Manual Installation

If you prefer manual installation:

```bash
cd ClaudeSkills
./see-terminal/install.sh
./tmux-wait/install.sh
./init-team-ai/install.sh
```

**Note**: With manual installation, you'll need to run `/init-team-ai` in your target project to set up pre-approved permissions, or you'll face permission prompts when using the skills.

Each skill has its own `install.sh` script for easy installation and an `uninstall.sh` for removal.

## Skill Structure

Each skill in this repository follows a standard structure:

```
SkillName/
├── README.md           # Detailed documentation
├── install.sh          # Installation script
├── uninstall.sh        # Uninstallation script
└── commands/           # Skill definitions
    └── SKILL.md        # Skill definition file
```

## Usage Pattern

All skills are designed to work seamlessly within Claude Code:

1. **Install** the skill using its `install.sh` script
2. **Restart** Claude Code to load the new skill
3. **Request** relevant tasks - Claude will automatically use the skill when appropriate
4. **Interact** naturally with Claude about the results

## Skill Catalog

| Skill | Name | Description | Status |
|-------|------|-------------|--------|
| [See Terminal](./see-terminal/) | `see-terminal` | Capture, analyze, and control tmux pane contents | ✅ Stable |
| [Tmux Wait](./tmux-wait/) | `tmux-wait` | Event-driven waiting for tmux pane commands | ✅ Stable |
| [Init Team AI](./init-team-ai/) | `init-team-ai` | Initialize projects with team AI collaboration setup | ✅ Stable |

_More skills coming soon!_

## Requirements

**General**:
- Claude Code (latest version recommended)
- Bash shell (WSL, Linux, or macOS)

**Skill-specific**:
- See individual skill READMEs for specific dependencies

## Platform Compatibility

**Tested on**: Windows WSL (Windows Subsystem for Linux)
**Likely works on**: Native Linux, macOS
**Not extensively tested on**: macOS, BSD, other Unix-like systems

Individual skills may have specific platform requirements. Check each skill's README for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/kiralpoon/ClaudeSkills/issues)
- **Discussions**: [GitHub Discussions](https://github.com/kiralpoon/ClaudeSkills/discussions)
- **Claude Code Docs**: [claude.ai/docs](https://claude.ai/docs)

## License

MIT License - See [LICENSE](LICENSE) file for details.

Individual skills may have additional license information in their respective directories.

## Acknowledgments

- Built for [Claude Code](https://claude.ai/download) by Anthropic
- Inspired by the Claude Code community
- Thanks to all contributors!

---

**⭐ Star this repo if you find it useful!**

**🔗 Share your own skills** - Open a PR to add your skill to the collection!
