---
description: Turn a broad product vision into a working app — a short kickoff interview, then autonomous build → verify → review → improve across milestones until the vision is met. Expansive (decide-and-build) posture.
argument-hint: [what to build]
---

Build this: **$ARGUMENTS**

Run the Claude Agentic Stack loop in **prototype posture** (see CLAUDE.md). After a brief kickoff, you turn a broad vision into a complete, working app **autonomously** — decide and build, record choices as assumptions, and ask nothing further (except the hard stops in CLAUDE.md's autonomy policy) until the run ends. The review gate and Definition of Done apply in full. Work on a dedicated branch (create one off the default branch before the first commit) and **commit each completed milestone as a checkpoint** once its gate is clean (CLAUDE.md → *Committing & publishing*). You **edit on the host**; all builds, tests, and app boots run on the **sandbox VM** over SSH. Long runs are expected, so persist state — the run must survive context compaction.

1. **Kickoff.** In a headless/non-interactive run, skip only the interactive sub-steps **1.2** and **1.4**; still run **1.1** and **1.3**, using the recommended defaults from SPEC: PROPOSE as the answers fed to SPEC: FINALIZE — so `.agentic/spec.md` is always written.
   1. Dispatch `product-designer` in **SPEC: PROPOSE** mode → a provisional vision + the few high-leverage kickoff questions (each with options and a recommended default).
   2. **Interview the user** with those questions via `AskUserQuestion` (one or two waves; lead each with the recommended default). This is the one place questions are allowed.
   3. Dispatch `product-designer` in **SPEC: FINALIZE** with the vision + answers → the lean spec. **Write it to `.agentic/spec.md`** (create `.agentic/.gitignore` containing `*` first if absent). This frozen outline is the run's north star.
   4. **Spec checkpoint** — show `.agentic/spec.md` and get one confirm-or-redirect. After this the gate closes: no more questions except the hard stops in CLAUDE.md's autonomy policy.

2. **Iterate per milestone** (outer / improvement loop), starting at M1. Let **N** be the verify-pass counter — start at 0 and increment it each time you enter sub-step 2.3 (Verify) below (not on the inner re-verifies in 2.5); it names a fresh screenshot bucket `round-<N>/` so the previous pass is always the "before". (This is separate from the round *budget*, which counts `ITERATE` decisions.) For the current milestone:
   1. **Plan.** Dispatch `planner` to turn the milestone into an ordered plan and file list — elaborate the milestone's features/screens here, since the spec deliberately leaves them out.
   2. **Implement.** Build a complete, coherent cut of the milestone — fill gaps with strong defaults, apply a consistent design system. Reuse before adding.
   3. **Verify.** Increment **N**, then run `/verify N` (pass N as the argument) to green: build + lint/type-check + unit tests **and** runtime smoke; `/verify` relays N to `e2e-tester` so it buckets this pass's screenshots under `.agentic/screenshots/round-<N>/`. Dispatch `test-engineer` for non-trivial unit coverage.
   4. **Review gate (mandatory, parallel).** In a single message dispatch `code-reviewer`, `security-reviewer`, and — since this builds UI — `ux-reviewer` (give it the spec and round N; it reads `round-<N>/` and compares against `round-<N-1>/` for changed screens).
   5. **Resolve (inner / convergence loop).** Fix every Critical/High + reasonable Medium, re-verify (do **not** increment N — only sub-step 2.3 does, so re-verifies keep landing in the same `round-<N>/`), and re-review the changed dimensions. Repeat until smoke is green and all reviewers report `GATE: PASS`. **If a failure won't resolve, apply the circuit-breaker** (CLAUDE.md → *When stuck*): after 3 failed attempts at the same failure, stop repeating it — record the failed approaches in `.agentic/progress.md` (guard + redact per CLAUDE.md → *Run artifacts*) and route around (build/test failures only) or escalate.
   6. **Gap review.** Dispatch `product-designer` in **GAP REVIEW** mode — give it the spec and round N (it reads `.agentic/spec.md` + `round-<N>/` screenshots). Then **checkpoint progress** to `.agentic/progress.md` (current milestone, what's done, what's next, key decisions, failed approaches — guard + redact per CLAUDE.md → *Run artifacts*) so the run can resume after compaction, and act on the decision:
      - `ITERATE` → close the listed must-close gaps; return to sub-step 2 (Implement) for this milestone (this consumes one round of the budget).
      - `ADVANCE` → the milestone is complete and its gate is clean, so **commit it as a checkpoint** (Conventional Commits, on the work branch, staging only intended files by explicit path — never `.agentic/`, secrets, or unrelated artifacts); then move to the named next milestone and return to sub-step 1 (Plan).
      - `DONE` → **commit the final milestone** as above, then exit the loop.
      - `ASK` → stop and put the question to the user.

3. **Stop conditions.** Exit when GAP REVIEW returns `DONE`, when the round budget is reached (default **3** improvement rounds — each `ITERATE` consumes one round, counted globally across all milestones; override with `rounds=N` in the arguments), or on `ASK`. Never declare success or run `/ship` with a red gate or failing smoke — a stuck check that cannot be resolved is a stop-and-report, not a green exit.

4. **Report.** Summarize what you built, the **assumptions** you made (point at `.agentic/spec.md`), where the screenshots are, what each review found and how you resolved it, and any milestones or polish left. Each clean milestone is already committed on the work branch; run `/ship` to push or open a PR when you're happy.

Honor the Definition of Done in CLAUDE.md. If you cannot meet it, stop and say why.
