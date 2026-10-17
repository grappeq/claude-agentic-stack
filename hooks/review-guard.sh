#!/bin/sh
# Review guard: a commit made during a cas run must contain exactly the content the latest passing code and
# security reviews saw (MANUAL.md -> Committing & publishing). Three entry points, wired in hooks.json:
#   review-guard.sh start   PreToolUse on Agent: a reviewer is dispatched -> snapshot what it will review
#   review-guard.sh stop    SubagentStop on a reviewer: record its final GATE verdict against that snapshot
#   review-guard.sh commit  PreToolUse on Bash: block `git commit` unless every required review covers the diff
# POSIX sh + git only. Records live in the plugin data dir, outside the project, so a run can't write them.
# A snapshot is HEAD plus one "<path><TAB><blob>" line per path that differs from HEAD (tracked, staged or
# untracked-not-ignored), sorted. A reviewer's pass counts only if the tree didn't change while it ran.

mode="${1:-}"
input=$(cat)

repo=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$repo" || exit 0
G="git -c core.quotePath=false"

key=$(printf '%s' "$repo" | git hash-object --stdin)
state="${CLAUDE_PLUGIN_DATA:-${HOME}/.cache/cas}/review/$key"

# The first "<name>":"<value>" string in the hook input, JSON escapes left as they are.
field() {
  printf '%s' "$input" | grep -oE "\"$1\":[[:space:]]*\"([^\"\\\\]|\\\\.)*\"" | head -n 1 | sed -E "s/^\"$1\":[[:space:]]*\"//; s/\"\$//"
}

# A cas reviewer's short name (code-reviewer, security-reviewer, ux-reviewer), or nothing.
reviewer_of() {
  printf '%s' "$1" | sed -nE 's/^(cas:)?((code|security|ux)-reviewer)$/\2/p'
}

snapshot() {
  head=$(git rev-parse --verify -q HEAD) || head=none
  base=$head; [ "$head" = none ] && base=$(git hash-object -t tree /dev/null)
  printf 'HEAD %s\n' "$head"
  { $G diff --name-only "$base" --; $G ls-files --others --exclude-standard; } | sort -u | while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$p" in .agentic/*) continue ;; esac
    if [ -f "$p" ] || [ -L "$p" ]; then printf '%s\t%s\n' "$p" "$(git hash-object -- "$p")"
    else printf '%s\tdeleted\n' "$p"; fi
  done
}

case "$mode" in
start)
  r=$(reviewer_of "$(field subagent_type)"); [ -n "$r" ] || exit 0
  mkdir -p "$state/pending" && snapshot > "$state/pending/$r"
  exit 0
  ;;
stop)
  r=$(reviewer_of "$(field agent_type)"); [ -n "$r" ] || exit 0
  # The last GATE line in the reviewer's final message decides (agents end with `GATE: PASS` / `GATE: FAIL — ...`).
  verdict=$(printf '%s' "$input" | grep -oE 'GATE: (PASS|FAIL)' | tail -n 1 | sed 's/GATE: //')
  [ -n "$verdict" ] || verdict=NONE
  now=$(snapshot)
  mkdir -p "$state"
  if [ ! -f "$state/pending/$r" ]; then verdict=UNSEEN
  elif [ "$now" != "$(cat "$state/pending/$r")" ]; then verdict=STALE
  fi
  rm -f "$state/pending/$r"
  { printf 'VERDICT %s\n' "$verdict"; printf '%s\n' "$now"; } > "$state/$r"
  exit 0
  ;;
commit) ;;
*) exit 0 ;;
esac

# --- commit ---
cmd=$(field command)
# `git [-C dir | -c k=v | --opt[=v] | -x]... commit`, anywhere in the command line.
opts='(([[:space:]]+(-C|-c)[[:space:]]+[^[:space:]]+)|([[:space:]]+--[a-z-]+(=[^[:space:]]+)?)|([[:space:]]+-[a-zA-Z]))*'
# shellcheck disable=SC2016  # the backticks in these patterns are literal
lead='(^|[;&|(`[:space:]])git'
# shellcheck disable=SC2016
printf '%s' "$cmd" | grep -qE "${lead}${opts}"'[[:space:]]+commit([[:space:];&|)`]|$)' || exit 0

head=$(git rev-parse --verify -q HEAD) || head=none
# Enforced during a cas run: a review was recorded on this HEAD, or .agentic/task.md is open (Status not done).
active=
for f in "$state/code-reviewer" "$state/security-reviewer" "$state/ux-reviewer"; do
  [ -f "$f" ] && sed -n 2p "$f" | grep -qx "HEAD $head" && active=1
done
if [ -f .agentic/task.md ] && ! grep -qiE '^Status:[[:space:]]*done' .agentic/task.md; then active=1; fi
[ -n "$active" ] || exit 0

# This hook runs before the command, so whatever precedes `git commit` in the same command goes unchecked: allow only
# `cd`, `git add` and read-only git there. (What follows the commit, such as its message or `| tail`, can't change it.)
# shellcheck disable=SC2016
before=$(printf '%s' "$cmd" | sed -E "s/${lead}${opts}"'[[:space:]]+commit([[:space:];&|)`].*)?$/\1/')
# shellcheck disable=SC2016
pre=$(printf '%s\n' "$before" | awk '{ gsub(/\\n/, "\n"); gsub(/&&|\|\||[;|]/, "\n"); gsub(/2>&1|2?>[ \t]*\/dev\/null/, ""); print }' |
  sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | while IFS= read -r seg; do
    [ -n "$seg" ] || continue
    if printf '%s' "$seg" | grep -qE '^cd[[:space:]]+[^[:space:]$`]+$'; then :
    elif printf '%s' "$seg" | grep -qE "^git${opts}"'[[:space:]]+add([[:space:]][^$`>]*)?$'; then echo ADD
    elif printf '%s' "$seg" | grep -qE "^git${opts}"'[[:space:]]+(status|diff|log|show|rev-parse)([[:space:]][^$`>]*)?$'; then :
    else printf 'BAD %s\n' "$seg"; fi
  done)
bad=$(printf '%s\n' "$pre" | sed -n 's/^BAD //p' | head -n 1)
if [ -n "$bad" ]; then
  cat >&2 <<EOF
cas review guard: run \`git commit\` as its own Bash command, after any edits. The guard checks the tree before a
command runs, so \`$bad\` ahead of the commit in the same command would go unchecked. (\`cd\`, \`git add\` and
read-only git commands may precede it.)
EOF
  exit 2
fi

now=$(snapshot)
base=$head; [ "$head" = none ] && base=$(git hash-object -t tree /dev/null)
# What a commit can carry: every path whose index or working-tree content differs from HEAD.
paths=$($G diff --name-only "$base" -- | grep -v '^\.agentic/')
# A `git add` ahead of the commit can stage untracked files too, so those must match the review as well.
if printf '%s\n' "$pre" | grep -qx ADD; then
  paths=$(printf '%s\n%s\n' "$paths" "$($G ls-files --others --exclude-standard | grep -v '^\.agentic/')")
fi
required="code-reviewer security-reviewer"
[ -f "$state/ux-reviewer" ] && sed -n 2p "$state/ux-reviewer" | grep -qx "HEAD $head" && required="$required ux-reviewer"

problems=
for r in $required; do
  f="$state/$r"
  if [ ! -f "$f" ]; then problems="$problems
- cas:$r: no review recorded for this change"; continue; fi
  v=$(sed -n 1p "$f" | sed 's/^VERDICT //')
  if ! sed -n 2p "$f" | grep -qx "HEAD $head"; then problems="$problems
- cas:$r: its last review was on another commit"; continue; fi
  case "$v" in
    PASS) ;;
    STALE) problems="$problems
- cas:$r: files changed while it was reviewing, so its verdict doesn't cover them"; continue ;;
    FAIL) problems="$problems
- cas:$r: its latest verdict is GATE: FAIL"; continue ;;
    *) problems="$problems
- cas:$r: its latest review has no GATE verdict"; continue ;;
  esac
  changed=$(printf '%s\n' "$paths" | while IFS= read -r p; do
    [ -n "$p" ] || continue
    want=$(sed '1,2d' "$f" | awk -F '\t' -v p="$p" '$1 == p { print $2; exit }')
    if [ -f "$p" ] || [ -L "$p" ]; then wt=$(git hash-object -- "$p"); else wt=deleted; fi
    idx=$($G ls-files -s -- "$p" | awk '{ print $2; exit }'); [ -n "$idx" ] || idx=deleted
    old=$(git rev-parse -q --verify "$base:$p" 2>/dev/null) || old=deleted
    # The index and the working tree may each hold the reviewed content or HEAD's (an unchanged side commits nothing).
    if { [ "$idx" != "$want" ] && [ "$idx" != "$old" ]; } || { [ "$wt" != "$want" ] && [ "$wt" != "$old" ]; }; then
      printf '%s ' "$p"
    fi
  done)
  [ -n "$changed" ] && problems="$problems
- cas:$r: changed since its passing review: $changed"
done

[ -z "$problems" ] && exit 0
cat >&2 <<EOF
cas review guard: this commit is blocked, because it would include code no passing review has seen.$problems
Re-run /cas:verify, then re-dispatch cas:code-reviewer and cas:security-reviewer (and cas:ux-reviewer for UI) on the
current diff, and commit only after each reports GATE: PASS on exactly this content (MANUAL.md -> Committing &
publishing). Unstaged edits to tracked files count too: revert them or include them in the review.
EOF
exit 2
