---
description: Run a task end-to-end through the full agentic loop — plan, implement, verify, review (code + security + UX), resolve, report.
argument-hint: [task description]
---

Execute the task: **$ARGUMENTS**

Run the full Claude Agentic Stack loop (see CLAUDE.md). **Do not skip the review gate.**

Execution model: you **edit on the host**, but **all builds/tests/installs run on the sandbox VM** over SSH (`/verify` syncs the tree and runs them there). Never run build/test on the limited host.

1. **Understand & plan.** Restate the goal and acceptance criteria. For anything beyond a trivial one-file change, dispatch the `planner` agent to produce an ordered plan, the files to touch, a test strategy, and risks. Use the `Explore` agent for broad search so your context stays clean. Before writing any state, check for a stranded run: existing `.agentic/` state counts as *unfinished* unless its marker says done (`task.md` at `Status: done`, or a final `DONE` prototype checkpoint) **and** `git log` confirms the recorded final commit(s) — the same reconciliation `/resume` applies. On a stranded run, stop and surface it — offer `/resume` or get explicit confirmation to discard; in a headless run this is a hard failure (report and stop, never auto-discard) — rather than silently overwriting a resumable run. Then **persist the task**: write `.agentic/task.md` (creating `.agentic/.gitignore` containing `*` first if absent — CLAUDE.md → *Run artifacts*) with the task, the acceptance criteria, a `Status:` line (`implementing | verifying | reviewing | resolving | done`), and the plan as a `- [ ]` checklist — redacting secret-looking strings from the task text per CLAUDE.md → *Run artifacts*. This is the run's durable target — keep it live: check items off as they complete and update `Status:` at each phase transition (the checklist tracks the implementation plan; `Status:` tracks where the loop is, so `/resume` re-enters at the right phase rather than mistaking "implemented" for "done"). Skip the file only for a trivial one-file change.

2. **Implement.** Make the smallest viable change, reusing existing code and matching conventions. Resolve any open question from the plan first — ask the user only if it is a genuine ambiguity per CLAUDE.md's autonomy policy. If the sandbox VM isn't already warm, first kick off a one-time **background** sync + dependency install on it (CLAUDE.md → *Where things run* → *Warm the sandbox early*) so the cold install finishes while you edit and `/verify`'s install is a no-op.

3. **Verify.** Run `/verify` and drive build + lint/type-check + tests **and the runtime smoke** to green. For non-trivial unit coverage dispatch the `test-engineer` agent; for a runnable app, `/verify` boots and drives it via `e2e-tester`. On a green pass, record in `.agentic/task.md` the commit SHA at that verify and whether the worktree was clean — the checkable evidence `/resume` needs to skip a redundant re-verify.

4. **Review gate (mandatory).** In a single message, dispatch `code-reviewer` and `security-reviewer` in parallel on the current diff — and `ux-reviewer` too if the change touches UI (give it the task/spec; it reads the screenshots from verify under `.agentic/screenshots/standalone/`). Give each: the `git diff`, the task description, and pointers to the relevant files (they start with a clean context and cannot see this conversation).

5. **Resolve.** Fix every Critical and High finding, plus reasonable Mediums. Re-run `/verify`. Re-dispatch the reviewer for any dimension whose code you changed (`security-reviewer` for security-relevant fixes, `ux-reviewer` for UI fixes). Repeat until every dispatched reviewer reports `GATE: PASS`. If a failure won't resolve, apply the circuit-breaker (CLAUDE.md → *When stuck*) instead of looping.

6. **Report & commit.** Summarize: what changed (files), what the reviews found and how you resolved it, the test results, and any accepted Low-severity items. Then, with the gate clean, **commit the change on a work branch** (branch first if you're on the default branch; stage only intended files — see CLAUDE.md → *Committing & publishing*) — and only after the commit succeeds, mark the run complete in `.agentic/task.md` (`Status: done`, every checklist item checked, plus the final commit SHA so a later stranded-run check can confirm completion against `git log`). Leave pushing / PRs to the user: `/ship` is the curated publish path.

Honor the Definition of Done in CLAUDE.md. If you cannot meet it, stop and say why.
