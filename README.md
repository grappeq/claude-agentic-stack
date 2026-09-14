# Claude Agentic Stack

This is the Claude Code config stack I've been using and iterating on. It makes Claude work like an autonomous, senior engineering team-of-one — it plans, implements, verifies, and **reviews its own work for correctness and security** before calling anything done.

It ships as a Claude Code plugin, **`cas`**, served from this repo's own marketplace: install it, run `/cas:setup` once in your repo, and Claude Code starts following the loop below. Sharing it in case it's useful to someone else — it's still evolving.

## Philosophy

Claude runs inside an **isolation boundary** — an OS-level sandbox, or a disposable VM/container — where it can work without stopping for approval, while the host *outside* the boundary stays protected. Within that boundary, **permissions are not what keeps the output good** — the mandatory review gate is. Every task ends with a parallel `cas:code-reviewer` + `cas:security-reviewer` pass, and the work is not "done" until both come back clean.

> Isolation protects the **host**. The **review gate** protects the **codebase**. Two different jobs.

## What's in the box

The repo root *is* the plugin (and its own marketplace):

```
.
├── .claude-plugin/
│   ├── plugin.json                # the `cas` plugin manifest
│   └── marketplace.json           # this repo is its own marketplace: `claude-agentic-stack`
├── MANUAL.md                      # operating manual — injected into every session by the hook below
├── hooks/hooks.json               # SessionStart hook: `cat MANUAL.md` into context (the only hook)
├── commands/
│   ├── build.md      →  /cas:build      # the full loop in precision posture
│   ├── prototype.md  →  /cas:prototype  # vision → app: iterate across milestones
│   ├── mockup.md     →  /cas:mockup     # design checkpoint: variants → your pick → .agentic/design.md
│   ├── resume.md     →  /cas:resume     # re-enter an interrupted run from .agentic/ state
│   ├── verify.md     →  /cas:verify     # build + lint + test + runtime smoke gate
│   ├── review.md     →  /cas:review     # reviewers in parallel → one report
│   ├── sync.md       →  /cas:sync       # bring branch up to date with base; re-gate (local)
│   ├── ship.md       →  /cas:ship       # finalize: gate + commit + sync + push + PR
│   └── setup.md      →  /cas:setup      # one-time repo setup: isolation profile, guards, registration
├── agents/                        # dispatched as cas:<name>
│   ├── product-designer.md        # kickoff Q&A + lean spec + mockup variants; gap review (read-only)
│   ├── planner.md                 # decomposes a task → plan + tests + surface impact  (read-only)
│   ├── test-engineer.md           # writes & runs meaningful unit tests
│   ├── e2e-tester.md              # boots the app on the VM, smokes it, screenshots it
│   ├── code-reviewer.md           # reviews diff: correctness / quality / reuse          (read-only)
│   ├── security-reviewer.md       # audits diff against a threat checklist               (read-only)
│   └── ux-reviewer.md             # critiques the rendered UI vs spec + design contract  (read-only)
├── skills/
│   └── frontend-design/           # vendored Anthropic skill (Apache-2.0) → cas:frontend-design
└── profiles/                      # permission profiles — a plugin can't ship settings, so /cas:setup installs one
    ├── settings.ssh-sandbox.json  # DEFAULT: limited host, free VM reached over SSH
    ├── settings.bash-sandbox.json # mac/Linux/WSL2, no separate VM: built-in OS Bash sandbox
    └── settings.vm-bypass.json    # when Claude Code runs INSIDE a disposable VM/container
```

## Install

```bash
claude plugin marketplace add grappeq/claude-agentic-stack        # once per machine
cd /path/to/your-repo
claude plugin install cas@claude-agentic-stack --scope project    # enable it for this repo
claude                                                            # start a session there …
```

…then, inside the session, run **`/cas:setup`**. A plugin can carry commands, agents, skills, and hooks — but not a permission policy — so `/cas:setup` installs the rest into your repo: it asks which isolation profile fits your setup (see *Isolation model* below) and writes it to `.claude/settings.json` (merging with what's there, showing the diff first), probes the sandbox, adds the **`.agentic/`** ignore guard (run evidence — screenshots, mockups, progress logs — can contain secrets or PII and must never be committed; the stack also drops a `.agentic/.gitignore` of `*` on first run as a backstop), writes a short `CLAUDE.md` pointer if you have none (if you do, it prints the lines to add), and registers the marketplace + plugin in `.claude/settings.json` so collaborators who trust the folder get it too. Restart the session afterwards — permission settings are read at startup.

Install scope: `--scope project` records the plugin in the repo's `.claude/settings.json` (shared via version control); `--scope user` enables it in every repo on the machine — use that on a CI runner (a headless `claude -p "/cas:build …"` needs the plugin installed on the runner). Confirm what loaded with `claude plugin details cas@claude-agentic-stack`; in a session, type `/cas:` to see the commands.

## Two postures

The same machinery runs in two modes — pick by the work:

- **`/cas:build <task>` — precision.** Changing an existing system: smallest viable change, reuse first, match conventions. A single pass with an inner convergence loop.
- **`/cas:prototype <vision>` — prototype.** Turning a broad vision into a working app: a **brief kickoff interview** (a few questions plus one design pick) pins down the need, then it runs **autonomously** — making the product and UX calls itself (recording assumptions) and **iterating across milestones** until the vision is met. Built for long, unattended runs.

### Precision loop — `/cas:build`

```
/cas:build <task>
   │  understand  ── reuse first; Explore agent for broad search
   │  plan        ── cas:planner agent (non-trivial) → durable target: .agentic/task.md
   │  mockup†     ── /cas:mockup when the plan reports a new surface → .agentic/design.md
   │  implement   ── edit on host; smallest viable change, match conventions
   │  /cas:verify     ── on the VM: build + lint + tests + RUNTIME SMOKE → green
   │                   (cas:test-engineer adds units · cas:e2e-tester boots & drives the app)
   │  REVIEW GATE ── cas:code-reviewer ‖ cas:security-reviewer ‖ cas:ux-reviewer*  (parallel, read-only)
   │  resolve     ── fix Critical/High, re-verify, re-review changed dimensions
   └─ report      ── auto-commit on green (work branch) ──► /cas:ship to push / open a PR
                                          * cas:ux-reviewer only when the diff touches UI
                                          † only for a new screen / endpoint / command / schema
```

### Prototype loop — `/cas:prototype`

```
/cas:prototype <vision>
   │  KICKOFF (interactive)  ── cas:product-designer proposes the few high-leverage
   │     questions → you answer (AskUserQuestion) → lean .agentic/spec.md written
   │     → spec checkpoint (one confirm) → /cas:mockup: pick a design for M1's key
   │     surfaces → .agentic/design.md frozen → gate closes, no more questions
   │          (headless: no Q&A or pick — defaults; /cas:mockup still runs, design=auto)
   │  ┌─ per milestone, autonomous ───────────────────────────────────┐
   │  │  plan → mockup (auto, new surfaces) → implement → /cas:verify      │
   │  │  REVIEW GATE: code ‖ security ‖ ux* → resolve until clean      │
   │  │     (stuck? circuit-breaker: 3 tries, then route around/stop)  │
   │  │  GAP REVIEW vs spec + design: ITERATE · ADVANCE · DONE · ASK   │
   │  │  checkpoint → .agentic/progress.md  (survives compaction)      │
   │  └───────────────────────────────────────────────────────────────┘
   │        ⟲ until spec met, round budget spent (default 3), or ASK
   └─ commit each milestone on green · report ──► /cas:ship to push / open a PR
                              * ux only for milestones that render UI
```

The orchestrator is the main Claude thread — and the one that **writes the code**. The agents are isolated-context leaf workers that **find** problems and assess progress; the orchestrator **implements**, **fixes**, and coordinates. There's deliberately **no "software-engineer" agent**: production implementation wants the full context the main thread already holds — the plan, the spec, the live review findings — and stays coupled to the fix loop, whereas search, review, and test-authoring are the bounded jobs that actually benefit from a clean, isolated context. (Subagents also can't spawn subagents, so coordination lives in the main thread regardless.)

## Three loops

Work converges through three loops — it helps to name them:

- **L1 — Convergence loop (inner).** `resolve → re-verify → re-review` until smoke is green and code / security / ux are clean. This is *reactive*: it drives the work to a correctness bar by fixing defects. But it never makes the product *better* — only *correct*. A blank-but-valid app passes L1.
- **L2 — Improvement loop (outer).** Build → critique against the vision → build the next increment → repeat. This is *generative*: it makes the thing more complete and more polished over successive rounds. It's the half that takes a broad vision and improves on it itself, rather than only making a given change correct — and it's what `/cas:prototype` adds on top of L1.
- **L3 — Human iteration.** You read the report (and screenshots) and send the next prompt, edit `.agentic/spec.md` or `.agentic/design.md` to steer the next run, or `/cas:resume` to continue an interrupted one. Always there.

So `/cas:build` is mostly L1; `/cas:prototype` is L2 wrapping L1, then back to you (L3).

## Usage

- **Prototype from a vision:** `/cas:prototype a habit tracker with streaks and weekly stats` — a few kickoff questions and one design pick, then it designs, builds, iterates across milestones, and screenshots it autonomously.
- **Precision change:** `/cas:build add rate limiting to the login endpoint` — when the plan reports a new user-facing surface (a screen, endpoint, command, or schema) it stops once for a design pick; `design=auto` takes the recommended default, `design=skip` bypasses it.
- **Design checkpoint on its own:** `/cas:mockup the settings screen` — 2–3 variants (web artboards, a CLI storyboard, API examples, a schema, or an architecture spine, by medium), your pick, frozen as a contract in `.agentic/design.md` that reviewers hold the build to.
- **Resume an interrupted run:** `/cas:resume` — reloads the `.agentic/` state (task/spec + progress), reconciles it with the repo, and re-enters the loop where it left off. Works after a crash, a closed session, or when you deliberately restart with a fresh context instead of grinding on a degraded one. Pass steering as arguments: `/cas:resume drop the CSV export, ship the rest`.
- **Just review what you have:** `/cas:review` (or `/cas:review staged`)
- **Just run the gate:** `/cas:verify`
- **Set up a repo:** `/cas:setup` — once per repo; idempotent, so re-run it after changing the sandbox alias or profile.
- **Auto-commit:** the loop commits on green automatically, on a work branch — you don't run anything.
- **Sync with the base branch:** `/cas:sync` brings your work branch up to date with master — resolving any conflicts safely and re-running the gate — local only, never pushes. `/cas:ship` runs it automatically first, but you can also run it mid-work.
- **Publish when ready:** `/cas:ship` re-confirms the gate, curates the commit, syncs with the base, then pushes and opens a PR — invoking it (the model can't self-trigger it) is your go-ahead to publish. e.g. `/cas:ship feat: add login rate limiting`.
- **Headless / CI:** `claude -p "/cas:build add rate limiting to the login endpoint"` (the plugin must be installed on the runner — `--scope user` — and the sandbox VM reachable via `ssh sandbox`; any design pick takes the recommended default)
- **Deeper one-off audits:** the built-in `/code-review` and `/security-review` skills complement the in-loop gate.

## Isolation model — pick the profile that matches your setup

The agent runs on a **limited host** and offloads real execution to an **isolated sandbox**, so it can act freely without endangering the host. `/cas:setup` asks which profile matches how your sandbox is reached (or pass `profile=ssh|bash|vm`) and installs it into `.claude/settings.json`. `deny` rules are enforced from every scope and even override `allow`, so the host floor holds regardless of mode.

| Your setup | Profile | Host vs. sandbox |
|------------|---------|------------------|
| **Claude Code on a host that SSHes into a separate sandbox VM** | **`profile=ssh` (default)** | Host: edit + `git` + sync only; dangerous ops and secret reads (`~/.ssh`, `~/.aws`, `.env`) denied. VM (`ssh sandbox …`): **unrestricted** — every build/test/install runs there. |
| Claude Code on **macOS / Linux / WSL2**, no separate VM | `profile=bash` | The built-in [OS Bash sandbox](https://code.claude.com/docs/en/sandboxing) confines bash + child processes to the workspace, denies credentials, allowlists network; auto-allow = no prompts inside the boundary. |
| Claude Code runs **inside a disposable VM / container / [sandbox-runtime](https://code.claude.com/docs/en/sandbox-environments)** | `profile=vm` | The VM/container is the wall; `bypassPermissions` is fine inside it; your real host is unreachable. Required for fully unattended `--dangerously-skip-permissions`. |

### Set up the SSH sandbox (default profile)

1. Provision a disposable Linux VM with the toolchains your projects need (node, python, go, …).
2. Add an SSH alias named **`sandbox`** to `~/.ssh/config` on the host:
   ```
   Host sandbox
       HostName <your-vm-ip>
       User dev
       IdentityFile ~/.ssh/sandbox_key
   ```
   The profile's allow-rule `Bash(ssh sandbox *)` keys off this exact alias. Keep `sandbox` unless you have to: `/cas:setup alias=<name>` rewrites the allow-rules and records the alias in your `CLAUDE.md`, but the commands' own examples still say `ssh sandbox`.
3. Pick the remote working directory with `/cas:setup dir=<path>` (default `~/agentic-workspace`); it lands in `SANDBOX_REMOTE_DIR` in `.claude/settings.json`.
4. Make sure `rsync` is available on host and VM for fast syncs (`scp -r` is the fallback).
5. For **frontend e2e** — the runtime smoke that boots a browser and screenshots the UI — install a headless browser on the VM: `npx playwright install --with-deps chromium`. Without it, `/cas:verify`'s runtime smoke degrades gracefully to an HTTP-level check and `cas:ux-reviewer` reports that no screenshots were available.

`/cas:setup` probes each of these (VM reachable, `rsync` on both ends, toolchains for the manifests it finds, headless Chromium) and prints a ✓/✗ line with the fix for anything missing. Now `/cas:verify` syncs the working tree to the VM and runs build/lint/test there; the host only edits and commits. Edits happen on the host (Claude's `Read`/`Edit`/`Write`), execution happens on the VM (`ssh sandbox …`).

> **Why SSH and not the OS Bash sandbox here?** The built-in Bash sandbox doesn't run on native Windows, and it only confines Bash (not MCP/hooks). A real VM reached over SSH gives a stronger, OS-independent boundary and matches a "controller host + disposable worker" topology. The other two profiles are there if your setup differs.

## Customize

Plugin files live in Claude Code's plugin cache and are **replaced on `claude plugin update`**, so don't edit them in place. Per-repo tuning goes in your own `CLAUDE.md` — the operating manual is injected alongside it and defers to it for project specifics:

- **Sandbox target** — a non-default SSH alias or remote dir: pass `alias=` / `dir=` to `/cas:setup` (it keeps the allow-rules and `SANDBOX_REMOTE_DIR` in sync and records them in your `CLAUDE.md`).
- **Security checklist** — add your domain's threats (payment flows, PII handling, tenancy isolation) to your `CLAUDE.md`; `cas:security-reviewer` extends its checklist per project.
- **Verify gate / runtime smoke** — state your exact build, lint, test, and boot commands and the user flows the smoke should drive in your `CLAUDE.md`; `/cas:verify` and `cas:e2e-tester` prefer the project's own scripts over their generic detection.
- **Iteration depth** — pass `rounds=N` to `/cas:prototype`, or set a default in your `CLAUDE.md`.
- **Design checkpoint** — pass `design=ask|auto|skip` and `fidelity=wireframe|styled` to `/cas:build`, `/cas:prototype`, or `/cas:mockup` per run.
- **Run artifacts** — a `/cas:build` run writes its task, acceptance criteria, and live plan checklist to `.agentic/task.md`; a `/cas:prototype` run writes its frozen vision to `.agentic/spec.md` and live progress to `.agentic/progress.md`; `/cas:mockup` writes the approved design contract to `.agentic/design.md` with the mockups under `.agentic/design/` (all git-ignored). Read them to see where an autonomous run is, edit them between runs to redirect it, or `/cas:resume` to continue it.
- **Everything else** — the Definition of Done, the mockup medium table, the reviewers' severities, agent models (`cas:code-reviewer` runs on `sonnet` for speed; the rest `inherit` your session model for rigor) — fork the repo, edit, and point your marketplace at the fork: `claude plugin marketplace add <you>/claude-agentic-stack`. To develop the stack itself, add your checkout as a local marketplace (`claude plugin marketplace add /path/to/checkout`) and install from it.

## Design notes

- **Two-layer security model** — *isolation* (the sandbox VM / OS sandbox) protects the **host**; the *review gate* is semantic and protects the **codebase**. Neither substitutes for the other, and the stack ships both.
- **Review-agents enforcement, not blocking hooks** — the gate is semantic (AI review) and lives in the workflow, so it adapts to any language without per-repo hook scripts. The plugin's only hook is the `SessionStart` one that injects the manual.
- **Read-only reviewers** — reviewers can't edit, so they can never silently "fix and pass" their own findings. Clean find/fix separation. This now extends to **UX**: `cas:ux-reviewer` critiques the rendered UI with fresh eyes instead of the builder grading its own design.
- **Runtime smoke, not just unit tests** — the gate boots and drives the assembled app (browser / API / CLI), so "it compiles" can't masquerade as "it works". The screenshots double as e2e evidence and as the input to independent UX review.
- **Generative + evaluative symmetry** — the stack pairs a *maker* and a *critic* for each concern: code (`cas:planner` → `cas:code-reviewer`/`cas:security-reviewer`) product/UX (`cas:product-designer` → `cas:ux-reviewer`), and now design (`cas:product-designer` DESIGN: PROPOSE → `cas:ux-reviewer` design-fidelity check, or `cas:e2e-tester` golden assertions for CLI/API surfaces), with `cas:product-designer` also closing the loop by gap-checking the build against its own spec and the approved design.
- **The orchestrator is the implementer** — there's no dedicated "coder" agent, by design. The subagents are the roles that gain from an isolated context (broad search, adversarial review, bounded test-authoring against a frozen diff); open-ended production implementation instead wants the orchestrator's full context and lives in the resolve loop where it fixes what the reviewers find. Delegating it would break the find/fix separation and add lossy clean-context round-trips on every fix.
- **Commit vs. publish** — the agent auto-commits on a work branch once the gate is green (local, reversible, no prompt), but *publishing* — push, PR, release — stays human-gated via `/cas:ship`. The boundary is external visibility, not the git verb.
- **Built for long autonomous runs** — `/cas:prototype` front-loads a brief kickoff interview (spec + one design pick), then runs hands-off. The frozen vision (`.agentic/spec.md`) and a progress log (`.agentic/progress.md`) are durable, so a run survives context compaction; a circuit-breaker caps repeated failed fixes (3 tries) so a stuck check can't burn the session. `cas:ux-reviewer` compares screenshots round-over-round to catch UI regressions.
- **Interruptible by design** — every run keeps a durable target on disk (`task.md` for `/cas:build`, `spec.md` + `progress.md` for `/cas:prototype`, `design.md` for either), so `/cas:resume` can re-enter it from a *fresh* session: reload the state, reconcile it against git (the repo wins on code facts), re-verify, continue. Deliberately restarting with a clean context beats grinding on a degraded one — the useful half of the "Ralph loop" pattern, without the bash loop. Starting a new run surfaces any unfinished one instead of silently overwriting its state.
- **Design before code, by medium** — the design checkpoint (`/cas:mockup`) exists because the cheapest moment to redirect a design is before it is built, and the loop otherwise shows you a design only after a milestone is built, verified, and reviewed. It is deliberately about the *surface* a user or caller experiences, not about pixels: web artboards, a CLI storyboard, API request/response examples, a schema, or an architecture spine — so it works for a backend service as well as a web app, and for text media the approved examples become the smoke assertions. `/cas:build` only runs it when the plan reports a genuinely new surface (a change *to* an existing screen follows its design system), and `/cas:prototype` asks once at kickoff and defaults later surfaces, so the "brief kickoff, then hands-off" promise holds. Web mockups are static HTML artboards rendered on the sandbox VM with Playwright; when the session has the built-in `design` skill's canvas (`/design`; a research preview — claude.ai login only, not API-key, Bedrock, or Vertex) it doubles as a nicer, hand-tweakable preview, but the stack never depends on it: the HTML + PNG under `.agentic/design/` are the evidence the read-only reviewers can actually open.
- **Why three target files** — `task.md`, `spec.md`, and `design.md` are the same pattern (durable target + live state) split by **authority**, not structure. The spec is a *user-confirmed contract*: drafted from your interview answers, approved at the spec checkpoint, then frozen — so a long unsupervised run converges on a target the agent can't quietly move; only the user edits it. The task file is the agent's own working restatement of a short, supervised change — continuously edited, never blessed, folding target and progress into one file because a single-milestone run doesn't need the split. One shared filename would let agent notes wear contract-grade authority (a misread task would be enshrined as if confirmed). The filename *is* the permission model: `spec.md` = the agent never edits it; `task.md` = the agent keeps it live. `design.md` is a second user-confirmed contract — a concrete artifact (mockup, transcript, examples) rather than a vision outline — kept separate from `spec.md` because it is approved at a different moment, per surface, and can be re-run with `/cas:mockup` without reopening the vision; the same rule applies: only `/cas:mockup` writes it, and each section records whether the user picked it or it was defaulted (assumption-grade, not contract-grade).
- **Warm sandbox, cold path removed** — the loop kicks off the VM dependency install during the *implement* phase, so it finishes in the background instead of sitting cold on the critical path at `/cas:verify`. Ecosystem-agnostic (it uses whatever install the manifest implies) and best-effort — `/cas:verify` still runs the authoritative install, so the gate is unchanged; it only reclaims latency.
- **No required MCP / Node / jq** — the stack is pure markdown and JSON. The hook is a bare `cat`; `/cas:setup`'s settings merge is done by the model with the diff shown before writing, so nothing needs a JSON tool on the host.
- **Packaged as a plugin** — a plugin can't ship a `CLAUDE.md` or a permission policy, which is exactly the two things this stack is built on. So the manual ships as `MANUAL.md` and a `SessionStart` hook injects it (at startup, resume, clear, and after compaction — subagents don't see session context, so the agents read `${CLAUDE_PLUGIN_ROOT}/MANUAL.md` themselves), and the permission profiles ship as data under `profiles/` that the human-only `/cas:setup` installs into the repo — showing the diff first, and never choosing a policy in a headless run. The workflows stay single-file `commands/*.md` for readability; they could migrate to `skills/<name>/SKILL.md` for supporting files or `context: fork` execution, and would still be `/cas:<name>`.
- **Vendored design skill** — `/cas:prototype` closes its generative UI gap with Anthropic's [`frontend-design`](https://github.com/anthropics/skills) skill, vendored inside the plugin at `skills/frontend-design/` and loaded as `cas:frontend-design` (pure markdown — every user and headless run gets it with the plugin, no separate install). It fires only for **web UI** milestones; `cas:ux-reviewer` critiques against the same principles, completing the maker/critic pairing for design.
- **Future hardening** — if you ever want a *non-bypassable* gate (e.g. for unattended fleets), add a `Stop` hook that refuses to end a turn until `/cas:review` has passed. Intentionally omitted here to keep enforcement agent-based.

## License

Released under the [MIT License](LICENSE) — © 2026 Kacper Grabowski. Free to use, fork, and adapt.

Exception: `skills/frontend-design/` is vendored from [anthropics/skills](https://github.com/anthropics/skills), © Anthropic, under the **Apache License 2.0** (see the `LICENSE.txt` in that folder; modifications are marked in its `SKILL.md`). The notice ships inside the plugin with the folder.
