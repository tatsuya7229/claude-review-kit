#!/usr/bin/env bash
#
# check-pr-reviews.sh
# 自分宛のレビュー依頼 PR を検出し、未処理のものを Claude (/pr-review) にかけて
# 結果を ~/.pr-reviews/ に保存し、macOS 通知する。冪等（同一 head SHA は再処理しない）。
#
# 想定起動: launchd (StartInterval) または cron。詳細は同ディレクトリの README/plist 参照。
# サブスク認証の claude / gh を使う。API キーは不要。
#
set -euo pipefail

# --- launchd/cron は最小 PATH なので、よく使う bin を前置 ---
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

OUT="$HOME/.pr-reviews"
STATE="$OUT/processed.txt"
LOG="$OUT/check-pr-reviews.log"
mkdir -p "$OUT"
touch "$STATE"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$LOG"; }

# --- 業務時間ガード（平日 9-18 時のみ）。PR_REVIEW_ALWAYS=1 で無効化 ---
if [[ "${PR_REVIEW_ALWAYS:-0}" != "1" ]]; then
  dow=$(date +%u)   # 1=Mon .. 7=Sun
  hour=$(date +%H)
  if (( dow > 5 )) || (( 10#$hour < 9 )) || (( 10#$hour >= 18 )); then
    exit 0
  fi
fi

command -v gh >/dev/null 2>&1     || { log "gh not found in PATH"; exit 1; }
command -v claude >/dev/null 2>&1 || { log "claude not found in PATH"; exit 1; }

notify() {
  # $1=title $2=message  （Aqua セッション=launchd LaunchAgent / 手動実行で有効）
  osascript -e "display notification \"${2//\"/\\\"}\" with title \"${1//\"/\\\"}\"" >/dev/null 2>&1 || true
}

log "=== run start ==="

# --- 自分がレビュアーに指定された open PR を全リポ横断で取得（draft は除外） ---
prs_json=$(gh search prs --review-requested=@me --state open --limit 30 \
            --json url,number,repository,isDraft 2>>"$LOG" || echo '[]')

count=$(echo "$prs_json" | jq 'length')
log "found $count review-requested PR(s)"
[[ "$count" -eq 0 ]] && { log "nothing to do"; exit 0; }

echo "$prs_json" | jq -c '.[] | select(.isDraft == false)' | while read -r pr; do
  url=$(echo "$pr"  | jq -r '.url')
  num=$(echo "$pr"  | jq -r '.number')
  repo=$(echo "$pr" | jq -r '.repository.nameWithOwner')

  # head SHA を取得（重複排除キー。新しい push で SHA が変われば再レビュー）
  sha=$(gh pr view "$url" --json headRefOid --jq '.headRefOid' 2>>"$LOG" || echo "")
  [[ -z "$sha" ]] && { log "skip (no sha): $url"; continue; }
  key="${repo}#${num}@${sha}"

  if grep -qxF "$key" "$STATE" 2>/dev/null; then
    continue   # 既にこの SHA をレビュー済み
  fi

  log "reviewing $key"
  short=${sha:0:7}
  safe_repo=${repo//\//-}
  outfile="$OUT/${safe_repo}-${num}-${short}.md"

  # /pr-review をヘッドレス実行（サブスク認証）。失敗時は state を更新せず次回再試行。
  if claude -p "/pr-review $url" >"$outfile" 2>>"$LOG"; then
    {
      echo
      echo "<!-- generated: $(date '+%Y-%m-%d %H:%M:%S')  $key -->"
    } >>"$outfile"
    echo "$key" >>"$STATE"
    log "saved $outfile"
    notify "PR Review 用意できた" "$repo #$num — $outfile"
  else
    log "FAILED claude for $key (will retry next run)"
    notify "PR Review 失敗" "$repo #$num（ログ参照）"
  fi
done

log "=== run end ==="
