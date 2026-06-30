---
description: Run a task end-to-end through the full agentic loop — plan, implement, verify, review (code + security), resolve, report.
argument-hint: [task description]
---

Execute the task: **$ARGUMENTS**

Run the full Agentic Dev Stack loop (see CLAUDE.md). **Do not skip the review gate.**

Execution model: you **edit on the host**, but **all builds/tests/installs run on the sandbox VM** over SSH (`/verify` syncs the tree and runs them there). Never run build/test on the limited host.

1. **Understand & plan.** Restate the goal and acceptance criteria. For anything beyond a trivial one-file change, dispatch the `planner` agent to produce an ordered plan, the files to touch, a test strategy, and risks. Use the `Explore` agent for broad search so your context stays clean.

2. **Implement.** Make the smallest viable change, reusing existing code and matching conventions. Resolve any open question from the plan first — ask the user only if it is a genuine ambiguity per CLAUDE.md's autonomy policy.

3. **Verify.** Run `/verify` and drive build + lint/type-check + tests to green. For non-trivial coverage, dispatch the `test-engineer` agent to add tests.

4. **Review gate (mandatory).** In a single message, dispatch BOTH `code-reviewer` and `security-reviewer` in parallel on the current diff. Give each: the `git diff`, the task description, and pointers to the relevant files (they start with a clean context and cannot see this conversation).

5. **Resolve.** Fix every Critical and High finding, plus reasonable Mediums. Re-run `/verify`. If you changed security-relevant code, re-dispatch `security-reviewer`. Repeat until both reviewers report `GATE: PASS`.

6. **Report.** Summarize: what changed (files), what the reviews found and how you resolved it, the test results, and any accepted Low-severity items. Do **not** commit automatically — tell the user to run `/ship` when ready.

Honor the Definition of Done in CLAUDE.md. If you cannot meet it, stop and say why.
