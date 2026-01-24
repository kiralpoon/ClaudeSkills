# Chrome MCP Skill

A Claude Code skill for setting up Chrome DevTools MCP with Linux Chrome and WSL2 mirrored networking.

## What It Does

1. **Enables mirrored networking** - Configures WSL2 so `127.0.0.1` reaches Windows services
2. **Installs Linux Chrome** - Installs Chrome in WSL if not present
3. **Configures MCP** - Sets up chrome-devtools MCP to auto-launch Linux Chrome

## Prerequisites

- **Windows 11 22H2+** with WSL2
- **WSLg** enabled (for Chrome GUI)
- **Claude Code** with MCP support

## Installation

```bash
./install.sh
```

Or manually:

```bash
mkdir -p ~/.claude/skills/chrome-mcp
cp commands/SKILL.md ~/.claude/skills/chrome-mcp/
```

## Usage

```
/chrome-mcp
```

The skill will:
1. Enable mirrored networking in `.wslconfig` (if needed)
2. Install Linux Chrome (if needed)
3. Configure the MCP with `--executablePath=/usr/bin/google-chrome`

After setup, restart Claude Code. The MCP will auto-launch Chrome when you use browser automation commands.

## Example Commands

After setup:
- "Go to google.com and take a screenshot"
- "Navigate to example.com and click the first link"
- "Fill in the search box with 'Claude AI' and submit"

## Why Mirrored Networking?

WSL2 runs in a separate virtual network from Windows. With mirrored networking:
- `127.0.0.1` in WSL reaches Windows localhost
- Windows services (like ComfyUI on port 8188) are accessible from WSL
- No port forwarding or firewall rules needed

## Troubleshooting

### MCP Tools Not Available
Restart Claude Code after running `/chrome-mcp`.

### Chrome Window Doesn't Appear
Ensure WSLg is working: `ls /mnt/wslg`

### After Enabling Mirrored Networking
Restart WSL: `wsl --shutdown` from Windows PowerShell.

## Uninstallation

```bash
./uninstall.sh
claude mcp remove chrome-devtools
```

## License

MIT License - See LICENSE file in the repository root.
