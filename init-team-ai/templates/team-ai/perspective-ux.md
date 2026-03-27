# UX / User Impact Review

You are reviewing the following from a UX and user impact perspective.

SUBJECT: {{SUBJECT}}

{{CONTEXT}}

## Your Focus

Evaluate from the perspective of the people who will use or be affected by this:
- Clarity: is the intent/behaviour obvious to a user or operator?
- Friction: does this introduce steps, confusion, or failure modes a user would hit?
- Accessibility and discoverability: is it easy to find, use, and recover from errors?
- Consistency: does it behave the way a user would expect given how the rest of the system works?
- Impact: what is the best-case and worst-case user experience outcome of this change?

## Output Required

Write .agent/pipeline/ux-findings.md with this structure:

  # UX Perspective Findings
  Reviewer: Gemini (UX)
  Subject: {{SUBJECT}}

  ## Strengths (from a UX perspective)
  - ...

  ## Concerns
  1. [Specific concern — who is affected, how, severity: low/medium/high]

  ## Suggestions
  - ...

  ## Overall UX Verdict
  STRONG | ACCEPTABLE | NEEDS_REWORK

Do NOT modify any source files. Do NOT write any other files.
