#!/bin/bash
# start-team.sh — Launch the team-ai pane layout
#
# Usage: bash start-team.sh [working-directory]
#
# Detects the current environment and adapts:
#   - If already inside tmux: creates a new window "team-ai" in the current session
#   - If NOT in tmux: creates a new tmux session "team-ai"
#
# Pane layout (2x2 grid in the team-ai window):
#   ┌──────────────────────┬──────────────────────┐
#   │  Builder             │  Code Reviewer       │
#   │  (claude -p)         │  (codex --full-auto)  │
#   ├──────────────────────┼──────────────────────┤
#   │  UI/UX Reviewer      │  Status Monitor      │
#   │  (gemini -y)         │                      │
#   └──────────────────────┴──────────────────────┘
#
# The Team Lead (Claude Code) stays in its original pane and targets
# these panes via their stable %N pane IDs stored in SESSION.json.
#
# Navigation (when using window mode inside tmux):
#   Ctrl+B n  — switch to team-ai window (see agents working)
#   Ctrl+B p  — switch back to your window (talk to Team Lead)
#
# Pane IDs are saved to .agent/pipeline/SESSION.json for stable targeting.
# If the team-ai layout already exists, this script exits without changes.
#
# PREREQUISITES: Each CLI tool must be installed and logged in before use.
# Auth: Claude and Codex use subscription auth (~/.claude/, ~/.codex/).
# Gemini uses OAuth — run `gemini auth login` before first use.
# The Team Lead verifies auth status at pipeline start (preflight check).

set -e

WORK_DIR="${1:-$(pwd)}"
WINDOW_NAME="team-ai"
SESSION_NAME="team-ai"

# Verify prerequisites
if ! command -v tmux >/dev/null 2>&1; then
    echo "✗ tmux not found. Install with: sudo apt install tmux  (or brew install tmux)"
    exit 1
fi

if [ ! -f "$WORK_DIR/scripts/monitor.sh" ]; then
    echo "✗ scripts/monitor.sh not found in $WORK_DIR"
    echo "  Run /init-team-ai first to scaffold the pipeline infrastructure."
    exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
    echo "⚠ codex CLI not found. Code Reviewer pane will show an error."
    echo "  Install from: https://github.com/openai/codex"
fi

if ! command -v gemini >/dev/null 2>&1; then
    echo "⚠ gemini CLI not found. UI/UX Reviewer pane will show an error."
    echo "  Install from: https://github.com/google-gemini/gemini-cli"
    echo "  Then run: gemini auth login"
fi

# --- Detect environment and choose mode ---
#
# If $TMUX is set, we're already inside a tmux session.
# Create a new window in the current session (Option 3 — no context switch).
# Otherwise, create a standalone session (Option 1 — fallback).

if [ -n "$TMUX" ]; then
    MODE="window"
    CURRENT_SESSION=$(tmux display-message -p '#{session_name}')

    # Check if team-ai window already exists in current session
    if tmux list-windows -t "$CURRENT_SESSION" -F '#{window_name}' 2>/dev/null | grep -q "^${WINDOW_NAME}$"; then
        echo "ℹ team-ai window already exists in session '$CURRENT_SESSION' — leaving it as-is"
        echo "  Pane IDs in .agent/pipeline/SESSION.json are still valid."
        echo "  Switch to it with: Ctrl+B n (or select window '$WINDOW_NAME')"
        exit 0
    fi
else
    MODE="session"

    # Check if team-ai session already exists
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "ℹ team-ai session already running — leaving it as-is"
        echo "  Pane IDs in .agent/pipeline/SESSION.json are still valid."
        echo "  Attach with: tmux attach -t $SESSION_NAME"
        exit 0
    fi
fi

# --- Create panes ---

if [ "$MODE" = "window" ]; then
    # Window mode: new window in current session
    # The first pane of the new window becomes the Builder.
    BUILDER_ID=$(tmux new-window -n "$WINDOW_NAME" -c "$WORK_DIR" -PF '#{pane_id}')
    TARGET_SESSION="$CURRENT_SESSION"
else
    # Session mode: new detached session
    # The first pane of the new session becomes the Builder.
    BUILDER_ID=$(tmux new-session -d -s "$SESSION_NAME" -c "$WORK_DIR" -x 220 -y 50 -PF '#{pane_id}')
    TARGET_SESSION="$SESSION_NAME"
fi

# Split into 2x2 grid
# Top-left: Builder (already created above)
# Bottom-left: UI/UX Reviewer (split Builder vertically)
UX_ID=$(tmux split-window -v -t "$BUILDER_ID" -c "$WORK_DIR" -PF '#{pane_id}')

# Top-right: Code Reviewer (split Builder horizontally)
REVIEWER_ID=$(tmux split-window -h -t "$BUILDER_ID" -c "$WORK_DIR" -PF '#{pane_id}')

# Bottom-right: Status Monitor (split UX Reviewer horizontally)
MONITOR_ID=$(tmux split-window -h -t "$UX_ID" -c "$WORK_DIR" -PF '#{pane_id}')

# Give panes semantic titles for human readability
tmux select-pane -t "$BUILDER_ID"  -T "Builder (claude -p)"
tmux select-pane -t "$UX_ID"       -T "UI/UX Reviewer (Gemini)"
tmux select-pane -t "$REVIEWER_ID" -T "Code Reviewer (Codex)"
tmux select-pane -t "$MONITOR_ID"  -T "Status Monitor"

# Ensure pipeline directories exist
mkdir -p "$WORK_DIR/.agent/pipeline"

# Write SESSION.json with stable pane IDs
# The "mode" field tells the SKILL.md how panes were created (for cleanup).
# The "lead" pane is filled in by SKILL.md after this script returns.
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "$WORK_DIR/.agent/pipeline/SESSION.json" <<EOF
{
  "session": "$TARGET_SESSION",
  "window": "$WINDOW_NAME",
  "mode": "$MODE",
  "created_at": "$TIMESTAMP",
  "panes": {
    "lead":     "(set by SKILL.md after session creation)",
    "builder":  "$BUILDER_ID",
    "ux":       "$UX_ID",
    "reviewer": "$REVIEWER_ID",
    "monitor":  "$MONITOR_ID"
  }
}
EOF
echo "✓ SESSION.json written with pane IDs"

# Launch agents in interactive mode with auto-approve
# Builder: Claude interactive mode (persistent, like Gemini and Codex)
tmux send-keys -t "$BUILDER_ID" "claude" Enter

# UI/UX Reviewer: Gemini interactive with yolo mode (auto-approve all tools)
tmux send-keys -t "$UX_ID" "gemini -y" Enter

# Code Reviewer: Codex interactive with full-auto (auto-approve + sandbox write)
tmux send-keys -t "$REVIEWER_ID" "codex --full-auto" Enter

# Status monitor — active watcher that detects handoff files and updates STATUS.json
# Uses scripts/monitor.sh rather than a passive `watch` display.
tmux send-keys -t "$MONITOR_ID" "bash scripts/monitor.sh" Enter

# Focus the builder pane
tmux select-pane -t "$BUILDER_ID"

# Switch back to the original window so the Team Lead isn't staring at
# the agent panes. Only relevant in window mode — in session mode the
# user is already in their original terminal.
if [ "$MODE" = "window" ]; then
    tmux last-window
fi

echo "✓ team-ai panes created (mode: $MODE)."
echo ""
echo "  Pane IDs:"
echo "    Builder       (claude -p): $BUILDER_ID"
echo "    UI/UX Reviewer (Gemini):   $UX_ID"
echo "    Code Reviewer  (Codex):    $REVIEWER_ID"
echo "    Status Monitor:            $MONITOR_ID"
echo ""
if [ "$MODE" = "window" ]; then
    echo "  View agents: Ctrl+B n  (next window)"
    echo "  Return here: Ctrl+B p  (previous window)"
else
    echo "  View agents: tmux attach -t $SESSION_NAME"
fi
echo ""
echo "  The Team Lead (Claude Code) runs in your original pane."
