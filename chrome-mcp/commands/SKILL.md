---
name: chrome-mcp
description: "Setup Chrome DevTools MCP with Linux Chrome and mirrored networking"
argument-hint: ""
allowed-tools: Bash(*), Skill(tmux-wait), Skill(see-terminal), mcp__chrome-devtools__*
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
    echo "NEEDS_WSL_RESTART=false"
elif grep -q "networkingMode=" "$WSLCONFIG" 2>/dev/null; then
    echo "Updating networkingMode to mirrored..."
    sed -i 's/networkingMode=.*/networkingMode=mirrored/' "$WSLCONFIG"
    echo "Mirrored networking configured."
    echo "NEEDS_WSL_RESTART=true"
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
    echo "NEEDS_WSL_RESTART=true"
fi
```

---

## Step 2: Check/Install Linux Chrome and Asian Fonts

Check if Chrome is already installed:

```bash
if which google-chrome >/dev/null 2>&1; then
    echo "Linux Chrome: $(google-chrome --version)"
    echo "CHROME_ALREADY_INSTALLED=true"
else
    echo "CHROME_ALREADY_INSTALLED=false"
    echo "Chrome needs to be installed (requires sudo password)"
fi
```

**If Chrome is NOT installed (`CHROME_ALREADY_INSTALLED=false`):**

Find an idle tmux pane (or create one if all are busy), then send installation commands:

```bash
# Find an idle pane by checking which panes are running just a shell
IDLE_PANE=""
for pane_id in $(tmux list-panes -F '#{pane_index}' | grep -v '^0$'); do
    pane_cmd=$(tmux display-message -p -t "$pane_id" '#{pane_current_command}')
    if [[ "$pane_cmd" == "bash" || "$pane_cmd" == "zsh" || "$pane_cmd" == "sh" || "$pane_cmd" == "fish" ]]; then
        IDLE_PANE="$pane_id"
        break
    fi
done

if [[ -z "$IDLE_PANE" ]]; then
    tmux split-window -h
    IDLE_PANE=$(tmux list-panes -F '#{pane_index}' | sort -n | tail -1)
    echo "✓ Created pane $IDLE_PANE for Chrome installation"
else
    echo "✓ Using idle pane $IDLE_PANE for Chrome installation"
fi

# Send Chrome installation commands to the target pane
tmux send-keys -t "$IDLE_PANE" "wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb && sudo apt install -y /tmp/chrome.deb && rm /tmp/chrome.deb && google-chrome --version" Enter

echo "Installation started in pane $IDLE_PANE."
echo "If prompted, please enter your sudo password in pane $IDLE_PANE."
```

Wait for installation to complete — first re-detect the install pane, then wait:

```bash
# Re-detect: find the non-0 pane that is busy (running something other than a shell)
INSTALL_PANE=""
for pane_id in $(tmux list-panes -F '#{pane_index}' | grep -v '^0$'); do
    pane_cmd=$(tmux display-message -p -t "$pane_id" '#{pane_current_command}')
    if [[ "$pane_cmd" != "bash" && "$pane_cmd" != "zsh" && "$pane_cmd" != "sh" && "$pane_cmd" != "fish" ]]; then
        INSTALL_PANE="$pane_id"
        break
    fi
done
# Fallback: highest non-0 pane (install may have already finished)
if [[ -z "$INSTALL_PANE" ]]; then
    INSTALL_PANE=$(tmux list-panes -F '#{pane_index}' | grep -v '^0$' | sort -n | tail -1)
fi
echo "INSTALL_PANE=$INSTALL_PANE"
```

```
Use Skill tool with skill="tmux-wait" and args="prompt <INSTALL_PANE> 120"
(Replace <INSTALL_PANE> with the pane number printed above)
```

Verify Chrome was installed successfully:

```bash
if which google-chrome >/dev/null 2>&1; then
    echo "✓ Chrome installed: $(google-chrome --version)"
else
    echo "✗ Chrome installation failed"
fi
```

**If installation failed:**

Capture pane output to check for errors — re-detect the install pane:

```bash
# Re-detect: find the non-0 pane (install finished, so fallback to highest non-0 pane)
INSTALL_PANE=$(tmux list-panes -F '#{pane_index}' | grep -v '^0$' | sort -n | tail -1)
echo "INSTALL_PANE=$INSTALL_PANE"
```

```
Use Skill tool with skill="see-terminal" and args="<INSTALL_PANE> 100"
(Replace <INSTALL_PANE> with the pane number printed above)
```

Then report the error to the user and exit.

### Install Asian Fonts

Check and install fonts for Japanese and Chinese character support:

```bash
echo "Checking Asian fonts..."
JA_FONTS=$(fc-list :lang=ja | wc -l)
ZH_FONTS=$(fc-list :lang=zh | wc -l)

if [[ $JA_FONTS -gt 0 ]] && [[ $ZH_FONTS -gt 0 ]]; then
    echo "✓ Asian fonts already installed (Japanese: $JA_FONTS, Chinese: $ZH_FONTS)"
    echo "FONTS_INSTALLED=true"
else
    echo "Asian fonts need to be installed (requires sudo password)"
    echo "FONTS_INSTALLED=false"
fi
```

**If fonts are NOT installed (`FONTS_INSTALLED=false`):**

Find an idle tmux pane (or create one if all are busy), then send installation commands:

```bash
# Find an idle pane by checking which panes are running just a shell
IDLE_PANE=""
for pane_id in $(tmux list-panes -F '#{pane_index}' | grep -v '^0$'); do
    pane_cmd=$(tmux display-message -p -t "$pane_id" '#{pane_current_command}')
    if [[ "$pane_cmd" == "bash" || "$pane_cmd" == "zsh" || "$pane_cmd" == "sh" || "$pane_cmd" == "fish" ]]; then
        IDLE_PANE="$pane_id"
        break
    fi
done

if [[ -z "$IDLE_PANE" ]]; then
    tmux split-window -h
    IDLE_PANE=$(tmux list-panes -F '#{pane_index}' | sort -n | tail -1)
    echo "✓ Created pane $IDLE_PANE for font installation"
else
    echo "✓ Using idle pane $IDLE_PANE for font installation"
fi

# Send font installation command to the target pane
tmux send-keys -t "$IDLE_PANE" "sudo apt install -y fonts-noto-cjk fonts-noto-cjk-extra && fc-cache -fv && echo 'Japanese fonts: \$(fc-list :lang=ja | wc -l)' && echo 'Chinese fonts: \$(fc-list :lang=zh | wc -l)'" Enter

echo "Installation started in pane $IDLE_PANE."
echo "If prompted, please enter your sudo password in pane $IDLE_PANE."
```

Wait for installation to complete — first re-detect the install pane, then wait:

```bash
# Re-detect: find the non-0 pane that is busy (running something other than a shell)
INSTALL_PANE=""
for pane_id in $(tmux list-panes -F '#{pane_index}' | grep -v '^0$'); do
    pane_cmd=$(tmux display-message -p -t "$pane_id" '#{pane_current_command}')
    if [[ "$pane_cmd" != "bash" && "$pane_cmd" != "zsh" && "$pane_cmd" != "sh" && "$pane_cmd" != "fish" ]]; then
        INSTALL_PANE="$pane_id"
        break
    fi
done
# Fallback: highest non-0 pane (install may have already finished)
if [[ -z "$INSTALL_PANE" ]]; then
    INSTALL_PANE=$(tmux list-panes -F '#{pane_index}' | grep -v '^0$' | sort -n | tail -1)
fi
echo "INSTALL_PANE=$INSTALL_PANE"
```

```
Use Skill tool with skill="tmux-wait" and args="prompt <INSTALL_PANE> 120"
(Replace <INSTALL_PANE> with the pane number printed above)
```

Verify fonts were installed successfully:

```bash
JA_FONTS=$(fc-list :lang=ja | wc -l)
ZH_FONTS=$(fc-list :lang=zh | wc -l)

if [[ $JA_FONTS -gt 0 ]] && [[ $ZH_FONTS -gt 0 ]]; then
    echo "✓ Asian fonts installed successfully (Japanese: $JA_FONTS, Chinese: $ZH_FONTS)"
else
    echo "✗ Font installation may have failed"
    echo "Japanese fonts: $JA_FONTS"
    echo "Chinese fonts: $ZH_FONTS"
fi
```

**If installation failed:**

Capture pane output to check for errors — re-detect the install pane:

```bash
# Re-detect: find the non-0 pane (install finished, so fallback to highest non-0 pane)
INSTALL_PANE=$(tmux list-panes -F '#{pane_index}' | grep -v '^0$' | sort -n | tail -1)
echo "INSTALL_PANE=$INSTALL_PANE"
```

```
Use Skill tool with skill="see-terminal" and args="<INSTALL_PANE> 100"
(Replace <INSTALL_PANE> with the pane number printed above)
```

Then report the error to the user and exit.

---

## Step 3: Configure Chrome Language Settings

**ONLY if Chrome is installed.**

### 3.1: Configure Language Preferences

Configure Chrome to support English, Japanese, and Chinese:

```bash
CHROME_PREFS="$HOME/.config/google-chrome/Default/Preferences"

# Check if languages are already configured
if [[ -f "$CHROME_PREFS" ]] && grep -q '"ja"' "$CHROME_PREFS" && grep -q '"zh' "$CHROME_PREFS"; then
    echo "✓ Languages already configured (Japanese and Chinese found)"
    echo "LANGUAGES_CONFIGURED=true"
else
    echo "Configuring language preferences..."

    # Ensure the Default profile directory exists
    mkdir -p "$(dirname "$CHROME_PREFS")"

    # Backup existing preferences if they exist
    if [[ -f "$CHROME_PREFS" ]]; then
        cp "$CHROME_PREFS" "$CHROME_PREFS.backup"
        echo "Backed up existing preferences"
    fi

    # Use Python to create or modify the Preferences file
    python3 << 'EOF'
import json
import sys
import os

prefs_file = os.path.expanduser("~/.config/google-chrome/Default/Preferences")

try:
    # Read existing preferences or create new ones
    if os.path.exists(prefs_file):
        with open(prefs_file, 'r') as f:
            prefs = json.load(f)
        print("Updating existing preferences...")
    else:
        # Create minimal preferences structure
        prefs = {
            "browser": {
                "check_default_browser": False
            }
        }
        print("Creating new preferences file...")

    # Ensure intl section exists
    if 'intl' not in prefs:
        prefs['intl'] = {}

    # Set accept languages to include English, Japanese, and Chinese
    prefs['intl']['accept_languages'] = 'en-US,en,ja,zh-CN,zh'

    # Set selected languages (list format)
    prefs['intl']['selected_languages'] = ['en-US', 'en', 'ja', 'zh-CN', 'zh']

    # Write to file
    with open(prefs_file, 'w') as f:
        json.dump(prefs, f, indent=2)

    print("✓ Language preferences configured: English, Japanese, Chinese")
    sys.exit(0)
except Exception as e:
    print(f"✗ Failed to configure preferences: {e}")
    sys.exit(1)
EOF

    if [[ $? -eq 0 ]]; then
        echo "LANGUAGES_CONFIGURED=true"
    else
        echo "LANGUAGES_CONFIGURED=false"
        echo "✗ Failed to configure language preferences"
    fi
fi
```

### 3.2: Verify Language Configuration

```bash
CHROME_PREFS="$HOME/.config/google-chrome/Default/Preferences"

if [[ -f "$CHROME_PREFS" ]]; then
    echo "Verifying language settings..."
    if grep -q '"ja"' "$CHROME_PREFS" && grep -q '"zh' "$CHROME_PREFS"; then
        echo "✓ Japanese and Chinese languages verified in preferences"
    else
        echo "! Language settings may need verification"
    fi
else
    echo "! Preferences file was not created"
fi
```

---

## Step 4: Configure MCP and Determine Next Action

### 4.1: Check/Configure MCP

Check if MCP is already configured:

```bash
if claude mcp list 2>/dev/null | grep -q "chrome-devtools"; then
    echo "MCP_ALREADY_CONFIGURED=true"
    echo "✓ Chrome DevTools MCP is already configured."
else
    echo "MCP_ALREADY_CONFIGURED=false"
    echo "Configuring Chrome DevTools MCP..."
    claude mcp remove chrome-devtools 2>/dev/null
    claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest --executablePath=/usr/bin/google-chrome
    echo "✓ MCP configured with Linux Chrome."
fi
```

### 4.2: Determine Next Action

**If `NEEDS_WSL_RESTART=true`:**

Report and EXIT:

```
========================================
Chrome DevTools MCP Setup Complete
========================================

Mirrored networking was configured.

REQUIRED: Restart WSL for networking changes.

Run in Windows PowerShell or CMD:
  wsl --shutdown

Then restart terminal and Claude Code.
After restart, run /chrome-mcp again to test browser.
```

**If `MCP_ALREADY_CONFIGURED=false` (MCP was just configured):**

Report and EXIT:

```
========================================
Chrome DevTools MCP Setup Complete
========================================

✓ Chrome installed: [version]
✓ Asian fonts installed: Japanese, Chinese
✓ Languages configured: English, Japanese, Chinese
✓ MCP configured with Linux Chrome

REQUIRED: Restart Claude Code for MCP changes to take effect.

After restart, run /chrome-mcp again to test the browser.
```

**If `NEEDS_WSL_RESTART=false` AND `MCP_ALREADY_CONFIGURED=true`:**

Proceed to Step 5 (Test Browser).

---

## Step 5: Test Browser and Verify Asian Fonts

**ONLY execute this step if MCP is already configured and available.**

This step verifies that Chrome starts correctly, language settings are working, and Asian fonts render properly without weird font issues.

### 5.1: Check for Existing Browser Instance and Restart if Needed

First check if Chrome processes are already running:

```bash
echo "Checking for existing Linux Chrome processes..."
if ps aux | grep -E 'google-chrome|chrome-devtools-mcp' | grep -v grep > /dev/null; then
    echo "Found existing Linux Chrome processes. Restarting browser for clean test..."
    pkill -f chrome-devtools-mcp || true
    pkill -f google-chrome || true
    sleep 2

    # Verify processes stopped
    if ps aux | grep -E 'google-chrome|chrome-devtools-mcp' | grep -v grep > /dev/null; then
        echo "! Some Linux Chrome processes still running, forcing stop..."
        pkill -9 -f google-chrome || true
        sleep 1
    fi
    echo "✓ All Linux Chrome processes stopped"
    echo "BROWSER_RESTARTED=true"
else
    echo "No existing Linux Chrome processes found"
    echo "BROWSER_RESTARTED=false"
fi
```

### 5.2: Start Browser and Test Japanese Fonts

Use the MCP tools to start a new browser page and navigate to Google Japan:

```
Use mcp__chrome-devtools__new_page with url="https://www.google.co.jp"
```

Take a snapshot to check for Japanese content:

```
Use mcp__chrome-devtools__take_snapshot
```

Verify Japanese text is present in the snapshot (look for "日本語", "検索", "ストア", etc.).

Take a screenshot to visually verify font rendering:

```
Use mcp__chrome-devtools__take_screenshot
```

**Analyze the screenshot:**
- Check that Japanese characters render properly
- Look for any boxes (□□□) or weird font issues
- Verify text is crisp and readable

### 5.3: Test Chinese Fonts

Navigate to a Chinese website:

```
Use mcp__chrome-devtools__navigate_page with type="url" and url="https://www.baidu.com"
```

Take a screenshot to verify Chinese font rendering:

```
Use mcp__chrome-devtools__take_screenshot
```

**Analyze the screenshot:**
- Check that Chinese characters render properly (look for "百度", "新闻", "地图", "贴吧", etc.)
- Look for any boxes (□□□) or weird font issues
- Verify text is crisp and readable

### 5.4: Report Font Verification Results

Report the complete verification status:

```
========================================
Chrome DevTools MCP - Font Verification Complete
========================================

✓ Chrome browser restarted successfully (if needed)
✓ Japanese fonts verified on Google.co.jp
  - Characters like "日本語", "検索", "ストア", "画像" display correctly

✓ Chinese fonts verified on Baidu.com
  - Characters like "百度", "新闻", "地图", "贴吧", "视频" display correctly

✓ No font rendering issues detected
  - No boxes (□□□) appearing in place of characters
  - All text is crisp and properly rendered
  - Both simplified Chinese and Japanese characters work perfectly

Summary:
The Chrome DevTools MCP setup is fully functional with complete Asian language support:
  - Linux Chrome <insert version from google-chrome --version>
  - <insert count> Japanese fonts and <insert count> Chinese fonts installed
  - Language preferences configured for English, Japanese, and Chinese
  - WSL2 mirrored networking enabled
  - MCP server connected and operational

The browser is ready for use with full multilingual support!
```

**If font issues ARE detected (boxes or weird rendering):**

Report the issue and provide fix instructions:

```
⚠ FONT RENDERING ISSUES DETECTED
========================================

The browser is displaying boxes (□□□) or weird fonts for Asian characters.

This may indicate:
1. Fonts were not installed correctly
2. Font cache needs to be refreshed

Recommended fixes:
1. Reinstall fonts (requires sudo):
   sudo apt install --reinstall fonts-noto-cjk fonts-noto-cjk-extra
   fc-cache -fv

2. Restart Claude Code and run /chrome-mcp again

Note: If sudo password is required, you may need to run these commands manually
or the skill will need to use the see-terminal skill for interactive execution.
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
