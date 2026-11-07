#!/bin/sh
# UserPromptSubmit hook: if Neovim queued review comments (lua/review.lua),
# attach them to this prompt as context and consume the queue.
# Plain stdout from UserPromptSubmit is added to Claude's context.
cat >/dev/null
q="$HOME/.local/state/nvim-review/pending.md"
[ -s "$q" ] || exit 0
tmp="$q.$$"
mv "$q" "$tmp" 2>/dev/null || exit 0   # atomic claim; another session may win
echo "The user left these line-anchored review comments in Neovim (path:line or path:start,end; paths relative to the repo root). Treat them as part of their message:"
echo
cat "$tmp"
rm -f "$tmp"
