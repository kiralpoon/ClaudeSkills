---
name: chrome-mcp
description: "Setup and launch Chrome DevTools MCP for browser automation in WSL"
argument-hint: "[method] - 'linux' (recommended), 'windows', or 'mirrored'"
allowed-tools: Bash(*), Read(*), Skill(see-terminal:*), Skill(tmux-wait:*)
---

# Chrome DevTools MCP Setup for WSL2

## EXECUTE IMMEDIATELY

**Arguments received:** `$ARGS`
- **$1** = setup method: `linux` (recommended), `windows`, or `mirrored`

If no argument provided, check current state and recommend the best approach.

---

## Overview: Three Setup Methods

Chrome DevTools MCP in WSL2 faces network isolation challenges. There are three approaches:

| Method | Description | Pros | Cons |
|--------|-------------|------|------|
| **linux** | Install Chrome in WSL | Most reliable, native | Requires WSLg, uses Linux Chrome |
| **windows** | Use Windows Chrome via port forwarding | Uses existing Chrome | Complex setup, can have connectivity issues |
| **mirrored** | Enable WSL2 mirrored networking | Simple once configured | Requires WSL restart, Windows 11 22H2+ |

**Recommendation:** Use `linux` method for best reliability.

---

## Method 1: Linux Chrome (Recommended)

### Step 1: Check if Linux Chrome is Installed

```bash
if which google-chrome >/dev/null 2>&1; then
    CHROME_VERSION=$(google-chrome --version 2>/dev/null)
    echo "Linux Chrome is installed: $CHROME_VERSION"
    LINUX_CHROME_INSTALLED=true
else
    echo "Linux Chrome is not installed."
    LINUX_CHROME_INSTALLED=false
fi
```

### Step 2: Install Chrome for Linux (if needed)

If Chrome is not installed:

```bash
echo "Installing Chrome for Linux..."
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
sudo apt install -y /tmp/chrome.deb
rm /tmp/chrome.deb
echo "Chrome for Linux installed successfully."
```

### Step 3: Configure MCP with executablePath

```bash
# Remove any existing configuration
claude mcp remove chrome-devtools 2>/dev/null

# Add MCP with Linux Chrome executable
claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest \
    --executablePath=/usr/bin/google-chrome

echo "MCP configured to use Linux Chrome."
```

### Step 4: Verify and Report

```bash
echo ""
echo "==================================="
echo "Chrome DevTools MCP Setup Complete"
echo "==================================="
echo ""
echo "Method: Linux Chrome (recommended)"
echo "Executable: /usr/bin/google-chrome"
echo ""
echo "IMPORTANT: Restart Claude Code for changes to take effect."
echo ""
echo "After restart, the MCP will launch Chrome automatically when needed."
echo "Chrome will open as a GUI window via WSLg."
echo ""
echo "Example commands to try after restart:"
echo "  - 'Navigate to google.com and take a screenshot'"
echo "  - 'Go to example.com and click the first link'"
```

**EXIT after reporting.**

---

## Method 2: Windows Chrome (Port Forwarding)

Use this if you need to use your existing Windows Chrome with extensions/bookmarks.

### Step 2.1: Get WSL Network Info

```bash
PORT="${2:-9222}"

# Get the vEthernet (WSL) IP - this is what WSL uses to reach Windows
# Method 1: From ipconfig output
WIN_HOST=$(powershell.exe -Command "(Get-NetIPAddress -InterfaceAlias 'vEthernet (WSL*' -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress" 2>/dev/null | tr -d '\r')

# Fallback: Use default gateway
if [[ -z "$WIN_HOST" ]]; then
    WIN_HOST=$(ip route | grep default | awk '{print $3}')
fi

echo "Using debugging port: $PORT"
echo "Windows host IP: $WIN_HOST"
```

### Step 2.2: Setup Port Forwarding

```bash
# Check if port forwarding exists
PORTPROXY_OUTPUT=$(powershell.exe -Command "netsh interface portproxy show v4tov4" 2>/dev/null | tr -d '\r')

if echo "$PORTPROXY_OUTPUT" | grep -q "$PORT"; then
    echo "Port forwarding already configured for port $PORT."
else
    echo "Setting up port forwarding (requires admin UAC approval)..."
    powershell.exe -Command "Start-Process powershell -Verb RunAs -ArgumentList '-Command netsh interface portproxy add v4tov4 listenport=$PORT listenaddress=0.0.0.0 connectport=$PORT connectaddress=127.0.0.1'" 2>/dev/null

    echo "Waiting for UAC approval..."
    sleep 5
fi
```

### Step 2.3: Setup Firewall Rule

```bash
# Add firewall rule if not exists
powershell.exe -Command "Start-Process powershell -Verb RunAs -ArgumentList '-Command New-NetFirewallRule -DisplayName \"Chrome DevTools MCP $PORT\" -Direction Inbound -Protocol TCP -LocalPort $PORT -Action Allow -ErrorAction SilentlyContinue'" 2>/dev/null
```

### Step 2.4: Configure MCP

```bash
claude mcp remove chrome-devtools 2>/dev/null
claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest --browserUrl "http://$WIN_HOST:$PORT"

echo "MCP configured with browserUrl: http://$WIN_HOST:$PORT"
```

### Step 2.5: Start Windows Chrome

```bash
# Find Chrome
CHROME_PATH="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
if [[ ! -f "$CHROME_PATH" ]]; then
    CHROME_PATH="/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe"
fi

WIN_CHROME_PATH=$(echo "$CHROME_PATH" | sed 's|/mnt/c|C:|' | sed 's|/|\\|g')

# Split pane and start Chrome
tmux split-window -v -t 0
tmux swap-pane -s 0 -t 1

tmux send-keys -t 0 "powershell.exe -Command \"Start-Process '$WIN_CHROME_PATH' -ArgumentList '--remote-debugging-port=$PORT','--user-data-dir=C:\\Temp\\ChromeDebug','--no-first-run','--no-default-browser-check'\"" Enter

echo "Started Chrome with remote debugging on port $PORT"
```

### Step 2.6: Verify Connection

Wait a few seconds, then verify from Windows side:
```bash
sleep 5
tmux send-keys -t 0 "powershell.exe -Command \"(Invoke-WebRequest -Uri 'http://localhost:$PORT/json/version' -UseBasicParsing -TimeoutSec 5).Content\"" Enter
```

Use `/see-terminal 0` to check results.

Then test from WSL:
```bash
curl -s --max-time 5 "http://$WIN_HOST:$PORT/json/version"
```

**If WSL curl fails but Windows works:** Chrome's localhost-only binding may be blocking. Consider using the `linux` or `mirrored` method instead.

---

## Method 3: Mirrored Networking

This enables WSL2 mirrored networking so `localhost` in WSL reaches Windows directly.

**Requirements:** Windows 11 22H2 or later with WSL 2.0.0+

### Step 3.1: Check Current Config

```bash
echo "Checking .wslconfig..."
if [[ -f /mnt/c/Users/$USER/.wslconfig ]]; then
    cat /mnt/c/Users/$USER/.wslconfig
else
    echo "No .wslconfig found."
fi
```

### Step 3.2: Enable Mirrored Networking

```bash
WSLCONFIG="/mnt/c/Users/$USER/.wslconfig"

if grep -q "networkingMode=mirrored" "$WSLCONFIG" 2>/dev/null; then
    echo "Mirrored networking is already configured."
else
    echo "Adding networkingMode=mirrored to .wslconfig..."

    if [[ -f "$WSLCONFIG" ]]; then
        # Check if [wsl2] section exists
        if grep -q "\[wsl2\]" "$WSLCONFIG"; then
            # Add under existing [wsl2] section
            sed -i '/\[wsl2\]/a networkingMode=mirrored' "$WSLCONFIG"
        else
            # Add new section
            echo -e "\n[wsl2]\nnetworkingMode=mirrored" >> "$WSLCONFIG"
        fi
    else
        # Create new file
        echo -e "[wsl2]\nnetworkingMode=mirrored" > "$WSLCONFIG"
    fi

    echo "Mirrored networking configured."
fi
```

### Step 3.3: Configure MCP for localhost

```bash
claude mcp remove chrome-devtools 2>/dev/null
claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest --browserUrl "http://localhost:9222"

echo "MCP configured to use localhost:9222"
```

### Step 3.4: Report and Request Restart

```
===========================================
Mirrored Networking Setup Complete
===========================================

IMPORTANT: You must restart WSL for changes to take effect.

Run this command in Windows PowerShell or CMD:
  wsl --shutdown

Then restart your terminal and Claude Code.

After restart:
1. Start Chrome with: chrome.exe --remote-debugging-port=9222 --user-data-dir=C:\Temp\ChromeDebug
2. localhost:9222 from WSL will reach Windows Chrome directly
```

**EXIT after reporting.**

---

## Auto-Detection Mode (No Arguments)

If no method is specified, detect the best approach:

```bash
echo "Detecting best setup method..."

# Check if Linux Chrome exists
if which google-chrome >/dev/null 2>&1; then
    echo "Linux Chrome detected. Recommending 'linux' method."
    RECOMMENDED="linux"
# Check if mirrored networking is enabled
elif grep -q "networkingMode=mirrored" /mnt/c/Users/$USER/.wslconfig 2>/dev/null; then
    echo "Mirrored networking detected. Recommending 'mirrored' method."
    RECOMMENDED="mirrored"
# Check if WSLg is available (for Linux Chrome)
elif [[ -d /mnt/wslg ]]; then
    echo "WSLg detected. Recommending 'linux' method for best reliability."
    RECOMMENDED="linux"
else
    echo "Recommending 'windows' method (port forwarding)."
    RECOMMENDED="windows"
fi

echo ""
echo "Run: /chrome-mcp $RECOMMENDED"
echo ""
echo "Available methods:"
echo "  /chrome-mcp linux    - Install Chrome in WSL (recommended)"
echo "  /chrome-mcp windows  - Use Windows Chrome via port forwarding"
echo "  /chrome-mcp mirrored - Enable WSL2 mirrored networking"
```

---

## Troubleshooting

### Connection Refused / Empty Reply

**Symptom:** `curl` to Windows Chrome returns "connection refused" or "empty reply"

**Cause:** Chrome's remote debugging only accepts connections from `127.0.0.1` for security.

**Solutions:**
1. Use the `linux` method (recommended)
2. Enable mirrored networking
3. Ensure firewall rule is added for port 9222

### MCP Tools Not Available

**Symptom:** Chrome DevTools MCP tools don't appear in Claude

**Solution:** Restart Claude Code after running `/chrome-mcp`. MCP changes require restart.

### Chrome Opens But Debugging Doesn't Work

**Cause:** Chrome joined an existing process instead of starting fresh.

**Solution:**
1. Close ALL Chrome windows (check system tray)
2. Use `--user-data-dir` to force a new process
3. Or use a different profile directory

### WSLg Display Issues

**Symptom:** Chrome window doesn't appear when using Linux method

**Solutions:**
1. Ensure WSLg is installed: `ls /mnt/wslg`
2. Try: `export DISPLAY=:0`
3. Restart WSL: `wsl --shutdown`

### Port Already in Use

**Solution:** Use a different port:
```bash
/chrome-mcp linux 9223
```

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `/chrome-mcp` | Auto-detect and recommend method |
| `/chrome-mcp linux` | Install and use Linux Chrome (recommended) |
| `/chrome-mcp windows` | Use Windows Chrome with port forwarding |
| `/chrome-mcp mirrored` | Enable mirrored networking mode |

---

## Sources

- [Chrome DevTools MCP GitHub](https://github.com/ChromeDevTools/chrome-devtools-mcp)
- [WSL Setup Guide](https://www.mfun.ink/english/post/chrome-devtools-mcp-wsl/)
- [WSL2 Support Issue #131](https://github.com/ChromeDevTools/chrome-devtools-mcp/issues/131)
- [WSL2 Support Issue #405](https://github.com/ChromeDevTools/chrome-devtools-mcp/issues/405)
