# claude-review-kit

Claude Code 用のコードレビュー基盤（fan-out → verify パターン）。
**共通エンジン（rubric ＋ reviewer 3体 ＋ verifier）を、PR用とセルフ用の2つの入口で使い分ける**構成。

## 構成

```
共通エンジン（PR用もセルフ用も同一）
  skills/review-rubric/SKILL.md        採点・報告の共通基準（重要度🔴🟡🟢/スキップ規則/出力フォーマット/根拠主義）
        ↓ 各 reviewer が skills フィールドで preload
  agents/correctness-reviewer.md       動作の正しさ・バグ・型・テスト・性能 (opus)
  agents/design-reviewer.md            責務分離・拡張性・運用性 ＋ セキュリティ (opus)
  agents/convention-reviewer.md        可読性・命名・規約準拠 (sonnet)
  ＋ Codex holistic（任意・外部AI・ファイル横断バグ。未導入なら自動フォールバック）
        ↓ file:line でマージ
  agents/review-verifier.md            実装で裏取りし採用/却下・severity確定 (opus)

入口（明示起動のみ＝ disable-model-invocation: true）
  commands/pr-review.md    他人のPR用   → ①タスク解説 ②返信コメント案 ③判定案（投稿はしない）
  commands/self-review.md  自分の差分用 → 「自分が直す指摘リスト」（提案のみ）
```

入口を**明示起動のみ**にしているのは、1回で reviewer 3〜4体＋verifier を spawn する**重い処理**で、Claude が自動判断で勝手に走るとトークンが無駄になるため（`disable-model-invocation: true`）。`/pr-review` `/self-review` と打った時だけ動く。

## インストール

```bash
git clone <このリポのURL>
cd claude-review-kit

# macOS / Linux / WSL / Git Bash
bash install.sh

# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -File install.ps1
```
→ `~/.claude`（Windows は `%USERPROFILE%\.claude`）に展開。**Claude Code を再起動**して有効化。`/self-review` `/pr-review` で確認。

## 前提・注意

- **認証は使う環境のアカウントで**。社用PCでは社用の Claude / Codex / `gh` アカウントを使うこと（このキットにアカウント紐付けは無く、どの環境でも動く）。
- **Codex は任意**。`commands/*` は `codex` CLI を呼ぶが、未導入/未認証なら自動で「Claude reviewer 3体のみ」にフォールバックする。
- **クロスプラットフォーム**：中身は Markdown のみなので Windows / macOS / Linux いずれの Claude Code でも動く。ただし reviewer/コマンドは `Bash` ツール（git / gh）を使うため、**git と gh が入っていること**、Windows ネイティブでは Bash ツールが使える環境（Git Bash / WSL）が必要。
- **秘密情報なし**。中身は汎用のレビュー方法論のみ。
