#!/bin/sh
# Tests for hooks/review-guard.sh, with synthetic hook inputs in a scratch repo. POSIX sh + git; no Claude calls.
# usage: sh tests/review-guard.test.sh
G="$(cd "$(dirname "$0")/.." && pwd)/hooks/review-guard.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export CLAUDE_PLUGIN_DATA="$T/data"
R="$T/repo"; mkdir -p "$R"; cd "$R" || exit 1
git init -q -b work; git config user.name t; git config user.email t@example.invalid
printf 'a\n' > a.txt; git add a.txt; git commit -qm init
pass=0; fail=0

dispatch() { printf '{"tool_name":"Agent","tool_input":{"description":"r","prompt":"p","subagent_type":"%s"}}' "$1" | sh "$G" start; }
finish() { printf '{"hook_event_name":"SubagentStop","agent_type":"%s","last_assistant_message":"findings...\\n\\nGATE: %s"}' "$1" "$2" | sh "$G" stop; }
review() { dispatch "cas:$1"; finish "cas:$1" "$2"; }
gate() { printf '{"tool_name":"Bash","tool_input":{"command":"%s","description":"x"}}' "$1" | sh "$G" commit 2>"$T/err"; }
expect() { # expect <allow|block> <name> <command>
  gate "$3"; rc=$?
  if { [ "$1" = allow ] && [ $rc -eq 0 ]; } || { [ "$1" = block ] && [ $rc -eq 2 ]; }; then pass=$((pass + 1)); echo "ok   $2"
  else fail=$((fail + 1)); echo "FAIL $2 (rc=$rc)"; sed 's/^/     /' "$T/err"; fi
}

printf 'a\nb\n' > a.txt
expect allow "no cas run, no reviews: not enforced" 'git commit -am x'
mkdir -p .agentic; printf '*\n' > .agentic/.gitignore; printf 'Task: x\nStatus: reviewing\n' > .agentic/task.md
expect block "open task, no reviews" 'git commit -am x'
expect allow "not a commit: git status" 'git status --short'
expect allow "not a commit: git log --grep commit" 'git log --grep commit'
review code-reviewer PASS
expect block "only the code review passed" 'git commit -am x'
review security-reviewer PASS
expect allow "both passed on this content (unstaged, -a)" 'git commit -am x'
git add a.txt
expect allow "both passed on this content (staged)" 'git commit -m \"feat: b\"'
printf 'a\nb\nc\n' > a.txt
expect block "edited after the passing reviews" 'git commit -am x'
expect block "detected after cd &&" 'cd sub && git commit -m x'
expect block "detected with git -C" 'git -C . commit -m x'
expect block "detected with git -c k=v" 'git -c core.editor=true commit'
git add a.txt
review code-reviewer PASS
expect block "re-review by code only" 'git commit -m x'
review security-reviewer PASS
expect allow "both re-reviewed" 'git commit -m x'
review security-reviewer FAIL
expect block "latest security verdict FAIL" 'git commit -m x'
review security-reviewer PASS
dispatch cas:code-reviewer; printf 'z\n' >> a.txt; finish cas:code-reviewer PASS
expect block "edit while a review ran (stale)" 'git commit -am x'
git checkout -q -- a.txt; git add a.txt; git diff --cached --quiet && echo "     (setup: nothing staged?)"
review code-reviewer PASS
printf 'scratch\n' > notes.tmp
expect allow "untracked file not staged" 'git commit -m x'
git add notes.tmp
expect block "untracked file staged after review" 'git commit -m x'
git rm -q --cached notes.tmp; rm notes.tmp
printf 'x\n' > b.txt; git add b.txt; review code-reviewer PASS; review security-reviewer PASS
git reset -q -- b.txt
expect allow "commit only part of a reviewed diff" 'git commit -m x'
printf 'y\n' > b.txt
expect allow "an untracked unstaged file can't be committed, so it doesn't block" 'git commit -m x'
rm b.txt
cp a.txt "$T/a.keep"; printf 'unreviewed\n' >> a.txt
expect block "an unreviewed edit to a tracked file, left unstaged, blocks" 'git commit -m x'
cp "$T/a.keep" a.txt
finish cas:code-reviewer PASS
expect block "a pass with no recorded dispatch (unseen)" 'git commit -m x'
review code-reviewer PASS
dispatch Explore; finish Explore PASS
expect allow "non-reviewer agents ignored" 'git commit -m x'
review ux-reviewer FAIL
expect block "ux reviewed this cycle and failed" 'git commit -m x'
review ux-reviewer PASS
expect allow "ux passed too" 'git commit -m x'
finish cas:code-reviewer NONE
expect block "a reply with no GATE line" 'git commit -m x'
review code-reviewer PASS
expect block "an edit chained before the commit (runs after the check)" 'echo z >> a.txt && git commit -am x'
# shellcheck disable=SC2016  # the $( is part of the command under test
expect allow "cd, git add and a heredoc message are fine" 'cd . && git add a.txt && git commit -m \"$(cat <<EOF\\nfeat: c; with | stuff\\nEOF\\n)\"'
expect allow "output piped after the commit is fine" 'git commit -am x 2>&1 | tail -20'
printf 'new\n' > c.txt
expect allow "unreviewed untracked file, plain commit" 'git commit -m x'
expect block "unreviewed untracked file, git add -A first" 'git add -A && git commit -m x'
rm c.txt
gate 'git commit -m x' && git commit -qm "feat: c"
printf 'Task: x\nStatus: done\n' > .agentic/task.md
printf 'a\nb\nc\nd\n' > a.txt
expect allow "after the commit: new HEAD, task done" 'git commit -am x'
printf 'Task: y\nStatus: implementing\n' > .agentic/task.md
expect block "next task open, reviews were on the old HEAD" 'git commit -am x'
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
