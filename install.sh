#!/usr/bin/env bash
#
# install.sh — このキットを ~/.claude に展開する（macOS / Linux / WSL / Git Bash）。
# 使い方: clone したディレクトリで `bash install.sh`
#
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$HOME/.claude/skills/review-rubric" "$HOME/.claude/agents" "$HOME/.claude/commands"

cp "$SRC/skills/review-rubric/SKILL.md" "$HOME/.claude/skills/review-rubric/"
cp "$SRC"/agents/*.md   "$HOME/.claude/agents/"
cp "$SRC"/commands/*.md "$HOME/.claude/commands/"

echo "✅ Installed to ~/.claude"
echo "   Claude Code を再起動すると agents / skills / commands が有効になります。"
echo "   確認: /self-review, /pr-review"
