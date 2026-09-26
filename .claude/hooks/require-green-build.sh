#!/bin/bash
# Claude Code hook: block `git push` and `gh pr create` unless `swift build`
# is free of errors and warnings (guardrails.md §3).
#
# Claude Code sends the Bash command as JSON on stdin.
# Exit 0 = allow the command. Exit 2 = block it; stderr is shown to Claude.

command=$(jq -r '.tool_input.command')

case "$command" in
  *"git push"* | *"gh pr create"*) ;;   # check these
  *) exit 0 ;;                          # allow everything else
esac

cd "$CLAUDE_PROJECT_DIR" || exit 0

# Treat warnings as errors, so a warning fails the build every time instead of
# being hidden by the incremental cache. Separate build folder keeps this from
# invalidating the normal .build/ cache.
if ! output=$(swift build --scratch-path .build/hook -Xswiftc -warnings-as-errors 2>&1); then
  echo "Blocked: swift build has errors or warnings. Fix these, then push again:" >&2
  echo "$output" | sed $'s/\e\\[[0-9;]*m//g' | grep -E '^/.*error:' | sort -u >&2
  exit 2
fi
