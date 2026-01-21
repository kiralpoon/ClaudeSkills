---
name: init-team-ai
description: Initialize a new project with team AI configuration files
argument-hint: [project-path (optional, defaults to current directory)]
allowed-tools: Read(*), Bash(mkdir:*), Bash(cp:*), Bash(cat:*), Bash(echo:*), Bash(grep:*), Bash(command:*), Bash(python3:*)
---

# Initialize Team AI Project

This skill sets up a new project for team AI collaboration by creating:
1. `Agents.md` - Core agent behavior and ExecPlan usage guidelines (gitignored)
2. `Claude.local.md` - Local preferences file (gitignored)
3. `.claude/settings.local.json` - Local settings with SessionStart hooks
4. `.agent/PLANS.md` - Detailed ExecPlan authoring guidelines (gitignored)
5. Updated `.gitignore` - Ensures local files are not committed

## Execution Efficiency Guidelines

**IMPORTANT: Execute this skill quickly and efficiently.**

- Use `cp` command to copy template files (instant, no AI processing)
- Templates are located in `$SKILL_DIR/templates/`
- Use Read tool only when checking existing file content is necessary
- Do NOT read files after creating them just to verify
- Do NOT analyze the content of files you just created
- Do NOT explore repository structure between steps
- Move immediately to the next step after each operation completes
- Only stop to analyze if a command fails

**Target execution time: 1-2 seconds total**

## Skill Execution

**Parameter Handling:**
- If $1 is provided: Use it as the target directory
- If $1 is empty: Use current directory (.)

**Step 1: Determine Target Directory**

```bash
TARGET_DIR="${1:-.}"
```

Verify the target directory exists:
```bash
if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: Directory '$TARGET_DIR' does not exist."
  exit 1
fi
```

**Step 2: Create Agents.md**

Copy from template if it doesn't exist:

```bash
if [ -f "$TARGET_DIR/Agents.md" ]; then
  echo "  ℹ Agents.md already exists - skipping to preserve your customizations"
else
  cp "$SKILL_DIR/templates/Agents.md" "$TARGET_DIR/Agents.md"
  if [ ! -f "$TARGET_DIR/Agents.md" ]; then
    echo "ERROR: Failed to create Agents.md"
    exit 1
  fi
  echo "  ✓ Created Agents.md"
fi
```

**Step 3: Create Claude.local.md**

Copy from template if it doesn't exist:

```bash
if [ -f "$TARGET_DIR/Claude.local.md" ]; then
  echo "  ℹ Claude.local.md already exists - skipping to preserve your customizations"
else
  cp "$SKILL_DIR/templates/Claude.local.md" "$TARGET_DIR/Claude.local.md"
  if [ ! -f "$TARGET_DIR/Claude.local.md" ]; then
    echo "ERROR: Failed to create Claude.local.md"
    exit 1
  fi
  echo "  ✓ Created Claude.local.md"
fi
```

**Step 4: Create .agent Directory and PLANS.md**

Create the agent directory and copy PLANS.md from template:

```bash
mkdir -p "$TARGET_DIR/.agent"
echo "  ✓ Created .agent directory"

if [ -f "$TARGET_DIR/.agent/PLANS.md" ]; then
  echo "  ℹ .agent/PLANS.md already exists - skipping to preserve your customizations"
else
  cp "$SKILL_DIR/templates/PLANS.md" "$TARGET_DIR/.agent/PLANS.md"
  if [ ! -f "$TARGET_DIR/.agent/PLANS.md" ]; then
    echo "ERROR: Failed to create .agent/PLANS.md"
    exit 1
  fi
  echo "  ✓ Created .agent/PLANS.md"
fi
```

**Step 5: Create .claude Directory and settings.local.json**

Create the .claude directory:
```bash
mkdir -p "$TARGET_DIR/.claude"
```

Create or update the settings.local.json file:

```bash
SETTINGS_FILE="$TARGET_DIR/.claude/settings.local.json"

if [ -f "$SETTINGS_FILE" ]; then
  # File exists - check if SessionStart hooks are present
  if grep -q "Local Preferences from Claude.local.md" "$SETTINGS_FILE"; then
    echo "  ✓ settings.local.json already has SessionStart hooks configured"
  else
    echo "  ⚠ settings.local.json exists but is missing SessionStart hooks"
    echo "  📝 Adding SessionStart hooks automatically..."

    # Use Python to merge JSON (Python is almost always available)
    python3 - "$SETTINGS_FILE" << 'PYTHON_SCRIPT'
import json
import sys

if len(sys.argv) < 2:
    print("  ✗ Error: settings file path not provided")
    sys.exit(1)

settings_file = sys.argv[1]

# Read existing settings
try:
    with open(settings_file, 'r') as f:
        settings = json.load(f)
except Exception as e:
    print(f"  ✗ Error reading settings file: {e}")
    sys.exit(1)

# Define SessionStart hooks
session_start_hooks = [
    {
        "hooks": [
            {
                "type": "command",
                "command": "if [ -f Agents.md ]; then echo '====================================' && echo 'Agent Behavior (Agents.md):' && echo '====================================' && cat Agents.md && echo '===================================='; fi"
            },
            {
                "type": "command",
                "command": "echo '' && echo '====================================' && echo 'Local Preferences (Claude.local.md):' && echo '====================================' && cat Claude.local.md && echo '===================================='"
            },
            {
                "type": "command",
                "command": "if [ -f .agent/PLANS.md ]; then echo '' && echo '====================================' && echo 'ExecPlan Guidelines (.agent/PLANS.md):' && echo '====================================' && echo 'Detailed ExecPlan authoring guidelines available at .agent/PLANS.md' && echo 'Follow these guidelines when creating execution plans.' && echo '===================================='; fi"
            }
        ]
    }
]

# Add or update hooks section
if "hooks" not in settings:
    settings["hooks"] = {}

settings["hooks"]["SessionStart"] = session_start_hooks

# Write back to file
try:
    with open(settings_file, 'w') as f:
        json.dump(settings, f, indent=2)
    print("  ✓ SessionStart hooks added successfully")
except Exception as e:
    print(f"  ✗ Error writing settings file: {e}")
    sys.exit(1)
PYTHON_SCRIPT

    if [ $? -ne 0 ]; then
      echo "  ✗ Failed to add SessionStart hooks"
      exit 1
    fi
  fi
else
  # File doesn't exist - copy from template
  cp "$SKILL_DIR/templates/settings.local.json" "$SETTINGS_FILE"

  if [ ! -f "$SETTINGS_FILE" ]; then
    echo "ERROR: Failed to create .claude/settings.local.json"
    exit 1
  fi
  echo "  ✓ Created .claude/settings.local.json with SessionStart hooks"
fi
```

**Step 6: Update .gitignore**

Check if .gitignore exists and update it:

```bash
if [ ! -f "$TARGET_DIR/.gitignore" ]; then
  echo "Creating new .gitignore file..."
  cat > "$TARGET_DIR/.gitignore" << 'EOF'
# Claude Code local settings
.claude/
*.local.json
Agents.md
Claude.local.md
.agent/

# Operating System files
.DS_Store
Thumbs.db
EOF
  echo "  ✓ Created .gitignore"
else
  echo "Updating existing .gitignore file..."

  # Add Claude Code section if not present
  if ! grep -q "# Claude Code local settings" "$TARGET_DIR/.gitignore"; then
    cat >> "$TARGET_DIR/.gitignore" << 'EOF'

# Claude Code local settings
.claude/
*.local.json
Agents.md
Claude.local.md
.agent/
EOF
    echo "  ✓ Updated .gitignore"
  else
    echo "  ℹ Claude Code entries already in .gitignore - skipping"
  fi
fi
```

**Step 7: Verify .gitignore was updated**

```bash
if [ ! -f "$TARGET_DIR/.gitignore" ]; then
  echo "ERROR: .gitignore was not created"
  exit 1
fi
```

**Step 8: Report Success**

```bash
echo ""
echo "=========================================="
echo "Team AI Initialization Complete!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✓ Agents.md (core agent behavior & ExecPlan usage)"
echo "  ✓ Claude.local.md (local preferences)"
echo "  ✓ .claude/settings.local.json (hooks & permissions)"
echo "  ✓ .agent/PLANS.md (detailed ExecPlan guidelines)"
echo "  ✓ .gitignore (updated with local files)"
echo ""
echo "Next steps:"
echo "  1. Customize Agents.md and Claude.local.md for your preferences"
echo "  2. Add more permissions to .claude/settings.local.json as needed"
echo "  3. Start a new Claude session to load the configuration"
echo ""
echo "These files are gitignored and will not be committed."
echo "=========================================="
```

## Implementation Notes

- **Templates**: All file content is stored in `$SKILL_DIR/templates/` directory
  - `templates/Agents.md` - Core agent behavior and ExecPlan usage template
  - `templates/Claude.local.md` - Local preferences template
  - `templates/PLANS.md` - Detailed ExecPlan authoring guidelines template
  - `templates/settings.local.json` - Default settings with hooks and permissions
- **Performance**: Files are copied instantly using `cp` command - no AI processing required
- **Idempotency**: Running the skill multiple times is safe - existing files are preserved
- **Error Handling**: All file creation operations are validated with error checks
- **Smart Handling**:
  - Agents.md: Copied from template if doesn't exist (preserves user customizations if exists)
  - Claude.local.md: Copied from template if doesn't exist (preserves user preferences if exists)
  - .agent/PLANS.md: Copied from template if doesn't exist (preserves customizations if exists)
  - settings.local.json:
    - If doesn't exist: Copied from template (permissions + hooks)
    - If exists with SessionStart hooks: Skips (preserves user config)
    - If exists without SessionStart hooks: **Automatically adds them using Python** (critical for system to work)
- **JSON Merging**: Uses Python 3 (almost always available) to properly parse and merge JSON - no external dependencies required
- **User Permissions Preserved**: Only SessionStart hooks are added or updated, existing permissions and other hooks are preserved
- All created files are automatically gitignored to prevent accidental commits
- The settings.local.json includes basic safe read-only commands in the allow list
- The SessionStart hooks will display both Claude.local.md and notify about PLANS.md
- The .agent directory is kept local to avoid conflicts in team environments
- Users can customize these files per their workflow needs

## Usage Examples

From a new project directory:
```bash
/init-team-ai
```

From Claude Code, initializing a specific directory:
```bash
/init-team-ai /path/to/project
```
