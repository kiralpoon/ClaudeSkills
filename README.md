# ClaudeSkills

A collection of custom skills for Claude Code that extend its capabilities with specialized commands and workflows.

## About

This repository contains skills (custom commands) for [Claude Code](https://claude.ai/download), Anthropic's official CLI tool. Each skill adds new functionality through slash commands that can be invoked during your coding sessions.

**Platform**: Primarily developed for Windows WSL (Windows Subsystem for Linux), but most skills should work on native Linux systems as well.

## Available Skills

### 🖥️ [WSL Terminal](./WSL_Terminal/)

**Command**: `/see-terminal`

Capture and analyze tmux pane contents directly within Claude Code. Perfect for debugging, reviewing build output, or getting Claude's insights on terminal activity.

**Key Features**:
- Capture output from any tmux pane
- Flexible pane targeting (by number or relative position)
- Adjustable history depth (default 50 lines)
- Automatic error analysis and suggestions

**Use Cases**:
- "What does this error mean?" - Capture and analyze error messages
- "Did the build succeed?" - Review build output
- "Summarize these test results" - Quick test output analysis

[📖 Full Documentation →](./WSL_Terminal/README.md)

## Quick Start

### Prerequisites

- [Claude Code](https://claude.ai/download) installed
- Git for cloning this repository
- WSL or Linux environment (for most skills)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/kiralpoon/ClaudeSkills.git
   cd ClaudeSkills
   ```

2. **Install a skill**:
   ```bash
   cd WSL_Terminal
   ./install.sh
   ```

3. **Start using it**:
   ```bash
   claude
   # In Claude Code session:
   /see-terminal
   ```

Each skill has its own `install.sh` script for easy installation and an `uninstall.sh` for removal.

## Skill Structure

Each skill in this repository follows a standard structure:

```
SkillName/
├── README.md           # Detailed documentation
├── install.sh          # Installation script
├── uninstall.sh        # Uninstallation script
├── commands/           # Command definitions
│   └── command.md      # Skill command file
└── .claude-plugin/     # Metadata (optional)
    └── plugin.json
```

## Usage Pattern

All skills are designed to work seamlessly within Claude Code:

1. **Install** the skill using its `install.sh` script
2. **Restart** Claude Code to pick up the new command
3. **Invoke** using the slash command (e.g., `/see-terminal`)
4. **Interact** with Claude about the results

## Skill Catalog

| Skill | Command | Description | Status |
|-------|---------|-------------|--------|
| [WSL Terminal](./WSL_Terminal/) | `/see-terminal` | Capture and analyze tmux pane contents | ✅ Stable |

_More skills coming soon!_

## Contributing

Have an idea for a skill? Want to improve an existing one?

### Adding a New Skill

1. Fork this repository
2. Create a new directory following the skill structure above
3. Implement your skill with proper documentation
4. Test thoroughly on WSL/Linux
5. Submit a pull request

### Improving Existing Skills

1. Check the individual skill's README for specific guidelines
2. Test your changes thoroughly
3. Update documentation as needed
4. Submit a pull request with clear description of changes

## Roadmap

Future skills under consideration:

- **Git Helper** - Advanced git operations and analysis
- **Code Review** - Automated code review workflows
- **Docker Manager** - Container inspection and debugging
- **Log Analyzer** - Parse and analyze application logs
- **Performance Profiler** - Capture and analyze performance metrics

Have a suggestion? [Open an issue](https://github.com/kiralpoon/ClaudeSkills/issues)!

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
