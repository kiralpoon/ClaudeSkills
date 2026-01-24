# Chrome MCP Skill

A Claude Code skill for setting up and launching Chrome DevTools MCP for browser automation in WSL environments.

## What It Does

This skill automates the entire setup process for Chrome DevTools MCP:

1. **Checks existing sessions** - Detects if Chrome is already running with debugging enabled
2. **Installs MCP** - Automatically installs the Chrome DevTools MCP if not present
3. **Finds Chrome** - Locates Chrome on your Windows filesystem
4. **Sets up tmux layout** - Splits the pane (Chrome on top, Claude below)
5. **Starts Chrome** - Launches Chrome with remote debugging enabled
6. **Verifies connection** - Confirms Chrome is ready for automation

## Why Use This?

Setting up browser automation in WSL requires several manual steps:
- Installing the MCP package
- Finding the correct Chrome path
- Starting Chrome with the right flags
- Verifying the connection

This skill handles all of that with a single command.

## Prerequisites

- **Windows**: Google Chrome installed
- **WSL2**: Claude Code with MCP support (WSL1 may work but is untested)
- **tmux**: Running in a tmux session (for pane splitting)
- **Admin access**: One-time setup requires administrator privileges for port forwarding

## Installation

From this directory, run:

```bash
./install.sh
```

Or manually:

```bash
mkdir -p ~/.claude/skills/chrome-mcp
cp commands/SKILL.md ~/.claude/skills/chrome-mcp/
```

## Usage

### Start with Default Port

```
/chrome-mcp
```

This starts Chrome with remote debugging on port 9222 (the default).

### Start with Custom Port

```
/chrome-mcp 9223
```

Use a different port if 9222 is already in use.

## What Happens

When you run `/chrome-mcp`:

### First Run (MCP Not Installed)

1. Skill detects MCP is not installed
2. Gets Windows host IP for WSL2 networking
3. Runs `claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest --browserUrl http://<WIN_HOST>:9222`
4. Prompts you to restart Claude Code
5. After restart, run `/chrome-mcp` again

### Normal Run (MCP Installed)

1. Checks if Chrome is already running with debugging (via Windows host IP)
2. Checks/sets up port forwarding (one-time, requires admin UAC approval)
3. If Chrome not running, finds Chrome installation on Windows
4. Splits tmux pane horizontally
5. Starts Chrome with `--remote-debugging-port=9222` and `--user-data-dir=C:\Temp\ChromeDebug`
6. Verifies Chrome is ready from Windows side (PowerShell)
7. Verifies WSL can reach Chrome through port forwarding
8. Reports success with Chrome version and usage tips

### Chrome Already Running

If Chrome is already running with debugging enabled:
1. Detects existing session
2. Reports Chrome version and debug URL
3. Skips all setup steps

## Pane Layout

After running `/chrome-mcp`:

```
+------------------------+
|     Chrome (pane 0)    |
|  (debugging process)   |
+------------------------+
|   Claude Code (pane 1) |
|  (your current shell)  |
+------------------------+
```

## Example Commands

After setup, you can ask Claude to control the browser:

- "Go to google.com and take a screenshot"
- "Navigate to example.com and click the first link"
- "Fill in the search box with 'Claude AI' and submit"
- "Get the page title and all links on the page"
- "Open developer tools and check for console errors"

## Troubleshooting

### Port Already in Use

```
ERROR: Chrome did not start within 30 seconds.
```

Solutions:
1. Use a different port: `/chrome-mcp 9223`
2. Close existing Chrome debugging sessions
3. Check what's using the port:
   ```bash
   netstat -ano | findstr :9222
   ```

### Chrome Not Found

```
ERROR: Chrome not found.
```

Solutions:
1. Install Google Chrome on Windows
2. Verify installation at one of these paths:
   - `C:\Program Files\Google\Chrome\Application\chrome.exe`
   - `C:\Program Files (x86)\Google\Chrome\Application\chrome.exe`
3. Add Chrome to your Windows PATH

### MCP Tools Not Available

After installing the MCP, if tools don't appear:
1. Make sure you restarted Claude Code
2. Check MCP is registered: `claude mcp list`
3. Verify MCP has correct URL (should have Windows host IP, not `127.0.0.1`)
4. Verify Chrome is accessible from WSL:
   ```bash
   WIN_HOST=$(ip route | grep default | awk '{print $3}')
   curl "http://$WIN_HOST:9222/json/version"
   ```

### WSL Cannot Reach Chrome

If Chrome is running but MCP tools fail with "Could not connect to Chrome":

1. **Check port forwarding exists** (from Windows PowerShell):
   ```powershell
   netsh interface portproxy show v4tov4
   ```

2. **Add port forwarding** (as Administrator):
   ```powershell
   netsh interface portproxy add v4tov4 listenport=9222 listenaddress=0.0.0.0 connectport=9222 connectaddress=127.0.0.1
   ```

3. **Check Windows Firewall** - may need to allow port 9222

### Chrome Profile Picker Appears

If Chrome shows "Who's using Chrome?" profile picker:
- Click **Guest mode** (bottom left) for a clean session
- Or select any profile - Chrome will start with debugging once a profile is selected

### Not Running in tmux

The pane splitting requires tmux. If you're not in tmux:
1. Start a tmux session: `tmux new-session -s dev`
2. Run Claude Code inside tmux
3. Run `/chrome-mcp`

## WSL2 Networking

WSL2 runs in a separate virtual network from Windows, which means:

- `127.0.0.1` in WSL refers to WSL's localhost, NOT Windows'
- Chrome listens on Windows' `127.0.0.1:9222`
- The MCP server runs in WSL and needs to reach Chrome

**Solution:** The skill sets up Windows port forwarding using `netsh interface portproxy`:

```powershell
# This is done automatically by the skill (requires admin)
netsh interface portproxy add v4tov4 listenport=9222 listenaddress=0.0.0.0 connectport=9222 connectaddress=127.0.0.1
```

This forwards connections from the WSL-facing network interface to Windows localhost.

**One-time setup:** The port forwarding rule persists across reboots. You only need to approve the UAC prompt once per port.

### Dynamic IP Detection

The Windows host IP (gateway) can change between WSL sessions. The skill:
1. Detects the current Windows host IP via `ip route`
2. Extracts the IP configured in the MCP settings
3. Compares them and updates the MCP configuration if they differ

This ensures the MCP always uses the correct IP, even after WSL restarts.

### Why --user-data-dir?

Chrome ignores `--remote-debugging-port` if it joins an existing Chrome process. The skill uses `--user-data-dir=C:\Temp\ChromeDebug` to force a new, isolated Chrome instance that respects the debugging flag.

## Technical Details

- **Default port**: 9222 (Chrome's standard remote debugging port)
- **Chrome detection**: Checks standard Windows installation paths
- **Chrome profile**: Isolated at `C:\Temp\ChromeDebug`
- **Connection timeout**: 30 seconds
- **MCP package**: `chrome-devtools-mcp@latest` from npm
- **MCP browserUrl**: Uses Windows host IP (from `ip route`), not `127.0.0.1`

### Skill Integration

This skill uses other ClaudeSkills for tmux operations:

- **`/see-terminal`** - Used to capture Chrome pane output after starting and for error diagnosis
- **`/tmux-wait`** - Available for waiting on terminal prompts (not used for HTTP verification)

**Why HTTP polling instead of /tmux-wait for Chrome?**

The skill uses `curl` to verify Chrome is ready because:
- `/tmux-wait` monitors tmux pane text output
- Chrome's debugging readiness is verified via HTTP endpoint (port 9222)
- The debugging port may be ready before Chrome outputs anything to the terminal
- HTTP check is the reliable way to confirm Chrome is accepting DevTools connections

## Chrome Paths Checked

1. `/mnt/c/Program Files/Google/Chrome/Application/chrome.exe`
2. `/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe`
3. PowerShell `Get-Command chrome` (for PATH-based installations)

## Uninstallation

To remove just the skill:

```bash
./uninstall.sh
```

To also remove the MCP configuration:

```bash
./uninstall.sh
claude mcp remove chrome-devtools
```

## Features

- **One-command setup** - No manual configuration needed
- **Auto-detect Chrome** - Finds Chrome on Windows automatically
- **Idempotent** - Safe to run multiple times
- **Custom ports** - Support for non-default debugging ports
- **Smart detection** - Skips setup if Chrome is already running
- **Clear feedback** - Reports status and troubleshooting tips

## License

MIT License - See LICENSE file in the repository root.

## Contributing

To improve this skill:

1. Fork the repository
2. Make your changes in the `chrome-mcp/` directory
3. Test the skill in WSL with Chrome
4. Submit a pull request

## Version History

- **1.0.0** (2026-01-24) - Initial release
  - Automatic MCP installation with WSL2-compatible URL
  - Chrome auto-detection for Windows/WSL
  - Automatic port forwarding setup via `netsh interface portproxy`
  - Isolated Chrome instance with `--user-data-dir` flag
  - Two-stage verification (Windows side then WSL)
  - Tmux pane splitting
  - Custom port support
  - Comprehensive WSL2 networking documentation
