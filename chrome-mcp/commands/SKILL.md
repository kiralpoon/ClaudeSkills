---
name: chrome-mcp
description: "Setup Chrome DevTools MCP with Linux Chrome and mirrored networking"
argument-hint: ""
allowed-tools: Bash(*), Read(*)
---

# Chrome DevTools MCP Setup

## EXECUTE IMMEDIATELY

Sets up Chrome DevTools MCP using Linux Chrome with WSL2 mirrored networking.

---

## Step 1: Check/Enable Mirrored Networking

Mirrored networking allows `127.0.0.1` in WSL to reach Windows services.

```bash
WIN_USER=$(powershell.exe -Command 'echo $env:USERNAME' 2>/dev/null | tr -d '\r')
WSLCONFIG="/mnt/c/Users/$WIN_USER/.wslconfig"

if grep -q "networkingMode=mirrored" "$WSLCONFIG" 2>/dev/null; then
    echo "Mirrored networking: already configured"
    NEEDS_WSL_RESTART=false
elif grep -q "networkingMode=" "$WSLCONFIG" 2>/dev/null; then
    echo "Updating networkingMode to mirrored..."
    sed -i 's/networkingMode=.*/networkingMode=mirrored/' "$WSLCONFIG"
    echo "Mirrored networking configured."
    NEEDS_WSL_RESTART=true
else
    echo "Enabling mirrored networking..."
    if [[ -f "$WSLCONFIG" ]]; then
        if grep -q "\[wsl2\]" "$WSLCONFIG"; then
            sed -i '/\[wsl2\]/a networkingMode=mirrored' "$WSLCONFIG"
        else
            echo -e "\n[wsl2]\nnetworkingMode=mirrored" >> "$WSLCONFIG"
        fi
    else
        echo -e "[wsl2]\nnetworkingMode=mirrored" > "$WSLCONFIG"
    fi
    echo "Mirrored networking configured."
    NEEDS_WSL_RESTART=true
fi
```

---

## Step 2: Check/Install Linux Chrome

```bash
if which google-chrome >/dev/null 2>&1; then
    echo "Linux Chrome: $(google-chrome --version)"
    CHROME_INSTALLED=true
else
    echo "Installing Chrome for Linux..."
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
    sudo apt install -y /tmp/chrome.deb
    rm /tmp/chrome.deb
    echo "Linux Chrome installed."
    CHROME_INSTALLED=true
fi
```

---

## Step 3: Configure MCP

```bash
claude mcp remove chrome-devtools 2>/dev/null
claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest --executablePath=/usr/bin/google-chrome
echo "MCP configured with Linux Chrome."
```

---

## Step 4: Report Status

**If `NEEDS_WSL_RESTART=true`:**

```
========================================
Chrome DevTools MCP Setup Complete
========================================

Mirrored networking was configured.

REQUIRED: Restart WSL for networking changes.

Run in Windows PowerShell or CMD:
  wsl --shutdown

Then restart terminal and Claude Code.
```

**If `NEEDS_WSL_RESTART=false`:**

```
========================================
Chrome DevTools MCP Setup Complete
========================================

MCP configured to auto-launch Linux Chrome.

REQUIRED: Restart Claude Code for MCP changes.
```

**EXIT after reporting.**

---

## Troubleshooting

### MCP Tools Not Available
Restart Claude Code. MCP changes require restart.

### Chrome Window Doesn't Appear
Ensure WSLg is working: `ls /mnt/wslg`

### Display Issues
Try: `export DISPLAY=:0` then restart Claude Code.
