# Claude Agentic Stack

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A portable, drop-in **Claude Code orchestration configuration** that makes Claude work as an autonomous, senior engineering team-of-one: it plans, implements, verifies, and **reviews its own work for correctness and security** before calling anything done.

The config *is* the product. Copy it into any repository and Claude Code starts following the loop below.

## Philosophy

Claude runs inside an **isolation boundary** — an OS-level sandbox, or a disposable VM/container — where it can work without stopping for approval, while the host *outside* the boundary stays protected. Within that boundary, **permissions are not what keeps the output good** — the mandatory review gate is. Every task ends with a parallel `code-reviewer` + `security-reviewer` pass, and the work is not "done" until both come back clean.

> Isolation protects the **host**. The **review gate** protects the **codebase**. Two different jobs.

## What's in the box

```
.
├── CLAUDE.md                          # operating manual — loaded into every session
└── .claude/
    ├── settings.json                      # DEFAULT: SSH-sandbox — limited host, free VM reached over SSH
    ├── settings.bash-sandbox.json.example # mac/Linux/WSL2, no separate VM: built-in OS Bash sandbox
    ├── settings.vm-bypass.json.example    # when Claude Code runs INSIDE a disposable VM/container
    ├── agents/
    │   ├── product-designer.md        # kickoff Q&A + lean spec; gap-checks build vs spec (read-only)
    │   ├── planner.md                 # decomposes a task → plan + test strategy            (read-only)
    │   ├── test-engineer.md           # writes & runs meaningful unit tests
    │   ├── e2e-tester.md              # boots the app on the VM, smokes it, screenshots it
    │   ├── code-reviewer.md           # reviews diff: correctness / quality / reuse          (read-only)
    │   ├── security-reviewer.md       # audits diff against a threat checklist               (read-only)
    │   └── ux-reviewer.md             # critiques the rendered UI vs the spec                (read-only)
    └── commands/
        ├── build.md      →  /build     # the full loop in precision posture
        ├── prototype.md  →  /prototype # vision → app: iterate across milestones
        ├── verify.md     →  /verify    # build + lint + test + runtime smoke gate
        ├── review.md     →  /review    # reviewers in parallel → one report
        └── ship.md       →  /ship      # finalize: curate commit + push/PR (user-only)
```

## Install

Clone the repo, then copy the two pieces into the root of your target repo:

```bash
git clone https://github.com/grappeq/claude-agentic-stack.git
cp -r claude-agentic-stack/.claude   /path/to/your-repo/.claude
cp    claude-agentic-stack/CLAUDE.md /path/to/your-repo/CLAUDE.md
```

This assumes a fresh target; if your repo already has a `.claude/`, replace or merge it rather than nesting a second one inside.

The runtime smoke writes screenshots under `.agentic/` — add **`.agentic/`** to your repo's `.gitignore` so that evidence (it can contain secrets or PII from the booted app) is never committed. As a backstop the stack also drops a `.agentic/.gitignore` of `*` on first run.

(Already have a `CLAUDE.md`? Merge the "Operating loop / Definition of Done / Orchestration contract" sections into yours.) Start Claude Code in the repo and run `/agents` to confirm the seven agents loaded, and `/` to see `/build`, `/prototype`, `/verify`, `/review`, `/ship`.

## Two postures

The same machinery runs in two modes — pick by the work:

- **`/build <task>` — precision.** Changing an existing system: smallest viable change, reuse first, match conventions. A single pass with an inner convergence loop.
- **`/prototype <vision>` — prototype.** Turning a broad vision into a working app: a **brief kickoff interview** pins down the need, then it runs **autonomously** — making the product and UX calls itself (recording assumptions) and **iterating across milestones** until the vision is met. Built for long, unattended runs.

### Precision loop — `/build`

```
/build <task>
   │  understand  ── reuse first; Explore agent for broad search
   │  plan        ── planner agent (non-trivial tasks)
   │  implement   ── edit on host; smallest viable change, match conventions
   │  /verify     ── on the VM: build + lint + tests + RUNTIME SMOKE → green
   │                   (test-engineer adds units · e2e-tester boots & drives the app)
   │  REVIEW GATE ── code-reviewer ‖ security-reviewer ‖ ux-reviewer*  (parallel, read-only)
   │  resolve     ── fix Critical/High, re-verify, re-review changed dimensions
   └─ report      ── auto-commit on green (work branch) ──► /ship to push / open a PR
                                          * ux-reviewer only when the diff touches UI
```

### Prototype loop — `/prototype`

```
/prototype <vision>
   │  KICKOFF (interactive)  ── product-designer proposes the few high-leverage
   │     questions → you answer (AskUserQuestion) → lean .agentic/spec.md written
   │     → spec checkpoint (one confirm) → gate closes, no more questions
   │                                              (headless: skip, use defaults)
   │  ┌─ per milestone, autonomous ───────────────────────────────────┐
   │  │  plan → implement (expansive) → /verify (+ runtime smoke)      │
   │  │  REVIEW GATE: code ‖ security ‖ ux  → resolve until clean      │
   │  │     (stuck? circuit-breaker: 3 tries, then route around/stop)  │
   │  │  GAP REVIEW vs spec: ITERATE · ADVANCE · DONE · ASK            │
   │  │  checkpoint → .agentic/progress.md  (survives compaction)      │
   │  └───────────────────────────────────────────────────────────────┘
   │        ⟲ until spec met, round budget spent (default 3), or ASK
   └─ commit each milestone on green · report ──► /ship to push / open a PR
```

The orchestrator is the main Claude thread; the agents are isolated-context leaf workers that **find** problems and assess progress. The orchestrator **fixes** and coordinates. (Subagents can't spawn subagents, which is why coordination lives in the main thread.)

## Three loops

The stack converges through three loops. Naming them is the fastest way to see how a one-line request becomes finished work:

| | Loop | What it does | Where |
|---|------|--------------|-------|
| **L1** | **Convergence** (inner) | `resolve → re-verify → re-review` until verify is green and every reviewer reports `GATE: PASS`. A circuit-breaker caps repeated failed fixes so it can't thrash. | Automatic — both `/build` and `/prototype` |
| **L2** | **Improvement** (outer) | Once a milestone is correct, `product-designer` gap-checks the running app against the frozen spec and the loop builds the next increment — milestone by milestone — until the vision is met, the round budget is spent (default 3), or the gap review signals scope beyond the vision (then it stops and asks). | `/prototype`, wrapping L1 |
| **L3** | **You** (human) | Each run ends with a report and the assumptions it made. You read it and send the next prompt to redirect; edit `.agentic/spec.md` to steer the next run. | Between runs |

The distinction that matters: **L1 makes work _correct_, L2 makes it _complete_, L3 is where _you_ point it.** `/build` is mostly L1; `/prototype` is L2 over L1, then back to you.

## Usage

- **Prototype from a vision:** `/prototype a habit tracker with streaks and weekly stats` — a few kickoff questions, then it designs, builds, iterates across milestones, and screenshots it autonomously.
- **Precision change:** `/build add rate limiting to the login endpoint`
- **Just review what you have:** `/review` (or `/review staged`)
- **Just run the gate:** `/verify`
- **Auto-commit:** the loop commits on green automatically, on a work branch — you don't run anything.
- **Publish when ready:** `/ship` re-confirms the gate, curates the commit, and pushes / opens a PR if you ask — e.g. `/ship feat: add login rate limiting`.
- **Headless / CI:** `claude -p "/build add rate limiting to the login endpoint"` (the sandbox VM must be reachable via `ssh sandbox`)
- **Deeper one-off audits:** the built-in `/code-review` and `/security-review` skills complement the in-loop gate.

## Isolation model — pick the profile that matches your setup

The agent runs on a **limited host** and offloads real execution to an **isolated sandbox**, so it can act freely without endangering the host. Pick the `settings.json` profile that matches how your sandbox is reached.

| Your setup | Use this profile | Host vs. sandbox |
|------------|------------------|------------------|
| **Claude Code on a host that SSHes into a separate sandbox VM** | **`settings.json` (default)** | Host: edit + `git` + sync only; dangerous ops and secret reads (`~/.ssh`, `~/.aws`, `.env`) denied. VM (`ssh sandbox …`): **unrestricted** — every build/test/install runs there. |
| Claude Code on **macOS / Linux / WSL2**, no separate VM | `cp .claude/settings.bash-sandbox.json.example .claude/settings.json` | The built-in [OS Bash sandbox](https://code.claude.com/docs/en/sandboxing) confines bash + child processes to the workspace, denies credentials, allowlists network; auto-allow = no prompts inside the boundary. |
| Claude Code runs **inside a disposable VM / container / [sandbox-runtime](https://code.claude.com/docs/en/sandbox-environments)** | `cp .claude/settings.vm-bypass.json.example .claude/settings.json` | The VM/container is the wall; `bypassPermissions` is fine inside it; your real host is unreachable. Required for fully unattended `--dangerously-skip-permissions`. |

### Set up the SSH sandbox (default profile)

1. Provision a disposable Linux VM with the toolchains your projects need (node, python, go, …).
2. Add an SSH alias named **`sandbox`** to `~/.ssh/config` on the host:
   ```
   Host sandbox
       HostName <your-vm-ip>
       User dev
       IdentityFile ~/.ssh/sandbox_key
   ```
   The default profile's allow-rule `Bash(ssh sandbox *)` keys off this exact alias — keep `sandbox`, or rename it in both the SSH config and `settings.json`.
3. Set the remote working directory via `SANDBOX_REMOTE_DIR` in `.claude/settings.json` `env` (default `~/agentic-workspace`).
4. Make sure `rsync` is available on host and VM for fast syncs (`scp -r` is the fallback).
5. For **frontend e2e** — the runtime smoke that boots a browser and screenshots the UI — install a headless browser on the VM: `npx playwright install --with-deps chromium`. Without it, `/verify`'s runtime smoke degrades gracefully to an HTTP-level check and `ux-reviewer` reports that no screenshots were available.

Now `/verify` syncs the working tree to the VM and runs build/lint/test there; the host only edits and commits. Edits happen on the host (Claude's `Read`/`Edit`/`Write`), execution happens on the VM (`ssh sandbox …`). `deny` rules are enforced from every scope and even override `allow`, so the host floor holds regardless of mode.

> **Why SSH and not the OS Bash sandbox here?** The built-in Bash sandbox doesn't run on native Windows, and it only confines Bash (not MCP/hooks). A real VM reached over SSH gives a stronger, OS-independent boundary and matches a "controller host + disposable worker" topology. The other two profiles are there if your setup differs.

## Customize

- **Sandbox target** — change the SSH alias (`sandbox`) and remote dir (`SANDBOX_REMOTE_DIR`) in `.claude/settings.json`; keep the `Bash(ssh <alias> *)` allow-rule in sync.
- **Security checklist** — edit `.claude/agents/security-reviewer.md`; add your domain's threats (e.g. payment flows, PII handling, tenancy isolation).
- **Verify gate** — edit `.claude/commands/verify.md` to add an ecosystem or point at your repo's exact build/test commands (they run on the VM over SSH).
- **Runtime smoke / e2e** — edit `.claude/commands/verify.md` and `.claude/agents/e2e-tester.md` to set how your app boots and which user flows the smoke drives.
- **Iteration depth** — change the default prototype round budget in `.claude/commands/prototype.md`, or pass `rounds=N` to `/prototype`.
- **Run artifacts** — a `/prototype` run writes its frozen vision to `.agentic/spec.md` and live progress to `.agentic/progress.md` (both git-ignored). Read them to see where an autonomous run is, or edit `spec.md` between runs to redirect it.
- **Definition of Done** — edit `CLAUDE.md`; it's the contract every task is held to.
- **Model/cost** — agent frontmatter sets the model (`code-reviewer` → `sonnet` for speed; `security-reviewer` → `inherit`, i.e. your session model, for rigor). Tune per the cost/depth trade-off you want.

## Design notes

- **Two-layer security model** — *isolation* (the sandbox VM / OS sandbox) protects the **host**; the *review gate* is semantic and protects the **codebase**. Neither substitutes for the other, and the stack ships both.
- **Review-agents enforcement, not blocking hooks** — the gate is semantic (AI review) and lives in the workflow, so it adapts to any language without per-repo hook scripts.
- **Read-only reviewers** — reviewers can't edit, so they can never silently "fix and pass" their own findings. Clean find/fix separation. This now extends to **UX**: `ux-reviewer` critiques the rendered UI with fresh eyes instead of the builder grading its own design.
- **Runtime smoke, not just unit tests** — the gate boots and drives the assembled app (browser / API / CLI), so "it compiles" can't masquerade as "it works". The screenshots double as e2e evidence and as the input to independent UX review.
- **Generative + evaluative symmetry** — the stack pairs a *maker* and a *critic* for each concern: code (`planner` → `code-reviewer`/`security-reviewer`) and product/UX (`product-designer` → `ux-reviewer`), with `product-designer` also closing the loop by gap-checking the build against its own spec.
- **Commit vs. publish** — the agent auto-commits on a work branch once the gate is green (local, reversible, no prompt), but *publishing* — push, PR, release — stays human-gated via `/ship`. The boundary is external visibility, not the git verb.
- **Built for long autonomous runs** — `/prototype` front-loads a brief kickoff interview, then runs hands-off. The frozen vision (`.agentic/spec.md`) and a progress log (`.agentic/progress.md`) are durable, so a run survives context compaction; a circuit-breaker caps repeated failed fixes (3 tries) so a stuck check can't burn the session. `ux-reviewer` compares screenshots round-over-round to catch UI regressions.
- **No required MCP / Node / jq** — the stack is pure config and drop-in anywhere.
- **Commands vs skills** — these workflows are single-file `.claude/commands/*.md` for readability. They can be migrated to `.claude/skills/<name>/SKILL.md` if you want supporting files or `context: fork` execution; both produce the same `/name`.
- **Future hardening** — if you ever want a *non-bypassable* gate (e.g. for unattended fleets), add a `Stop` hook that refuses to end a turn until `/review` has passed. Intentionally omitted here to keep enforcement agent-based.

## License

Released under the [MIT License](LICENSE) — © 2026 Kacper Grabowski. Free to use, fork, and adapt.
