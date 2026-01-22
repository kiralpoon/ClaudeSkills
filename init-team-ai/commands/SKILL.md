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
TEMPLATE_FILE="$SKILL_DIR/templates/settings.local.json"

if [ -f "$SETTINGS_FILE" ]; then
  # File exists - merge permissions and hooks from template
  echo "  📝 Merging settings from template..."

  # Use Python to merge JSON (Python is almost always available)
  python3 - "$SETTINGS_FILE" "$TEMPLATE_FILE" << 'PYTHON_SCRIPT'
import json
import sys

if len(sys.argv) < 3:
    print("  ✗ Error: settings file paths not provided")
    sys.exit(1)

settings_file = sys.argv[1]
template_file = sys.argv[2]

# Read existing settings
try:
    with open(settings_file, 'r') as f:
        settings = json.load(f)
except Exception as e:
    print(f"  ✗ Error reading settings file: {e}")
    sys.exit(1)

# Read template settings
try:
    with open(template_file, 'r') as f:
        template = json.load(f)
except Exception as e:
    print(f"  ✗ Error reading template file: {e}")
    sys.exit(1)

# Merge permissions - add template permissions to existing (preserving user additions)
if "permissions" not in settings:
    settings["permissions"] = {}

if "allow" not in settings["permissions"]:
    settings["permissions"]["allow"] = []

template_allow = template.get("permissions", {}).get("allow", [])
existing_allow = settings["permissions"]["allow"]

# Add template permissions that don't exist yet
added_permissions = []
for perm in template_allow:
    if perm not in existing_allow:
        existing_allow.append(perm)
        added_permissions.append(perm)

if added_permissions:
    print(f"  ✓ Added {len(added_permissions)} permissions from template")
else:
    print("  ✓ All template permissions already present")

# Merge hooks - update SessionStart hooks from template
template_hooks = template.get("hooks", {}).get("SessionStart", [])
if template_hooks:
    if "hooks" not in settings:
        settings["hooks"] = {}
    settings["hooks"]["SessionStart"] = template_hooks
    print("  ✓ SessionStart hooks updated from template")

# Write back to file
try:
    with open(settings_file, 'w') as f:
        json.dump(settings, f, indent=2)
    print("  ✓ Settings merged successfully")
except Exception as e:
    print(f"  ✗ Error writing settings file: {e}")
    sys.exit(1)
PYTHON_SCRIPT

  if [ $? -ne 0 ]; then
    echo "  ✗ Failed to merge settings"
    exit 1
  fi
else
  # File doesn't exist - copy from template
  cp "$TEMPLATE_FILE" "$SETTINGS_FILE"

  if [ ! -f "$SETTINGS_FILE" ]; then
    echo "ERROR: Failed to create .claude/settings.local.json"
    exit 1
  fi
  echo "  ✓ Created .claude/settings.local.json with hooks and permissions"
fi
```

**Step 6: Update .gitignore**

Merge .gitignore entries from template (preserves existing entries, adds missing ones):

```bash
GITIGNORE_FILE="$TARGET_DIR/.gitignore"
GITIGNORE_TEMPLATE="$SKILL_DIR/templates/.gitignore"

if [ ! -f "$GITIGNORE_FILE" ]; then
  # File doesn't exist - copy from template
  cp "$GITIGNORE_TEMPLATE" "$GITIGNORE_FILE"
  echo "  ✓ Created .gitignore from template"
else
  # File exists - merge entries from template
  echo "  📝 Merging .gitignore entries from template..."

  # Use Python to merge gitignore entries properly
  python3 - "$GITIGNORE_FILE" "$GITIGNORE_TEMPLATE" << 'PYTHON_SCRIPT'
import sys

if len(sys.argv) < 3:
    print("  ✗ Error: file paths not provided")
    sys.exit(1)

gitignore_file = sys.argv[1]
template_file = sys.argv[2]

# Read existing gitignore
try:
    with open(gitignore_file, 'r') as f:
        existing_lines = f.read().splitlines()
except Exception as e:
    print(f"  ✗ Error reading gitignore: {e}")
    sys.exit(1)

# Read template
try:
    with open(template_file, 'r') as f:
        template_lines = f.read().splitlines()
except Exception as e:
    print(f"  ✗ Error reading template: {e}")
    sys.exit(1)

# Get non-empty, non-comment entries from template
template_entries = [line for line in template_lines if line.strip() and not line.strip().startswith('#')]

# Check which template entries are missing
existing_set = set(line.strip() for line in existing_lines)
missing_entries = [entry for entry in template_entries if entry.strip() not in existing_set]

if not missing_entries:
    print("  ✓ All template entries already present in .gitignore")
    sys.exit(0)

# Append missing entries with a section header
try:
    with open(gitignore_file, 'a') as f:
        # Add newline if file doesn't end with one
        if existing_lines and existing_lines[-1].strip():
            f.write('\n')
        f.write('\n# Claude Code local settings (added by init-team-ai)\n')
        for entry in missing_entries:
            f.write(entry + '\n')
    print(f"  ✓ Added {len(missing_entries)} entries to .gitignore")
except Exception as e:
    print(f"  ✗ Error writing gitignore: {e}")
    sys.exit(1)
PYTHON_SCRIPT

  if [ $? -ne 0 ]; then
    echo "  ✗ Failed to merge .gitignore"
    exit 1
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
  - `templates/.gitignore` - Gitignore entries for Claude Code local files
- **Performance**: Files are copied instantly using `cp` command - no AI processing required
- **Idempotency**: Running the skill multiple times is safe - existing files are preserved
- **Error Handling**: All file creation operations are validated with error checks
- **Smart Handling**:
  - Agents.md: Copied from template if doesn't exist (preserves user customizations if exists)
  - Claude.local.md: Copied from template if doesn't exist (preserves user preferences if exists)
  - .agent/PLANS.md: Copied from template if doesn't exist (preserves customizations if exists)
  - settings.local.json:
    - If doesn't exist: Copied from template (permissions + hooks)
    - If exists: **Merges permissions and hooks from template** (preserves user additions)
- **JSON Merging**: Uses Python 3 (almost always available) to properly parse and merge JSON - no external dependencies required
- **Permission Merging**: Template permissions are added to existing permissions (user additions are preserved, template permissions are ensured)
- **Gitignore Merging**: Template entries are added to existing .gitignore (user entries preserved, missing template entries added)
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
