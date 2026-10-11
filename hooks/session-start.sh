#!/bin/sh
# SessionStart hook: point the session at the cas operating manual.
# Claude Code only puts the first ~2 KB of a hook's output into context, and
# MANUAL.md is far larger, so the hook prints a short directive to Read it
# instead of the manual itself. Keep this output well under 2 KB.
# A broken install still prints a notice to stdout (exit 0), so the model
# tells the user instead of silently working without the manual.
manual="${CLAUDE_PLUGIN_ROOT:-}/MANUAL.md"
if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ] || [ ! -r "$manual" ]; then
  printf '%s\n' "cas plugin: the operating manual could not be found (looked for \`$manual\`). Tell the user the cas plugin install is broken and should be reinstalled; do not start cas work without the manual."
  exit 0
fi
cat <<EOF
# cas plugin active — read the operating manual first

You operate under the Claude Agentic Stack (the \`cas\` plugin). Its operating manual is NOT in your context yet.

BEFORE any other action this session — and again after every compaction or /clear — use the Read tool to read this file in full (every line, no offset/limit):

\`$manual\`

It has the authority of CLAUDE.md and governs every task: the operating loop, the mandatory code + security review gate, the Definition of Done, the autonomy policy, and when to stop and ask. The repository's own CLAUDE.md wins on project specifics (build/test commands, sandbox alias). If the file cannot be read, say so and stop rather than working without it.
EOF
