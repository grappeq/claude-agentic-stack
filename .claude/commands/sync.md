---
description: Bring the current work branch up to date with its base branch — fetch, integrate, resolve any conflicts safely, and re-run the gate. Local only; never pushes.
argument-hint: [optional base ref, default the remote's default branch]
---

Bring the current work branch up to date with its base branch so a later `/ship` opens a conflict-free PR. Base: **$ARGUMENTS** (if empty, the remote's default branch — `origin/main` or `origin/master`).

This is a **local** operation: it fetches and integrates, but **never pushes**. Publishing stays with `/ship`. Conflict resolution is ordinary implementation — its safety comes from re-running the gate, not from trusting the merge.

1. **Preconditions.** You must be on a work branch, not the default branch (there is nothing to sync master into master). The working tree must be clean — commit or stash first; refuse to merge over uncommitted changes. If either fails, STOP and say so.

2. **Fetch & classify (read-only).** `git fetch` the remote, then compare the current branch to the base ref:
   - **Up to date** (base is an ancestor of HEAD) → nothing to do. Report `SYNC: CLEAN` and stop.
   - **Behind / fast-forwardable** → integrate; no judgment needed.
   - **Diverged** → go to step 3. Note the pre-merge SHA (`git rev-parse HEAD`) so the merge is trivially revertible.

3. **Merge with an escape hatch.** Integrate with **merge, not rebase** — rebasing an already-pushed branch would need a force-push, which is off-limits. Give yourself the common ancestor for context (`-c merge.conflictStyle=zdiff3`) and stage without committing so you can inspect first:
   ```
   git -c merge.conflictStyle=zdiff3 merge --no-commit --no-ff <base>
   ```
   - **No conflicts** → commit the merge and go to step 5. (Still re-gate — a clean merge can be semantically broken; git only flags textual overlap.)
   - **Conflicts** → step 4.

4. **Resolve — as implementation, within a budget.** Apply the circuit-breaker (CLAUDE.md → *When stuck*): if the conflicts exceed a small threshold (a handful of files/hunks) or sprawl across core logic, this is a "reconcile or rebuild" call that is genuinely the user's — `git merge --abort` and report `SYNC: BLOCKED` with what diverged. Within budget, resolve each conflict yourself (this is open-ended authoring — the orchestrator's job, not a subagent's), using the zdiff3 base to reason about *intent* on both sides rather than picking a side blindly. Then commit the merge.

5. **Re-gate — non-negotiable.** A merge is a code change and must clear the same gate as any other:
   - Run the **full `/verify`** (not just touched files — the clean-but-wrong case hides outside them). Drive it green; circuit-break at 3 failed attempts (revert to the pre-merge SHA and report `SYNC: BLOCKED` rather than looping).
   - If step 4 resolved any conflict, run `/review` scoped to the resolution: hand the reviewers `git diff <pre-merge-SHA>..HEAD` plus a one-line note per resolution decision, so they audit the reconciliation specifically. Resolve Critical/High findings.
   - **Thin coverage is a bail signal.** If a conflict landed in code with no test to arbitrate correctness, don't ship a guess — write the characterizing test first, or `SYNC: BLOCKED` and report.

6. **Report.** End with a verdict on its own line: `SYNC: CLEAN` (already current), `SYNC: PASS` (integrated and the gate is green), or `SYNC: BLOCKED` (reverted to the pre-merge state — describe what needs a human). `/sync` never pushes; on `PASS`, tell the user the branch is current and ready for `/ship`.
