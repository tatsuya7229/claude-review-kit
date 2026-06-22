#!/usr/bin/env bash
#
# install.sh — このキットを ~/.claude（と ~/bin）に展開する。
# 使い方: clone したディレクトリで `bash install.sh`
#
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$HOME/.claude/skills/review-rubric" "$HOME/.claude/agents" "$HOME/.claude/commands" "$HOME/bin"

cp "$SRC/skills/review-rubric/SKILL.md" "$HOME/.claude/skills/review-rubric/"
cp "$SRC"/agents/*.md   "$HOME/.claude/agents/"
cp "$SRC"/commands/*.md "$HOME/.claude/commands/"

if [ -f "$SRC/bin/check-pr-reviews.sh" ]; then
  cp "$SRC/bin/check-pr-reviews.sh" "$HOME/bin/"
  chmod +x "$HOME/bin/check-pr-reviews.sh"
fi

echo "✅ Installed to ~/.claude (and ~/bin)."
echo "   Claude Code を再起動すると agents / skills / commands が有効になります。"
echo "   確認: /self-review, /pr-review"
