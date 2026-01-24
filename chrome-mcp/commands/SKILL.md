---
name: chrome-mcp
description: "Setup and launch Chrome DevTools MCP for browser automation in WSL"
argument-hint: "[port] - optional debugging port (default: 9222)"
allowed-tools: Bash(*), Read(*), Skill(see-terminal:*), Skill(tmux-wait:*)
---

# Chrome DevTools MCP Setup

## EXECUTE IMMEDIATELY

**Arguments received:** `$ARGS`
- **$1** = port number (optional, default: 9222)

Parse the port argument and store it for use throughout:
```bash
PORT="${1:-9222}"
echo "Using debugging port: $PORT"

# Get Windows host IP for WSL2 networking
WIN_HOST=$(ip route | grep default | awk '{print $3}')
echo "Windows host IP: $WIN_HOST"
```

---

## Step 1: Check if Chrome is Already Running with Debugging

**IMPORTANT:** In WSL2, we cannot use `curl` to check `127.0.0.1` because that refers to WSL's localhost, not Windows'. Instead, check from Windows side using PowerShell in pane 0, OR check if port forwarding is already set up.

First, try to reach Chrome via the Windows host IP (works if port forwarding is configured):

```bash
if curl -s --max-time 2 "http://$WIN_HOST:$PORT/json/version" > /dev/null 2>&1; then
    VERSION=$(curl -s "http://$WIN_HOST:$PORT/json/version" | grep -o '"Browser":"[^"]*"' | cut -d'"' -f4)
    echo "Chrome already running with debugging on port $PORT"
    echo "  Browser: $VERSION"
    echo "  Debug URL: http://$WIN_HOST:$PORT"
    echo ""
    echo "Chrome DevTools MCP is ready to use."
    echo "CHROME_READY=true"
fi
```

**If Chrome is already running (CHROME_READY=true):** Report status and EXIT - skill is complete.

**If Chrome is NOT running or unreachable:** Continue to Step 2.

---

## Step 2: Check if MCP is Installed (with correct browserUrl)

Check if chrome-devtools MCP is configured with the correct Windows host URL.

**IMPORTANT:** The Windows host IP can change between WSL sessions. We must extract the currently configured IP and compare it to the current `$WIN_HOST`.

```bash
MCP_INSTALLED=false
MCP_CORRECT_URL=false
CONFIGURED_IP=""

# Check each config file for chrome-devtools
for config_file in ~/.claude.json ~/.claude/settings.json ~/.claude/settings.local.json; do
    if [[ -f "$config_file" ]] && grep -q "chrome-devtools" "$config_file" 2>/dev/null; then
        MCP_INSTALLED=true
        # Extract the configured browserUrl IP (e.g., "http://172.30.16.1:9222" -> "172.30.16.1")
        CONFIGURED_IP=$(grep -oP 'http://\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(?=:[0-9]+)' "$config_file" 2>/dev/null | head -1)
        break
    fi
done

if [[ "$MCP_INSTALLED" == "true" ]]; then
    echo "Chrome DevTools MCP is installed."
    echo "  Configured IP: $CONFIGURED_IP"
    echo "  Current Windows host IP: $WIN_HOST"

    if [[ "$CONFIGURED_IP" == "$WIN_HOST" ]]; then
        MCP_CORRECT_URL=true
        echo "  Status: URL is correct."
    else
        echo "  Status: URL needs update (Windows host IP changed)."
    fi
else
    echo "Chrome DevTools MCP is not installed."
fi
```

**If MCP is NOT installed OR has wrong URL (IP changed):**

```bash
# Remove old configuration if it exists
claude mcp remove chrome-devtools 2>/dev/null

echo "Installing Chrome DevTools MCP with WSL2-compatible URL..."
claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest --browserUrl "http://$WIN_HOST:$PORT"
```

Then report to user:
```
MCP installed/updated successfully!

IMPORTANT: Please restart Claude Code and run /chrome-mcp again.
The MCP tools will only be available after restarting.
```

**EXIT** - User must restart Claude Code.

**If MCP is installed with correct URL:** Continue to Step 3.

---

## Step 3: Check/Setup Port Forwarding

WSL2 cannot reach Windows localhost directly. We need port forwarding via `netsh interface portproxy`.

**Check if port forwarding is already set up:**

Run PowerShell directly from WSL to check (no tmux pane needed):

```bash
# Check if port forwarding rule exists for this port
PORTPROXY_OUTPUT=$(powershell.exe -Command "netsh interface portproxy show v4tov4" 2>/dev/null | tr -d '\r')

if echo "$PORTPROXY_OUTPUT" | grep -q "$PORT"; then
    echo "Port forwarding is already configured for port $PORT."
    PORT_FORWARD_EXISTS=true
else
    echo "Port forwarding not configured for port $PORT."
    PORT_FORWARD_EXISTS=false
fi
```

**If port forwarding is NOT configured:**

Explain to user and set up port forwarding:
```
Port forwarding is required for WSL2 to reach Chrome on Windows.

This requires administrator privileges. A UAC prompt will appear.
```

```bash
echo "Setting up port forwarding (requires admin)..."
powershell.exe -Command "Start-Process powershell -Verb RunAs -ArgumentList '-Command netsh interface portproxy add v4tov4 listenport=$PORT listenaddress=0.0.0.0 connectport=$PORT connectaddress=127.0.0.1'" 2>/dev/null

echo "Please approve the UAC prompt to set up port forwarding..."
echo "Waiting for approval..."
sleep 5

# Verify port forwarding was added
PORTPROXY_OUTPUT=$(powershell.exe -Command "netsh interface portproxy show v4tov4" 2>/dev/null | tr -d '\r')
if echo "$PORTPROXY_OUTPUT" | grep -q "$PORT"; then
    echo "Port forwarding configured successfully."
else
    echo "WARNING: Port forwarding may not have been configured."
    echo "You may need to run this manually as Administrator:"
    echo "  netsh interface portproxy add v4tov4 listenport=$PORT listenaddress=0.0.0.0 connectport=$PORT connectaddress=127.0.0.1"
fi
```

**If port forwarding is already configured:** Continue to Step 4.

---

## Step 4: Find Chrome Executable

Locate Chrome on the Windows filesystem:

```bash
# Check default installation path
DEFAULT_CHROME="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
if [[ -f "$DEFAULT_CHROME" ]]; then
    CHROME_PATH="$DEFAULT_CHROME"
else
    # Try Program Files (x86)
    ALT_CHROME="/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe"
    if [[ -f "$ALT_CHROME" ]]; then
        CHROME_PATH="$ALT_CHROME"
    else
        # Try to find via PowerShell
        CHROME_PATH=$(powershell.exe -Command "(Get-Command chrome -ErrorAction SilentlyContinue).Source" 2>/dev/null | tr -d '\r')
    fi
fi

if [[ -z "$CHROME_PATH" || ! -f "$CHROME_PATH" ]]; then
    echo "ERROR: Chrome not found."
    echo ""
    echo "Please ensure Google Chrome is installed on Windows."
    echo "Checked locations:"
    echo "  - C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
    echo "  - C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe"
fi
```

**If Chrome is NOT found:** Report error and EXIT.

**If Chrome is found:** Report location and convert path for Windows.

```bash
echo "Found Chrome at: $CHROME_PATH"

# Convert WSL path to Windows path for PowerShell
WIN_CHROME_PATH=$(echo "$CHROME_PATH" | sed 's|/mnt/c|C:|' | sed 's|/|\\|g')
```

---

## Step 5: Split Pane and Start Chrome

Split the current tmux pane and start Chrome with remote debugging.

**IMPORTANT:** Use `--user-data-dir` to force a new Chrome instance. Without this, if Chrome is already running, the new window joins the existing process and ignores the debugging flag.

```bash
# Split pane 0 horizontally (creates new pane below)
tmux split-window -v -t 0

# Swap so Chrome is on top (pane 0), Claude stays on bottom (pane 1)
tmux swap-pane -s 0 -t 1

# Start Chrome in pane 0 with remote debugging AND isolated profile
# Using --user-data-dir ensures this Chrome instance runs separately
tmux send-keys -t 0 "powershell.exe -Command \"Start-Process '$WIN_CHROME_PATH' -ArgumentList '--remote-debugging-port=$PORT','--user-data-dir=C:\\Temp\\ChromeDebug'\"" Enter
```

Report to user:
```
Starting Chrome with remote debugging on port $PORT...
Using isolated profile at C:\Temp\ChromeDebug
```

**After sending the command, use /see-terminal to check the Chrome pane:**

```
/see-terminal 0
```

This captures the Chrome pane output to see if Chrome started or if there were errors.

**Note about profile selection:**
If Chrome shows a profile picker, selecting "Guest mode" (bottom left) is recommended for testing, as it ensures a fresh session.

---

## Step 6: Wait for Chrome to Be Ready

**IMPORTANT:** Verify from **Windows side** (pane 0) using PowerShell, since WSL curl may not work until Chrome is fully ready.

Send verification command to pane 0:
```bash
tmux send-keys -t 0 "powershell.exe -Command \"(Invoke-WebRequest -Uri 'http://localhost:$PORT/json/version' -UseBasicParsing -TimeoutSec 5).Content\"" Enter
```

Wait and check result:
```bash
sleep 3
tmux capture-pane -t 0 -p -S -15
```

Look for JSON response containing `"Browser":` in the output.

**If no response after 30 seconds:** Use /see-terminal to diagnose:

```
/see-terminal 0 100
```

Common issues:
- Profile picker waiting for selection → Select a profile or Guest mode
- Port already in use → Use different port: `/chrome-mcp 9223`
- Chrome not starting → Check pane for error messages

**If Chrome responds:** Continue to Step 7.

---

## Step 7: Verify WSL Connectivity and Report Success

Now verify that WSL can reach Chrome through the port forwarding:

```bash
if curl -s --max-time 3 "http://$WIN_HOST:$PORT/json/version" > /dev/null 2>&1; then
    VERSION=$(curl -s "http://$WIN_HOST:$PORT/json/version" | grep -o '"Browser":"[^"]*"' | cut -d'"' -f4)
    echo ""
    echo "Chrome DevTools ready!"
    echo "  Browser: $VERSION"
    echo "  Debug URL: http://$WIN_HOST:$PORT"
    echo "  Port forwarding: Active"
else
    echo ""
    echo "WARNING: Chrome is running but WSL cannot reach it."
    echo "Port forwarding may not be configured correctly."
    echo ""
    echo "Try running this command as Administrator in PowerShell:"
    echo "  netsh interface portproxy add v4tov4 listenport=$PORT listenaddress=0.0.0.0 connectport=$PORT connectaddress=127.0.0.1"
fi
```

**Use /see-terminal to show the final state of the Chrome pane:**

```
/see-terminal 0 30
```

Then report to user:

```
You can now use Chrome DevTools MCP tools in Claude.

Example commands to try:
  - 'Go to google.com and take a screenshot'
  - 'Navigate to example.com and click the first link'
  - 'Fill out the search form and submit'

Pane layout:
  - Top pane (0): Chrome process
  - Bottom pane (1): Claude Code
```

---

## WSL2 Networking Notes

### Why Port Forwarding is Required

In WSL2, Windows and Linux run on separate virtual networks:
- `127.0.0.1` in WSL refers to WSL's loopback, NOT Windows'
- Chrome listens on Windows' `127.0.0.1:9222`
- WSL needs to reach Chrome via the Windows host IP (gateway)

The `netsh interface portproxy` command creates a forwarding rule:
- Listens on `0.0.0.0:9222` (all interfaces, including WSL-facing)
- Forwards to `127.0.0.1:9222` (Windows localhost where Chrome listens)

### Port Forwarding Persistence

The netsh rule persists across reboots. You only need to set it up once per port.

To view existing rules:
```powershell
netsh interface portproxy show v4tov4
```

To remove a rule:
```powershell
netsh interface portproxy delete v4tov4 listenport=9222 listenaddress=0.0.0.0
```

### Why --user-data-dir is Required

Chrome only accepts `--remote-debugging-port` when starting a NEW process. If Chrome is already running:
- New windows join the existing process
- The debugging flag is ignored
- Port 9222 won't be opened

Using `--user-data-dir=C:\Temp\ChromeDebug` forces Chrome to start a separate process with its own profile directory, ensuring the debugging flag takes effect.

---

## When to Use Each Skill

| Situation | Use |
|-----------|-----|
| Check Chrome pane output | `/see-terminal 0` |
| Wait for shell prompt in pane | `/tmux-wait prompt 0 30` |
| Wait for specific text in pane | `/tmux-wait output 0 "text" 30` |
| Check HTTP endpoint ready | PowerShell in pane 0, then `/see-terminal 0` |

**Why verify from pane 0 (Windows side)?**
- WSL curl may fail due to networking until port forwarding is active
- PowerShell can always reach Windows localhost
- More reliable for initial verification

---

## Usage Examples

| Command | Description |
|---------|-------------|
| `/chrome-mcp` | Start Chrome with default port 9222 |
| `/chrome-mcp 9223` | Start Chrome with custom port 9223 |

---

## Troubleshooting

### Port Already in Use

If you get "port in use" errors, either:
1. Use a different port: `/chrome-mcp 9223`
2. Find and close the process using the port (from Windows PowerShell):
   ```powershell
   netstat -ano | findstr :9222
   ```

### Chrome Not Found

If Chrome is installed in a non-standard location:
1. Add Chrome to your Windows PATH, or
2. Manually start Chrome with: `chrome.exe --remote-debugging-port=9222 --user-data-dir=C:\Temp\ChromeDebug`

### WSL Cannot Reach Chrome

If Chrome is running but MCP tools fail with connection errors:

1. **Check port forwarding exists:**
   ```powershell
   netsh interface portproxy show v4tov4
   ```

2. **Add port forwarding (as Administrator):**
   ```powershell
   netsh interface portproxy add v4tov4 listenport=9222 listenaddress=0.0.0.0 connectport=9222 connectaddress=127.0.0.1
   ```

3. **Check Windows Firewall** - may need to allow port 9222

4. **Test from WSL:**
   ```bash
   WIN_HOST=$(ip route | grep default | awk '{print $3}')
   curl "http://$WIN_HOST:9222/json/version"
   ```

### Profile Picker Appears

If Chrome shows "Who's using Chrome?" profile picker:
- Click **Guest mode** (bottom left) for a clean session
- Or select any profile - once selected, Chrome starts with debugging

### Chrome Joins Existing Process

If you see Chrome open but debugging doesn't work:
- Close ALL Chrome windows (check system tray)
- Or use a different `--user-data-dir` path
- The skill uses `C:\Temp\ChromeDebug` to avoid this issue

### Check Chrome Pane for Errors

If Chrome doesn't start, check the Chrome pane:
```
/see-terminal 0 100
```

This shows what Chrome output, including any error messages.

### MCP Tools Not Working

If MCP tools don't appear after installation:
1. Make sure you restarted Claude Code after running `/chrome-mcp`
2. Check MCP configuration: `claude mcp list`
3. Verify MCP has correct URL (should include Windows host IP, not 127.0.0.1)

---

## Complete Flow Summary

1. **Get Windows host IP** → `ip route | grep default | awk '{print $3}'`
2. **Check existing Chrome** → Try curl to `$WIN_HOST:$PORT`
3. **Check/Install MCP** → Must use `http://$WIN_HOST:$PORT`, not `127.0.0.1`
4. **Setup port forwarding** → `netsh interface portproxy` (requires admin, one-time)
5. **Find Chrome** → Check WSL paths, fallback to PowerShell
6. **Start Chrome** → `tmux send-keys` with `--user-data-dir` flag
7. **Verify from Windows** → PowerShell `Invoke-WebRequest` in pane 0
8. **Verify from WSL** → curl to `$WIN_HOST:$PORT`
9. **Report success** → `/see-terminal 0`, show usage examples
