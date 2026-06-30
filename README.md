# Agentic Dev Stack

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
    │   ├── planner.md                 # decomposes a task → plan + test strategy   (read-only)
    │   ├── code-reviewer.md           # reviews diff: correctness / quality / reuse (read-only)
    │   ├── security-reviewer.md       # audits diff against a threat checklist      (read-only)
    │   └── test-engineer.md           # writes & runs meaningful tests
    └── commands/
        ├── build.md     →  /build     # the full loop, end to end
        ├── verify.md    →  /verify    # language-agnostic build + lint + test gate
        ├── review.md    →  /review    # both reviewers in parallel → one report
        └── ship.md      →  /ship      # gated conventional commit (user-only)
```

## Install

Copy the two pieces into the root of your target repo:

```bash
cp -r /path/to/agentic-dev-stack/.claude  /path/to/your-repo/.claude
cp    /path/to/agentic-dev-stack/CLAUDE.md /path/to/your-repo/CLAUDE.md
```

(Already have a `CLAUDE.md`? Merge the "Operating loop / Definition of Done / Orchestration contract" sections into yours.) Start Claude Code in the repo and run `/agents` to confirm the four agents loaded, and `/` to see `/build`, `/verify`, `/review`, `/ship`.

## The loop

```
/build <task>
   │  understand  ── reuse first; Explore agent for broad search
   │  plan        ── planner agent (non-trivial tasks)
   │  implement   ── edit on host; smallest viable change, match conventions
   │  /verify     ── sync to VM, run build + lint + tests on the VM → green  (test-engineer adds tests)
   │  REVIEW GATE ── code-reviewer ‖ security-reviewer  (parallel, read-only, on the host diff)
   │  resolve     ── fix Critical/High, re-verify, re-review if security code changed
   └─ report      ──► you run /ship → gated conventional commit
```

The orchestrator is the main Claude thread; the agents are isolated-context leaf workers that **find** problems. The orchestrator **fixes** them. (Subagents can't spawn subagents, which is why coordination lives in the main thread.)

## Usage

- **Interactive:** `/build add rate limiting to the login endpoint`
- **Just review what you have:** `/review` (or `/review staged`)
- **Just run the gate:** `/verify`
- **Commit when clean:** `/ship` — or `/ship feat: add login rate limiting`
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
       HostName 10.0.0.42
       User dev
       IdentityFile ~/.ssh/sandbox_key
   ```
   The default profile's allow-rule `Bash(ssh sandbox *)` keys off this exact alias — keep `sandbox`, or rename it in both the SSH config and `settings.json`.
3. Set the remote working directory via `SANDBOX_REMOTE_DIR` in `.claude/settings.json` `env` (default `~/agentic-workspace`).
4. Make sure `rsync` is available on host and VM for fast syncs (`scp -r` is the fallback).

Now `/verify` syncs the working tree to the VM and runs build/lint/test there; the host only edits and commits. Edits happen on the host (Claude's `Read`/`Edit`/`Write`), execution happens on the VM (`ssh sandbox …`). `deny` rules are enforced from every scope and even override `allow`, so the host floor holds regardless of mode.

> **Why SSH and not the OS Bash sandbox here?** The built-in Bash sandbox doesn't run on native Windows, and it only confines Bash (not MCP/hooks). A real VM reached over SSH gives a stronger, OS-independent boundary and matches a "controller host + disposable worker" topology. The other two profiles are there if your setup differs.

## Customize

- **Sandbox target** — change the SSH alias (`sandbox`) and remote dir (`SANDBOX_REMOTE_DIR`) in `.claude/settings.json`; keep the `Bash(ssh <alias> *)` allow-rule in sync.
- **Security checklist** — edit `.claude/agents/security-reviewer.md`; add your domain's threats (e.g. payment flows, PII handling, tenancy isolation).
- **Verify gate** — edit `.claude/commands/verify.md` to add an ecosystem or point at your repo's exact build/test commands (they run on the VM over SSH).
- **Definition of Done** — edit `CLAUDE.md`; it's the contract every task is held to.
- **Model/cost** — agent frontmatter sets the model (`code-reviewer` → `sonnet` for speed; `security-reviewer` → `inherit`, i.e. your session model, for rigor). Tune per the cost/depth trade-off you want.

## Design notes

- **Two-layer security model** — *isolation* (the sandbox VM / OS sandbox) protects the **host**; the *review gate* is semantic and protects the **codebase**. Neither substitutes for the other, and the stack ships both.
- **Review-agents enforcement, not blocking hooks** — the gate is semantic (AI review) and lives in the workflow, so it adapts to any language without per-repo hook scripts.
- **Read-only reviewers** — reviewers can't edit, so they can never silently "fix and pass" their own findings. Clean find/fix separation.
- **No required MCP / Node / jq** — the stack is pure config and drop-in anywhere.
- **Commands vs skills** — these workflows are single-file `.claude/commands/*.md` for readability. They can be migrated to `.claude/skills/<name>/SKILL.md` if you want supporting files or `context: fork` execution; both produce the same `/name`.
- **Future hardening** — if you ever want a *non-bypassable* gate (e.g. for unattended fleets), add a `Stop` hook that refuses to end a turn until `/review` has passed. Intentionally omitted here to keep enforcement agent-based.
