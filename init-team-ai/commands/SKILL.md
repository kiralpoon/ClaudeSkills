---
name: init-team-ai
description: Initialize a new project with team AI configuration files
argument-hint: [project-path (optional, defaults to current directory)]
allowed-tools: Read(*), Bash(mkdir:*), Bash(cp:*), Bash(cat:*), Bash(echo:*), Bash(grep:*), Bash(git:*), Bash(command:*), Bash(python3:*), Bash(chmod:*), Bash(touch:*)
---

# Initialize Team AI Project

This skill sets up a new project for team AI collaboration by creating:
1. `Agents.md` - Core agent behavior and ExecPlan usage guidelines (gitignored)
2. `Claude.local.md` - Local preferences file (gitignored)
3. `.claude/settings.local.json` - Local settings with SessionStart hooks
4. `.agent/PLANS.md` - Detailed ExecPlan authoring guidelines (gitignored)
5. Updated `.gitignore` - Ensures local files are not committed
6. `.agent/TEAM.md` - Team AI communication protocol (committed)
7. `.agent/templates/` - Task and deliberation templates for Mode A pipeline (committed)
8. `.agent/templates/` - Perspective templates for Mode B multi-review (committed)
9. `scripts/start-team.sh` - tmux layout launcher for agent panes
10. `.gemini/settings.json` - Gemini CLI Chrome MCP config (gitignored, per-developer)
11. `.codex/config.toml` - Codex CLI Chrome MCP config (gitignored, per-developer)

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

**Target execution time: under 30 seconds total**

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

**Step 2: Create or Update Agents.md**

If the file doesn't exist, copy from template. If it exists and has section markers, merge template sections while preserving user content outside markers. If it exists without markers, use `claude -p` to smart-merge — preserving all user content and appending only genuinely missing template sections (with a simple append fallback if `claude -p` is unavailable).

```bash
if [ ! -f "$TARGET_DIR/Agents.md" ]; then
  cp "$SKILL_DIR/templates/Agents.md" "$TARGET_DIR/Agents.md"
  if [ ! -f "$TARGET_DIR/Agents.md" ]; then
    echo "ERROR: Failed to create Agents.md"
    exit 1
  fi
  echo "  ✓ Created Agents.md"
else
  python3 "$SKILL_DIR/merge_sections.py" "$TARGET_DIR/Agents.md" "$SKILL_DIR/templates/Agents.md"
  if [ $? -ne 0 ]; then
    echo "  ✗ Failed to merge Agents.md"
    exit 1
  fi
fi

# ClaudeSkills repo only: append Skill Development Research section
if git -C "$TARGET_DIR" remote -v 2>/dev/null | grep -q "ClaudeSkills"; then
  if ! grep -q "Skill Development Research" "$TARGET_DIR/Agents.md" 2>/dev/null; then
    cat >> "$TARGET_DIR/Agents.md" << 'RESEARCH_SECTION'

## Skill Development Research

When creating a new skill or updating an existing skill in this repository:

1. Browse https://github.com/affaan-m/everything-claude-code for similar skills or related tools
2. If a similar skill exists, present findings to the user and discuss:
   - What the external repo does differently
   - Strategies: adopt their approach, adapt it, or diverge
3. Incorporate learnings into the ExecPlan before implementation
RESEARCH_SECTION
    echo "  ✓ Added Skill Development Research section to Agents.md"
  else
    echo "  ℹ Skill Development Research section already exists in Agents.md"
  fi
fi
```

**Step 3: Create or Update Claude.local.md**

Same merge strategy as Agents.md — section markers are merged, user content outside markers is preserved.

```bash
if [ ! -f "$TARGET_DIR/Claude.local.md" ]; then
  cp "$SKILL_DIR/templates/Claude.local.md" "$TARGET_DIR/Claude.local.md"
  if [ ! -f "$TARGET_DIR/Claude.local.md" ]; then
    echo "ERROR: Failed to create Claude.local.md"
    exit 1
  fi
  echo "  ✓ Created Claude.local.md"
else
  python3 "$SKILL_DIR/merge_sections.py" "$TARGET_DIR/Claude.local.md" "$SKILL_DIR/templates/Claude.local.md"
  if [ $? -ne 0 ]; then
    echo "  ✗ Failed to merge Claude.local.md"
    exit 1
  fi
fi
```

**Step 4: Create .agent Directory and Create or Update PLANS.md**

Create the agent directory and copy/merge PLANS.md from template:

```bash
mkdir -p "$TARGET_DIR/.agent"
echo "  ✓ Created .agent directory"

if [ ! -f "$TARGET_DIR/.agent/PLANS.md" ]; then
  cp "$SKILL_DIR/templates/PLANS.md" "$TARGET_DIR/.agent/PLANS.md"
  if [ ! -f "$TARGET_DIR/.agent/PLANS.md" ]; then
    echo "ERROR: Failed to create .agent/PLANS.md"
    exit 1
  fi
  echo "  ✓ Created .agent/PLANS.md"
else
  python3 "$SKILL_DIR/merge_sections.py" "$TARGET_DIR/.agent/PLANS.md" "$SKILL_DIR/templates/PLANS.md"
  if [ $? -ne 0 ]; then
    echo "  ✗ Failed to merge .agent/PLANS.md"
    exit 1
  fi
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

# Merge allow permissions
if "allow" not in settings["permissions"]:
    settings["permissions"]["allow"] = []

template_allow = template.get("permissions", {}).get("allow", [])
existing_allow = settings["permissions"]["allow"]

# Add template allow permissions that don't exist yet
added_allow = []
for perm in template_allow:
    if perm not in existing_allow:
        existing_allow.append(perm)
        added_allow.append(perm)

# Merge deny permissions
if "deny" not in settings["permissions"]:
    settings["permissions"]["deny"] = []

template_deny = template.get("permissions", {}).get("deny", [])
existing_deny = settings["permissions"]["deny"]

# Add template deny permissions that don't exist yet
added_deny = []
for perm in template_deny:
    if perm not in existing_deny:
        existing_deny.append(perm)
        added_deny.append(perm)

# Report changes
if added_allow or added_deny:
    if added_allow:
        print(f"  ✓ Added {len(added_allow)} allow permissions from template")
    if added_deny:
        print(f"  ✓ Added {len(added_deny)} deny permissions from template (protects secrets)")
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

# Migration: replace blanket .agent/ with specific entries
migrated = False
for i, line in enumerate(existing_lines):
    if line.strip() == '.agent/':
        # Replace the single blanket line with two specific entries
        existing_lines[i] = '.agent/PLANS.md'
        existing_lines.insert(i + 1, '.agent/pipeline/')
        migrated = True
        break

if migrated:
    # Rewrite the file with the replacement applied
    with open(gitignore_file, 'w') as f:
        f.write('\n'.join(existing_lines) + '\n')
    print("  ✓ Migrated .agent/ → .agent/PLANS.md + .agent/pipeline/")
    print("    (.agent/TEAM.md, .agent/templates/, .agent/reviews/ are now tracked by git)")

# Check which template entries are missing (rebuild set after potential migration)
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

**Step 8: Core Files Complete**

```bash
echo ""
echo "  ── Core files created. Setting up Team AI pipeline... ──"
echo ""
```

**Step 9: Create Team AI Directories**

Create the pipeline, templates, and reviews directories. Add `.gitkeep` files so git tracks the committed directories:

```bash
mkdir -p "$TARGET_DIR/.agent/pipeline" "$TARGET_DIR/.agent/templates" "$TARGET_DIR/.agent/reviews"

# .gitkeep ensures git tracks templates/ and reviews/ even when empty
# (pipeline/.gitkeep exists locally but is gitignored — that's fine)
for dir in pipeline templates reviews; do
  if [ ! -f "$TARGET_DIR/.agent/$dir/.gitkeep" ]; then
    touch "$TARGET_DIR/.agent/$dir/.gitkeep"
  fi
done
echo "  ✓ Created .agent/pipeline/, .agent/templates/, .agent/reviews/"
```

**Step 10: Copy TEAM.md (always overwrite)**

```bash
VERB="Created"
[ -f "$TARGET_DIR/.agent/TEAM.md" ] && VERB="Updated"
cp "$SKILL_DIR/templates/team-ai/TEAM.md" "$TARGET_DIR/.agent/TEAM.md"
echo "  ✓ $VERB .agent/TEAM.md (communication protocol)"
```

**Step 11: Copy Mode A Task Templates (always overwrite)**

Copy the six Mode A pipeline templates (build, fix, UX review, code review, deliberation):

```bash
MODE_A_FILES="build-task.md fix-task.md ux-task.md review-task.md ux-deliberation.md review-deliberation.md"

for file in $MODE_A_FILES; do
  VERB="Created"
  [ -f "$TARGET_DIR/.agent/templates/$file" ] && VERB="Updated"
  cp "$SKILL_DIR/templates/team-ai/$file" "$TARGET_DIR/.agent/templates/$file"
  echo "  ✓ $VERB .agent/templates/$file"
done
```

**Step 12: Copy start-team.sh (always overwrite)**

```bash
mkdir -p "$TARGET_DIR/scripts"

VERB="Created"
[ -f "$TARGET_DIR/scripts/start-team.sh" ] && VERB="Updated"
cp "$SKILL_DIR/templates/team-ai/start-team.sh" "$TARGET_DIR/scripts/start-team.sh"
chmod +x "$TARGET_DIR/scripts/start-team.sh"
echo "  ✓ $VERB scripts/start-team.sh (tmux layout launcher)"
```

**Step 13: Create or Merge Gemini CLI Config**

```bash
mkdir -p "$TARGET_DIR/.gemini"

if [ -f "$TARGET_DIR/.gemini/settings.json" ]; then
  echo "  📝 Merging .gemini/settings.json from template..."

  python3 - "$TARGET_DIR/.gemini/settings.json" "$SKILL_DIR/templates/team-ai/gemini-settings.json" << 'PYTHON_SCRIPT'
import json, sys

existing_file, template_file = sys.argv[1], sys.argv[2]

with open(existing_file, 'r') as f:
    existing = json.load(f)
with open(template_file, 'r') as f:
    template = json.load(f)

if "mcpServers" not in existing:
    existing["mcpServers"] = {}

added = []
for name, config in template.get("mcpServers", {}).items():
    if name not in existing["mcpServers"]:
        existing["mcpServers"][name] = config
        added.append(name)

if added:
    print(f"  ✓ Added MCP servers from template: {', '.join(added)}")
else:
    print("  ✓ All template MCP servers already present")

with open(existing_file, 'w') as f:
    json.dump(existing, f, indent=2)
    f.write('\n')
PYTHON_SCRIPT

  if [ $? -ne 0 ]; then
    echo "  ✗ Failed to merge .gemini/settings.json"
    exit 1
  fi
else
  cp "$SKILL_DIR/templates/team-ai/gemini-settings.json" "$TARGET_DIR/.gemini/settings.json"
  echo "  ✓ Created .gemini/settings.json (Chrome MCP for Gemini)"
fi
```

**Step 14: Create or Merge Codex CLI Config**

```bash
mkdir -p "$TARGET_DIR/.codex"

if [ -f "$TARGET_DIR/.codex/config.toml" ]; then
  echo "  📝 Merging .codex/config.toml from template..."

  python3 - "$TARGET_DIR/.codex/config.toml" "$SKILL_DIR/templates/team-ai/codex-config.toml" << 'PYTHON_SCRIPT'
import re, sys

existing_file, template_file = sys.argv[1], sys.argv[2]

with open(existing_file, 'r') as f:
    existing_text = f.read()
with open(template_file, 'r') as f:
    template_text = f.read()

# Parse [mcp_servers.NAME] section names from existing file
existing_sections = set(re.findall(r'^\[mcp_servers\.(\w+)\]', existing_text, re.MULTILINE))

# Split template into blocks (each starts with [mcp_servers.NAME])
template_blocks = re.split(r'(?=^\[mcp_servers\.)', template_text, flags=re.MULTILINE)
template_blocks = [b for b in template_blocks if b.strip()]

added = []
for block in template_blocks:
    match = re.match(r'^\[mcp_servers\.(\w+)\]', block)
    if match:
        name = match.group(1)
        if name not in existing_sections:
            # Append with a blank line separator
            if not existing_text.endswith('\n\n'):
                existing_text = existing_text.rstrip('\n') + '\n\n'
            existing_text += block.rstrip('\n') + '\n'
            added.append(name)

if added:
    with open(existing_file, 'w') as f:
        f.write(existing_text)
    print(f"  ✓ Added MCP servers from template: {', '.join(added)}")
else:
    print("  ✓ All template MCP servers already present")
PYTHON_SCRIPT

  if [ $? -ne 0 ]; then
    echo "  ✗ Failed to merge .codex/config.toml"
    exit 1
  fi
else
  cp "$SKILL_DIR/templates/team-ai/codex-config.toml" "$TARGET_DIR/.codex/config.toml"
  echo "  ✓ Created .codex/config.toml (Chrome MCP for Codex)"
fi
```

**Step 15: Verify Codex CLI Readiness**

```bash
echo ""
echo "--- CLI Readiness Check ---"

if command -v codex >/dev/null 2>&1; then
  CODEX_VERSION=$(codex --version 2>&1 | head -1)
  echo "  ✓ codex CLI found: $CODEX_VERSION"
else
  echo "  ⚠ codex CLI not found. Code Reviewer will not work."
  echo "    Install from: https://github.com/openai/codex"
  echo "    Then run: codex auth login"
fi
```

**Step 16: Verify Gemini CLI Readiness**

```bash
if command -v gemini >/dev/null 2>&1; then
  GEMINI_VERSION=$(gemini --version 2>&1 | head -1)
  echo "  ✓ gemini CLI found: $GEMINI_VERSION"
else
  echo "  ⚠ gemini CLI not found. UI/UX Reviewer will not work."
  echo "    Install from: https://github.com/google-gemini/gemini-cli"
  echo "    Then run: gemini auth login"
fi

echo "---"
```

**Step 17: Copy Mode B Perspective Templates (always overwrite)**

```bash
MODE_B_FILES="perspective-ux.md perspective-arch.md perspective-devil.md review-synthesis.md"

for file in $MODE_B_FILES; do
  VERB="Created"
  [ -f "$TARGET_DIR/.agent/templates/$file" ] && VERB="Updated"
  cp "$SKILL_DIR/templates/team-ai/$file" "$TARGET_DIR/.agent/templates/$file"
  echo "  ✓ $VERB .agent/templates/$file"
done
```

**Step 18: Report Success**

```bash
echo ""
echo "=========================================="
echo "Team AI Initialization Complete!"
echo "=========================================="
echo ""
echo "Core files:"
echo "  ✓ Agents.md (core agent behavior & ExecPlan usage)"
echo "  ✓ Claude.local.md (local preferences)"
echo "  ✓ .claude/settings.local.json (hooks & permissions)"
echo "  ✓ .agent/PLANS.md (detailed ExecPlan guidelines)"
echo "  ✓ .gitignore (updated with local files)"
echo ""
echo "Team AI pipeline (Mode A — build→review):"
echo "  ✓ .agent/TEAM.md (communication protocol)"
echo "  ✓ .agent/templates/ (6 task & deliberation templates)"
echo "  ✓ scripts/start-team.sh (tmux layout launcher)"
echo "Team AI review (Mode B — multi-perspective):"
echo "  ✓ .agent/templates/ (4 perspective & synthesis templates)"
echo ""
echo "Agent CLI configs (per-developer, gitignored):"
echo "  ✓ .gemini/settings.json (Chrome MCP for Gemini)"
echo "  ✓ .codex/config.toml (Chrome MCP for Codex)"
echo ""
echo "Next steps:"
echo "  1. Install CLIs: codex (https://github.com/openai/codex)"
echo "     gemini (https://github.com/google-gemini/gemini-cli)"
echo "  2. Authenticate: codex auth login && gemini auth login"
echo "  3. Install Chrome MCP: /chrome-mcp (for browser testing)"
echo "  4. Start a new Claude session to load the configuration"
echo "  5. Use /team-ai to run the pipeline"
echo ""
echo "=========================================="
```

## Implementation Notes

- **Templates**: All file content is stored in `$SKILL_DIR/templates/` directory
  - `templates/Agents.md` - Core agent behavior and ExecPlan usage template
  - `templates/Claude.local.md` - Local preferences template
  - `templates/PLANS.md` - Detailed ExecPlan authoring guidelines template
  - `templates/settings.local.json` - Default settings with hooks and permissions
  - `templates/.gitignore` - Gitignore entries for Claude Code local files
  - `templates/team-ai/TEAM.md` - Communication protocol
  - `templates/team-ai/build-task.md` - Builder initial task template
  - `templates/team-ai/fix-task.md` - Builder revision round template
  - `templates/team-ai/ux-task.md` - UI/UX review task template
  - `templates/team-ai/review-task.md` - Code review task template
  - `templates/team-ai/ux-deliberation.md` - UX deliberation template
  - `templates/team-ai/review-deliberation.md` - Code review deliberation template
  - `templates/team-ai/start-team.sh` - tmux layout launcher
  - `templates/team-ai/gemini-settings.json` - Gemini Chrome MCP config
  - `templates/team-ai/codex-config.toml` - Codex Chrome MCP config
  - `templates/team-ai/perspective-ux.md` - Mode B UX perspective
  - `templates/team-ai/perspective-arch.md` - Mode B architecture perspective
  - `templates/team-ai/perspective-devil.md` - Mode B devil's advocate
  - `templates/team-ai/review-synthesis.md` - Mode B synthesis prompt
- **Performance**: Files are copied instantly using `cp` command - no AI processing required
- **Idempotency**: Running the skill multiple times is safe - template updates propagate via section merge, user content is preserved
- **Error Handling**: All file creation operations are validated with error checks
- **Update Strategy** (3 categories):
  - **Category A (always overwrite)**: TEAM.md, task templates, start-team.sh, Mode B templates — fully template-owned, always copied fresh from template.
  - **Category B (section merge)**: Agents.md, Claude.local.md, PLANS.md — template sections wrapped in `<!-- BEGIN/END TEMPLATE: name -->` markers are replaced on re-run; user content outside markers is preserved. Files without markers are smart-merged via `claude -p` (user content preserved, only genuinely missing sections appended); falls back to a simple append if `claude -p` is unavailable.
  - **Category C (smart merge)**: settings.local.json, .gitignore, .gemini/settings.json, .codex/config.toml — custom merge logic preserves user additions while ensuring template entries are present.
- **Section Merging**: `$SKILL_DIR/merge_sections.py` handles marker-based merge for Category B files — single source of truth, no duplication
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
