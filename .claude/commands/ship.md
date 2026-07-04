---
description: Finalize & publish — confirm the Definition of Done, curate the commit, sync with the base branch, then push and open a PR. User-invoked; invoking it is your authorization to publish.
argument-hint: [optional commit message]
disable-model-invocation: true
allowed-tools: Bash(git add *), Bash(git commit *), Bash(git status *), Bash(git diff *), Bash(git log *), Bash(git branch *), Bash(git switch *), Bash(git fetch *), Bash(git merge *), Bash(git rev-parse *)
---

Finalize the current work and publish it. The loop already **auto-commits on green** (see CLAUDE.md → *Committing & publishing*), so this is the curated **publish** path. `/ship` is `disable-model-invocation` — the model can never trigger it, so a human typing `/ship` **is** the authorization to publish; there is no second ask. Force-push stays denied and each push/PR still surfaces a permission prompt as a backstop.

1. **Gate.** Confirm the work is shippable — before committing, so a red gate is never committed:
   - `/verify` is green (run it if you have not this turn).
   - The review gate passed (run `/review` if you have not reviewed the current diff).

   If either fails, STOP and report what is blocking — do not commit or publish.

2. **Commit / curate.** Show `git status` and `git diff`. If there are uncommitted changes, ensure you are on a work branch (not the default branch), stage only the intended files **by explicit path** (never secrets, `.env`, `.agentic/`, or unrelated files), and commit with a [Conventional Commits](https://www.conventionalcommits.org/) message — use `$ARGUMENTS` as the subject if provided, otherwise derive it from the diff. If the loop already committed, optionally tidy the message or squash on the work branch — but **only if the branch has not been pushed** (rewriting a pushed branch needs a force-push, which is off-limits; otherwise leave history as-is). Confirm with `git log -1 --stat`.

3. **Sync.** With the tree now clean, run `/sync` to bring the branch up to date with its base so the PR opens conflict-free. If it returns `SYNC: BLOCKED`, STOP and report — do not publish a branch that will not cleanly integrate. `SYNC: CLEAN` or `SYNC: PASS` → continue. If `/sync` merged anything it already re-ran the gate (and committed the merge) on the integrated result, so step 1's gate need not be repeated.

4. **Publish.** Push the branch and open a PR with `gh`. This is the defined purpose of `/ship`, so it needs no further confirmation beyond the permission prompt each command surfaces — that prompt is the backstop; force-push stays denied. Honor a narrower explicit request when the user gave one (e.g. "just push, no PR"). Report the pushed branch and PR URL when done.
