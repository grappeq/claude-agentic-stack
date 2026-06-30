---
description: Finalize & publish — confirm the Definition of Done, curate the commit, and (only if asked) push or open a PR. User-invoked.
argument-hint: [optional commit message]
disable-model-invocation: true
allowed-tools: Bash(git add *), Bash(git commit *), Bash(git status *), Bash(git diff *), Bash(git log *), Bash(git branch *), Bash(git switch *)
---

Finalize the current work. The loop already **auto-commits on green** (see CLAUDE.md → *Committing & publishing*), so this is the curated **publish** path — but it still holds the gate.

1. **Gate.** Confirm the work is shippable:
   - `/verify` is green (run it if you have not this turn).
   - The review gate passed (run `/review` if you have not reviewed the current diff).

   If either fails, STOP and report what is blocking — do not commit or publish.

2. **Commit / curate.** Show `git status` and `git diff`. If there are uncommitted changes, ensure you are on a work branch (not the default branch), stage only the intended files (never secrets, `.env`, `.agentic/`, or unrelated files), and commit with a [Conventional Commits](https://www.conventionalcommits.org/) message — use `$ARGUMENTS` as the subject if provided, otherwise derive it from the diff. If the loop already committed, optionally tidy the message or squash on the work branch — but **only if the branch has not been pushed** (rewriting a pushed branch needs a force-push, which is off-limits; otherwise leave history as-is). Confirm with `git log -1 --stat`.

   Pushing and PRs are not pre-authorized here, so each publish action in step 3 surfaces a permission prompt — that prompt is the backstop; force-push stays denied.

3. **Publish — only if the user asked.** Push the branch, and/or open a PR with `gh`, **only** when the user explicitly requested it in this invocation. Never force-push a shared branch. If they did not ask to publish, stop after committing and tell them the branch is ready to push.
