# claude-review-kit（自分用メモ）

社用PCに自分のレビュー基盤を移すための一式。fan-out → verify 構成。

## 中身
- `skills/review-rubric/SKILL.md` … 共通基準（重要度/スキップ/出力フォーマット）。各 reviewer が `skills:` で preload。**`disable-model-invocation` は付けない**（付けると preload が壊れる）
- `agents/correctness|design|convention-reviewer.md` … 観点別 reviewer（並列・read-only）
- `agents/review-verifier.md` … 指摘を実装で裏取りして採否確定
- `commands/pr-review.md` … 他人のPR用。出力＝解説＋返信コメント案＋判定案
- `commands/self-review.md` … 自分の差分用。出力＝直すリスト
- コマンドは `disable-model-invocation: true`＝`/pr-review` `/self-review` で**明示起動した時だけ**動く（重い4並列が勝手に走らないように）

## 入れ方
```bash
bash install.sh                                   # mac/linux/WSL/GitBash
powershell -ExecutionPolicy Bypass -File install.ps1   # Windows
```
→ `~/.claude`(Win: `%USERPROFILE%\.claude`) にコピーするだけ。Claude Code 再起動で有効化。

## 前提
- 使う環境のアカウントで認証（社用PCは社用アカウント）
- `git` / `gh` 必須。Windowsネイティブは Bash ツール(Git Bash/WSL)が要る
- Codex は任意。`codex` CLI があれば 4ソース目として横断レビューに参加、無ければ自動で reviewer 3体のみにフォールバック
