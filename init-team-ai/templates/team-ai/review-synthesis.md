# Multi-Perspective Review Synthesis

You are the Team Lead. Three reviewers have examined the following subject
from different angles. Your job is to synthesise their findings into a
clear, actionable report.

SUBJECT: {{SUBJECT}}

## UX Findings
{{UX_FINDINGS}}

## Architecture Findings
{{ARCH_FINDINGS}}

## Devil's Advocate Findings
{{DEVIL_FINDINGS}}

## Synthesis Instructions

1. Identify CONSENSUS: concerns raised by multiple reviewers carry more weight.
2. Identify CONFLICTS: where reviewers disagree, note both sides without picking a winner.
3. Identify BLIND SPOTS: points raised only by the devil's advocate that the others missed.
4. Assign an overall risk level: LOW / MEDIUM / HIGH.
5. List the top 3 actionable next steps in priority order.

Write .agent/reviews/<YYYYMMDD>-<subject-slug>.md with this structure:

  # Multi-Perspective Review: {{SUBJECT}}
  Date: <timestamp>

  ## Executive Summary
  [2-3 sentences: what was reviewed, overall verdict, most important finding]

  ## Consensus Concerns (raised by 2+ reviewers)
  1. ...

  ## Conflicting Views
  - Topic: [UX says X / Architecture says Y]

  ## Devil's Advocate Highlights
  - ...

  ## Overall Risk: LOW | MEDIUM | HIGH

  ## Recommended Next Steps
  1. [Highest priority action]
  2. ...
  3. ...

  ## Full Reviewer Outputs
  See: .agent/pipeline/ux-findings.md    (ephemeral — gitignored)
       .agent/pipeline/arch-findings.md  (ephemeral — gitignored)
       .agent/pipeline/devil-findings.md (ephemeral — gitignored)
