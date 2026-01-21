# Testing & Monitoring Guide for init-team-ai Skill

This document captures lessons learned from testing the init-team-ai skill to ensure efficient monitoring and interaction during skill execution.

## Lesson 1: Use see-terminal Skill for Monitoring

**Problem:** During testing, manual `sleep` commands were used to wait and check progress:
```bash
sleep 2 && tmux capture-pane -t 0 -p -S -80
sleep 5 && tmux capture-pane -t 0 -p -S -100
```

**Solution:** Use the `/see-terminal` skill instead for efficient monitoring:
```bash
/see-terminal 0 80    # Monitor pane 0, last 80 lines
/see-terminal 0 100   # Monitor pane 0, last 100 lines
```

**Benefits:**
- No manual sleep delays - see-terminal skill handles timing efficiently
- Consistent monitoring pattern
- Better integration with Claude's skill system
- Cleaner code without manual bash sleep commands

**When to Use:**
- ✅ Monitoring skill execution progress in tmux panes
- ✅ Checking for permission prompts from Claude
- ✅ Verifying completion status
- ✅ Debugging errors during skill execution

**When NOT to Use:**
- ❌ When you need to execute commands (use tmux send-keys)
- ❌ For one-time immediate checks (direct tmux capture-pane is fine)

---

## Lesson 2: Selecting Option 2 in Claude Permission Prompts

**Problem:** When Claude presents a permission prompt with options like:
```
 Do you want to proceed?
 ❯ 1. Yes
   2. Yes, and don't ask again for similar commands in /home/user/project
   3. No
```

Initial attempt that **FAILED**:
```bash
tmux send-keys -t 0 "2" Enter
```
This types the character "2" and presses Enter, but Claude's UI doesn't accept this.

**Solution that WORKS:**
```bash
tmux send-keys -t 0 Down Enter
```

This navigates DOWN to option 2 (from default option 1), then presses Enter to select it.

**Navigation Pattern:**
- Default selection: Option 1 (highlighted with ❯)
- To select option 2: Press `Down` once, then `Enter`
- To select option 3: Press `Down` twice, then `Enter`
- To go back up: Use `Up` key

**Complete Examples:**

Select option 1 (already selected by default):
```bash
tmux send-keys -t 0 Enter
```

Select option 2:
```bash
tmux send-keys -t 0 Down Enter
```

Select option 3:
```bash
tmux send-keys -t 0 Down Down Enter
```

**Why This Matters:**
When testing init-team-ai, Claude will request permissions multiple times. To automate approvals with "don't ask again" (option 2), you must use the navigation pattern, not type "2".

---

## Lesson 3: Efficient Testing Workflow Pattern

**Best Practice Pattern for Testing init-team-ai:**

1. **Start claude in tmux pane 0:**
   ```bash
   tmux send-keys -t 0 "claude" Enter
   ```

2. **Wait for claude to load:**
   ```bash
   /see-terminal 0 50
   ```

3. **Execute skill:**
   ```bash
   tmux send-keys -t 0 "/init-team-ai" Enter Enter
   ```
   Note: Press Enter TWICE - first to execute the command, second to confirm

4. **Monitor progress:**
   ```bash
   /see-terminal 0 100
   ```

5. **When permission prompt appears, approve with option 2:**
   ```bash
   tmux send-keys -t 0 Down Enter
   ```

6. **Continue monitoring until complete:**
   ```bash
   /see-terminal 0 80
   ```

7. **Verify completion and check created files:**
   ```bash
   ls -la /home/user/project
   cat /home/user/project/Agents.md
   cat /home/user/project/Claude.local.md
   # etc.
   ```

---

## Lesson 4: Monitoring Skill Execution States

**Claude Code Execution States:**

During init-team-ai execution, Claude goes through these states:

1. **"Forming..."** - Claude is processing the task, queuing commands
   ```
   ✽ Forming… (ctrl+c to interrupt)
   ```

2. **"Enchanting..."** - Claude is finalizing the response
   ```
   ✽ Enchanting… (ctrl+c to interrupt · 37s · ↓ 1.9k tokens)
   ```

3. **"Worked for Xs"** - Skill completed
   ```
   ✻ Worked for 43s
   ```

**Monitoring Strategy:**
- Check every 3-5 seconds during "Forming..." phase
- Check every 2-3 seconds during "Enchanting..." phase
- Use `/see-terminal` for all checks (not manual sleep)

---

## Lesson 5: Permission Approval Strategy

**Types of Permission Requests:**

1. **Bash command with "don't ask again" option:**
   ```
   ❯ 1. Yes
     2. Yes, and don't ask again for similar commands in /home/user/project
     3. No
   ```
   **Action:** Use `Down Enter` to select option 2

2. **Template file access:**
   ```
   ❯ 1. Yes
     2. Yes, and always allow access to templates/ from this project
     3. No
   ```
   **Action:** Use `Down Enter` to select option 2

**Best Practice:**
- Always approve with option 2 when testing - it grants persistent permission
- This reduces future permission prompts
- Makes testing faster in subsequent runs

---

## Quick Reference

**Essential Commands:**

Monitor pane 0:
```bash
/see-terminal 0 100
```

Approve permission (select option 2):
```bash
tmux send-keys -t 0 Down Enter
```

Execute skill:
```bash
tmux send-keys -t 0 "/init-team-ai" Enter Enter
```

Check completion:
```bash
/see-terminal 0 80
```

**DO:**
- ✅ Use `/see-terminal` for all monitoring
- ✅ Use `Down Enter` for option 2 selection
- ✅ Press Enter TWICE when executing skills
- ✅ Grant persistent permissions (option 2) during testing

**DON'T:**
- ❌ Use manual `sleep` commands for monitoring
- ❌ Type "2" to select option 2 in prompts
- ❌ Forget to press Enter twice for skill execution

---

## Test Verification Checklist

After init-team-ai completes, verify these files:

- [ ] `Agents.md` exists and contains ExecPlan guidelines
- [ ] `Claude.local.md` exists and contains local preferences
- [ ] `.agent/PLANS.md` exists and contains detailed guidelines
- [ ] `.claude/settings.local.json` exists with SessionStart hooks
- [ ] `.gitignore` contains Claude Code entries
- [ ] All files are properly gitignored (check with `git status`)

Quick verification command:
```bash
ls -la Agents.md Claude.local.md .agent/PLANS.md .claude/settings.local.json && tail -20 .gitignore
```
