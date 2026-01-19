---
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
  - Example: Use `/see-terminal 0 100` not `/see-terminal 0 abc`

- **Other errors** → Show the error and suggest troubleshooting

## Usage Examples

```
/see-terminal           # Capture last 50 lines from pane 0
/see-terminal 1         # Capture last 50 lines from pane 1
/see-terminal 0 100     # Capture last 100 lines from pane 0
/see-terminal {right}   # Capture from pane to the right
/see-terminal 1 200     # Get more context (200 lines) from pane 1
```
