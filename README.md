# claude-review-kit

Claude Code 用のコードレビュー基盤（fan-out → verify パターン）。
**共通エンジン（rubric ＋ reviewer 3体 ＋ verifier）を、PR用とセルフ用の2つの入口で使い分ける**構成。

## 構成

```
共通エンジン（PR用もセルフ用も同一）
  skills/review-rubric/SKILL.md        採点・報告の共通基準（重要度🔴🟡🟢/スキップ規則/出力フォーマット/根拠主義）
        ↓ 各 reviewer が skills: で preload
  agents/correctness-reviewer.md       動作の正しさ・バグ・型・テスト・性能 (opus)
  agents/design-reviewer.md            責務分離・拡張性・運用性 ＋ セキュリティ (opus)
  agents/convention-reviewer.md        可読性・命名・規約準拠 (sonnet)
  ＋ Codex holistic（任意・外部AI・ファイル横断バグ。未導入なら自動フォールバック）
        ↓ file:line でマージ
  agents/review-verifier.md            実装で裏取りし採用/却下・severity確定 (opus)

入口（オーケストレーター）
  commands/pr-review.md    他人のPR用   → ①タスク解説 ②返信コメント案 ③判定案（投稿はしない）
  commands/self-review.md  自分の差分用 → 「自分が直す指摘リスト」（提案のみ）
  commands/diff-review.md  （任意）直近 diff 起点のレビュー

自動化（任意）
  bin/check-pr-reviews.sh  レビュー依頼PRを検出→/pr-review をheadless実行→保存＋通知（業務時間ガード入り）
```

## インストール

```bash
git clone <このリポのURL>
cd claude-review-kit
bash install.sh
```
→ `~/.claude` と `~/bin` に展開。**Claude Code を再起動**して有効化。`/self-review` `/pr-review` で確認。

## 前提・注意

- **認証は使う環境のアカウントで**。社用PCでは社用の Claude / Codex / `gh` アカウントを使うこと（このキットにアカウント紐付けは無く、どの環境でも動く）。
- **Codex は任意**。`commands/*` は `codex` CLI を呼ぶが、未導入/未認証なら自動で「Claude reviewer 3体のみ」にフォールバックする。
- **秘密情報なし**。中身は汎用のレビュー方法論のみ（コミット前に必ず再確認すること）。
- 自動化スクリプトは macOS（launchd / osascript）前提。`gh auth login` 済みが必要。cron/launchd 登録は手動。
