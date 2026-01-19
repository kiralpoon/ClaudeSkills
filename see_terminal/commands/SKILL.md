---
name: see-terminal
description: Capture tmux pane contents for analysis
argument-hint: [pane-target] [lines]
allowed-tools: Bash(tmux:*)
---

# Tmux Pane Content Capture

## Validate Tmux Session

First, verify tmux is running and show available panes:

Available panes: !`tmux list-panes -F "#{pane_index}: #{pane_current_command} (#{pane_width}x#{pane_height})" 2>&1`

## Capture Pane Contents

Target pane: ${1:-0}
Lines to capture: ${2:-50}

**Note**: For performance reasons, requesting more than 1000 lines may be slow. The default of 50 lines is usually sufficient for most debugging tasks.

Captured output: !`tmux capture-pane -t "${1:-0}" -p -S -${2:-50} 2>&1`

## Analysis Instructions

If the above capture succeeded (no error message):

Analyze the captured terminal output with focus on:

1. **Current State**: What is the terminal showing? What command was run?

2. **Output Analysis**:
   - If there are errors, identify them clearly
   - If it's build output, summarize results
   - If it's logs, highlight key events
   - If it's command output, explain what it means

3. **Context**: What was likely happening in this terminal session?

4. **Next Steps**: Based on the output, suggest relevant actions or provide insights

5. **Error Detection**: Flag any errors, warnings, or issues visible in the output

## Error Handling

If the capture command failed (error message present):

Common errors and solutions:

- **"can't find pane: X"** → The pane number/ID doesn't exist
  - Check the available panes listed above
  - Try a different pane number (0, 1, 2, etc.)

- **"no server running"** → No tmux session is active
  - Start a tmux session first with `tmux`
  - Or run this command from within a tmux session

- **Invalid numeric values** → If you see errors about invalid line numbers
  - The line count parameter must be a positive integer
  - Ask the user to request a valid number of lines

- **Other errors** → Show the error and suggest troubleshooting

## Parameters

When Claude invokes this skill, it can specify:

- **pane-target** (default: 0): Pane number (0, 1, 2...) or relative position ({right}, {left}, etc.)
- **lines** (default: 50): Number of lines to capture from pane history

Examples of what users might request:
- "Check my terminal" → captures pane 0, last 50 lines
- "What's in pane 1?" → captures pane 1, last 50 lines
- "Show me the last 100 lines from the right pane" → captures right pane, 100 lines
