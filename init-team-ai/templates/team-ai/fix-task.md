# Fix Task — Round {{ROUND}}

You are the Builder. The Team Lead has reviewed feedback from the UI/UX Reviewer
and Code Reviewer. You must fix the issues listed below.

ORIGINAL TASK: {{TASK_DESCRIPTION}}

## Issues from UI/UX Review (fix these)
{{UX_ISSUES}}

## Issues from Code Review (fix these)
{{REVIEW_ISSUES}}

## Steps

1. Read .agent/TEAM.md to understand the communication protocol.
2. Read .agent/pipeline/PLAN.md for the full task specification.
3. Read your previous build handoff: .agent/pipeline/01-build.md
4. Read the reviewer feedback files for full context:
   - .agent/pipeline/02-ux-review.md (if it exists)
   - .agent/pipeline/03-code-review.md (if it exists)
5. Fix each listed issue. Do not touch unrelated code.
6. Self-review and self-test your fixes (same as initial build).
7. Rewrite .agent/pipeline/01-build.md with the updated handoff.
   Include a Lineage section documenting what was fixed this round
   and any prior decisions. Set Verdict: APPROVED. Set Route: NEXT.
   Set Ready For Next Stage: true.

## Output

Rewrite .agent/pipeline/01-build.md (same file, updated content).
Its existence tells the Team Lead you are done.
