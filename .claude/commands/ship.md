---
description: Gated commit — verify the Definition of Done holds, then create a conventional commit. User-invoked only.
argument-hint: [optional commit message]
disable-model-invocation: true
allowed-tools: Bash(git add *), Bash(git commit *), Bash(git status *), Bash(git diff *), Bash(git log *), Bash(git branch *)
---

Create a commit for the current changes — but only if the Definition of Done holds.

1. **Gate.** Confirm the work is shippable:
   - `/verify` is green (run it if you have not this turn).
   - The review gate passed (run `/review` if you have not reviewed the current diff).

   If either fails, STOP and report what is blocking — do not commit.

2. **Stage & inspect.** Show `git status` and `git diff`. Stage the intended changes with `git add`. Never stage secrets, `.env` files, or unrelated artifacts.

3. **Commit.** Write a [Conventional Commits](https://www.conventionalcommits.org/) message (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:` …). Use `$ARGUMENTS` as the subject if provided; otherwise derive a concise, accurate subject from the diff. Keep the body to the what and the why.

4. Confirm with `git log -1 --stat`. Do **not** push, force-push, or open a PR unless the user explicitly asks — those are out-of-repo / irreversible actions per CLAUDE.md.
