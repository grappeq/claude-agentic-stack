---
description: Run the full review gate — code-reviewer and security-reviewer in parallel on the current diff — and aggregate one severity-sorted report.
argument-hint: [optional: focus area or "staged"]
---

Review the current changes. Focus: **$ARGUMENTS** (if empty, review the full working-tree diff).

1. Determine the diff: `git diff` for the working tree, or `git diff --staged` if the user asked for staged / `"staged"`. If there is no diff, say so and stop.
2. In a single message, dispatch BOTH the `code-reviewer` and `security-reviewer` agents in parallel. Give each the diff, the branch/PR context, and pointers to the relevant files — they start with a clean context and cannot see this conversation.
3. Aggregate their findings into ONE report, sorted by severity (Critical → Low), de-duplicated, each item tagged `[code]` or `[security]` with `file:line` and the fix.
4. End with the combined verdict: `GATE: PASS` only if neither reviewer reported an unresolved Critical or High; otherwise `GATE: FAIL` listing the blockers.

This is the same gate `/build` runs. For a deeper one-off audit you can also use the built-in `/code-review` and `/security-review` skills.
