#!/bin/bash
# scripts/monitor.sh — Active pipeline monitor for team-ai
#
# Polls for handoff files every 2 seconds, updates STATUS.json automatically
# when agents finish, and displays live pipeline state.
#
# Runs in the Status Monitor pane (started by scripts/start-team.sh).
# The Team Lead no longer needs to manually update STATUS.json for verdicts —
# this script does it as soon as a handoff file appears.

PIPELINE_DIR=".agent/pipeline"

# Track processed handoffs in a temp file (bash 3 compatible, no associative arrays)
PROCESSED_FILE="/tmp/team-ai-monitor-processed-$$"
touch "$PROCESSED_FILE"
trap "rm -f $PROCESSED_FILE" EXIT

# --- Helpers ---

update_status() {
    local field="$1" value="$2"
    local status_file="$PIPELINE_DIR/STATUS.json"
    [ -f "$status_file" ] || return

    FIELD="$field" VALUE="$value" python3 -W ignore - "$status_file" << 'PYEOF'
import json, sys, os, datetime
path = sys.argv[1]
with open(path) as f:
    s = json.load(f)
s[os.environ['FIELD']] = os.environ['VALUE']
s['updated_at'] = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
with open(path, 'w') as f:
    json.dump(s, f, indent=2)
PYEOF
}

strip_verdict() {
    # Remove markdown formatting (bold **, italic *, backticks) and all whitespace
    # Keeps only ALLCAPS_WITH_UNDERSCORES — the verdict token itself
    echo "$1" | sed 's/\*\*//g; s/\*//g; s/`//g' | grep -oE '[A-Z][A-Z_]+' | head -1
}

parse_verdict_mode_a() {
    # Verdict: APPROVED  or  Verdict: NEEDS_REVISION
    local raw
    raw=$(grep -i "^Verdict:" "$1" 2>/dev/null | head -1 \
        | sed 's/^[Vv]erdict:[[:space:]]*//')
    strip_verdict "$raw"
}

parse_verdict_mode_b() {
    # Matches:
    #   ## Overall UX Verdict\n**STRONG**
    #   ## Verdict\n**VIABLE_WITH_CAVEATS**
    local verdict
    verdict=$(grep -A5 -E "^## (Overall|Verdict)" "$1" 2>/dev/null \
        | grep -v -E "^## (Overall|Verdict)" | grep -v "^[[:space:]]*$" | head -1)
    verdict=$(strip_verdict "$verdict")
    # Fallback to Mode A style if no heading found
    [ -z "$verdict" ] && verdict=$(parse_verdict_mode_a "$1")
    echo "$verdict"
}

process_handoff() {
    local file="$1" field="$2" mode="${3:-a}"
    local filepath="$PIPELINE_DIR/$file"

    [ -f "$filepath" ] || return
    grep -qF "$file" "$PROCESSED_FILE" 2>/dev/null && return  # already handled
    echo "$file" >> "$PROCESSED_FILE"

    local verdict
    if [ "$mode" = "b" ]; then
        verdict=$(parse_verdict_mode_b "$filepath")
    else
        verdict=$(parse_verdict_mode_a "$filepath")
    fi
    [ -z "$verdict" ] && verdict="unknown"

    local val
    val=$(echo "$verdict" | tr '[:upper:]' '[:lower:]')
    update_status "$field" "$val"

    local ts
    ts=$(date '+%H:%M:%S')
    printf "  [%s] ✓ %-28s → %s=%s\n" "$ts" "$file" "$field" "$val"
    echo "[$ts] monitor: $file → $field=$val" >> "$PIPELINE_DIR/pipeline.log" 2>/dev/null
}

show_status() {
    if [ ! -f "$PIPELINE_DIR/STATUS.json" ]; then
        printf "  (no STATUS.json yet)\n"; return
    fi
    python3 - "$PIPELINE_DIR/STATUS.json" << 'PYEOF' 2>/dev/null
import json, sys
try:
    with open(sys.argv[1]) as f:
        s = json.load(f)
    w = 10
    print(f"  {'stage':<{w}} {s.get('stage','?')}")
    print(f"  {'activity':<{w}} {s.get('activity_state','?')}")
    print(f"  {'agent':<{w}} {s.get('active_agent','?')}")
    print(f"  {'round':<{w}} {s.get('loop_round',0)}")
    print(f"  {'build':<{w}} {s.get('build_verdict','?')}")
    print(f"  {'ux':<{w}} {s.get('ux_verdict','?')}")
    print(f"  {'review':<{w}} {s.get('review_verdict','?')}")
    if s.get('devil_verdict'):
        print(f"  {'devil':<{w}} {s.get('devil_verdict','?')}")
    if s.get('builder_verdict'):
        print(f"  {'builder':<{w}} {s.get('builder_verdict','?')}")
except Exception as e:
    print(f"  (parse error: {e})")
PYEOF
}

# --- Main loop ---

while true; do
    clear
    printf "╔══════════════════════════════════════╗\n"
    printf "║     TEAM AI — PIPELINE MONITOR       ║\n"
    printf "╚══════════════════════════════════════╝\n"
    printf "  %s\n\n" "$(date '+%Y-%m-%d %H:%M:%S')"

    printf "── STATUS ────────────────────────────\n"
    show_status

    printf "\n── HANDOFFS ──────────────────────────\n"
    handoffs=$(ls -1t "$PIPELINE_DIR"/*.md 2>/dev/null | grep -v "pipeline.log")
    if [ -n "$handoffs" ]; then
        echo "$handoffs" | sed 's|.*/|  |'
    else
        printf "  (none yet)\n"
    fi

    printf "\n── LOG (last 10) ─────────────────────\n"
    tail -10 "$PIPELINE_DIR/pipeline.log" 2>/dev/null | sed 's/^/  /' \
        || printf "  (no log yet)\n"

    printf "\n── WATCHER ───────────────────────────\n"

    # Mode A — build/review pipeline
    process_handoff "01-build.md"       "build_verdict"   "a"
    process_handoff "02-ux-review.md"   "ux_verdict"      "a"
    process_handoff "03-code-review.md" "review_verdict"  "a"

    # Mode B — multi-perspective review
    process_handoff "ux-findings.md"      "ux_verdict"      "b"
    process_handoff "arch-findings.md"    "review_verdict"  "b"
    process_handoff "devil-findings.md"   "devil_verdict"   "b"
    process_handoff "builder-analysis.md" "builder_verdict" "b"

    # Done signal
    if [ -f "$PIPELINE_DIR/DONE.md" ]; then
        if ! grep -qF "DONE.md" "$PROCESSED_FILE" 2>/dev/null; then
            echo "DONE.md" >> "$PROCESSED_FILE"
            update_status "stage" "done"
            update_status "activity_state" "completed"
            ts=$(date '+%H:%M:%S')
            printf "  [%s] ✓ DONE.md — pipeline complete\n" "$ts"
            echo "[$ts] monitor: DONE.md → pipeline complete" >> "$PIPELINE_DIR/pipeline.log" 2>/dev/null
        fi
    fi

    sleep 2
done
