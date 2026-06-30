---
description: Turn a broad product vision into a working app — product design, then iterate build → verify → review → improve across milestones until the spec is met. Expansive (decide-and-build) posture.
argument-hint: [what to build]
---

Build this: **$ARGUMENTS**

Run the Agentic Dev Stack loop in **prototype posture** (see CLAUDE.md). You are turning a broad vision into a complete, working app — decide and build, don't ask for product/UX choices; record them as assumptions instead. The review gate and Definition of Done still apply in full. You **edit on the host**; all builds, tests, and app boots run on the **sandbox VM** over SSH.

1. **Product design.** Dispatch `product-designer` in SPEC mode → a concrete spec with milestones (M1 = thinnest usable version, then coherent increments), per-milestone acceptance criteria, UX decisions, visual direction, default stack, and Assumptions.

2. **Iterate per milestone** (outer / improvement loop). For the current milestone:
   1. **Plan.** Dispatch `planner` to turn the milestone into an ordered plan and file list.
   2. **Implement.** Build a complete, coherent cut of the milestone — fill gaps with strong defaults, apply a consistent design system. Reuse before adding.
   3. **Verify.** Run `/verify` to green: build + lint/type-check + unit tests **and** runtime smoke (boot + drive the app; `e2e-tester` captures screenshots). Dispatch `test-engineer` for non-trivial unit coverage.
   4. **Review gate (mandatory, parallel).** In a single message dispatch `code-reviewer`, `security-reviewer`, and — since this builds UI — `ux-reviewer` (give it the spec; it reads the screenshots).
   5. **Resolve (inner / convergence loop).** Fix every Critical/High + reasonable Medium from all reviewers, re-verify, and re-review the dimensions that changed. Repeat until smoke is green and all reviewers report `GATE: PASS`.
   6. **Gap review.** Dispatch `product-designer` in GAP REVIEW mode with the spec + current build + screenshots, then act on its decision:
      - `ITERATE` → close the listed must-close gaps (return to sub-step 2, Implement, for the current milestone).
      - `ADVANCE` → move to the named next milestone (return to sub-step 1, Plan, for the next milestone).
      - `DONE` → exit the loop.
      - `ASK` → stop and put the question to the user.

3. **Stop conditions.** Exit when GAP REVIEW returns `DONE`, when the round budget is reached (default **3** improvement rounds — each `ITERATE` response from GAP REVIEW consumes one round, counted globally across all milestones; override with `rounds=N` in the arguments), or on `ASK`. Never exit with a red gate or failing smoke.

4. **Report.** Summarize what you built, the **assumptions** you made (so the user can redirect), where the screenshots are, what each review found and how you resolved it, and any milestones or polish left. Tell the user to run `/ship` when they're happy — do not commit automatically.

Honor the Definition of Done in CLAUDE.md. If you cannot meet it, stop and say why.
