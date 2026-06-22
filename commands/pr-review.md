---
disable-model-invocation: true
description: 人からのレビュー依頼PRを調査し、3つの観点別レビュアー並列→verifier検証を経て「①タスク解説 ②返信コメント案(file:line+本文) ③レビュー判定案」を出す。Copilot/Devin等のAIレビューは除外。既定は提案のみ（自動投稿しない）。
argument-hint: "[<PR URL or number>｜空で現在ブランチのPRを自動検出]"
allowed-tools: Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr list:*), Bash(gh search:*), Bash(gh api:*), Bash(git rev-parse:*), Bash(codex:*), Read, Grep, Glob, Agent
---

あなたはコードレビューの**オーケストレーター**。人からのレビュー依頼PRを調査し、レビュアー3体（並列）→ verifier を通して、ユーザーが「読んで判断し、自分で返信する」ための材料を作る。GitHubへの自動投稿はしない（既定は提案のみ）。

## 手順

### 1. 対象PRを特定する
- `$ARGUMENTS` にPR URL/番号があればそれを対象にする。
- 無ければ現在のブランチに紐づくPRを `gh pr view --json url,number` 等で自動検出する。見つからなければユーザーにPRの指定を促して終了。

### 2. PRの文脈を集める
- `gh pr view <pr> --json title,body,author,url,headRefOid,headRepository` でタイトル・本文・author・head SHA を取得。
- 本文にリンクされた Issue があれば `gh issue view` で要約を取得（このPRが解こうとしている課題＝タスクの背景）。
- **AIレビューは除外**: Copilot / Devin など bot が付けたレビューコメントは収集・考慮しない。人間（あなた）が独立に判断するための材料に絞る。開発者が既にbot指摘へ対応済みである前提。
- `gh pr diff <pr>` で差分（パッチ）を取得。review-rubric のスキップ規則該当ファイルは除外。

> 注: PRは別ブランチ/別リポのことが多く、ローカル作業ツリーがPRのhead状態とは限らない。**レビューは取得した diff（パッチ＝周辺コンテキスト行を含む）を主たる根拠**にする。定義元や利用箇所の確認が要る場合は `gh search code` / `gh api .../contents/{path}?ref=<headSHA>` を best-effort で使う。convention 観点のため、対象リポの `CLAUDE.md`/`REVIEW.md` を `gh api` で best-effort 取得し convention-reviewer に渡す。

### 3. 3つの Claude finder ＋ Codex holistic を**並列**で走らせる
**(a) 3つの finder を1メッセージで並列 spawn** — `Agent` ツールで `correctness-reviewer` / `design-reviewer` / `convention-reviewer` を同時起動。各プロンプトに渡す:
- PRの **diff（パッチ）全文**
- タスク背景（PRタイトル・本文・リンクIssueの要約）
- 変更ファイル一覧、head SHA、対象リポ（owner/repo）
- 取得できていれば対象リポの `CLAUDE.md`/`REVIEW.md`（特に convention-reviewer へ）
- 「diff を主たる根拠にレビューし、review-rubric の基準と出力フォーマットで担当観点だけを返すこと。ローカルファイルはPR head とずれている可能性があるので、必要な追加文脈は gh で取得すること」

**(b) Codex holistic レビューを Bash で起動** — 別AI(Codex)に PR の変更を全体俯瞰させ、ファイル横断の結合バグ（呼び出し側↔定義側、コンポーネント間 state 同期、エントリの既定値齟齬）を拾わせる。3 finder の縦割りでは落ちやすい領域の担当。別アカウント実行で Claude 予算を食わない。
- PR ブランチがローカルで参照可能なら（同一リポで `gh pr checkout` 済み or worktree）：
  ```bash
  codex review --base <PRのbaseブランチ> "ファイル横断の相互作用・データフロー・コンポーネント間state同期に注目。file:line/重要度/理由/修正案で。read-only。" < /dev/null
  ```
- ブランチをローカルに用意できない場合は、取得済みの diff を holistic レビューさせる：
  ```bash
  codex exec -s read-only "次のPR差分を全体文脈でレビュー。ファイル横断の不整合を重視。<diffを貼付>" < /dev/null
  ```
- **`< /dev/null` 必須**（stdin 開放だとハング）。Codex 未導入/失敗時はメモして 3 finder のみで続行（フォールバック）。Codex 出力は自由形式で可（verifier が正規化）。

### 4. マージ → verifier
3 finder ＋ Codex の指摘（計4ソース）を `file:line` でマージ（同義は統合・観点/出典併記）し、`Agent` で `review-verifier` を起動。マージ済み指摘・diff・PR情報（head SHA・リポ）を渡す。verifier は diff と gh での裏取りに基づき採用/却下・確定 severity を返す。**Codex の指摘は未検証なので必ず verifier に通す**（別AIの誤検出を素通ししない）。

### 5. 3部構成で出力する
verifier の採用指摘をもとに、次を提示する:

**① タスク解説** — このPRが何を・なぜ変更するのか（背景Issue、変更の要点、影響範囲）を数行で。ユーザーがPRの全体像を即つかめるように。

**② 返信コメント案** — 採用指摘を「GitHubにそのまま貼れる粒度」で。各コメントは:
```
- 該当: path/to/file.ts:123  （severity: 🔴|🟡|🟢、観点）
  コメント: <レビュイーに向けた文面。問題→なぜ→提案を簡潔に。攻撃的でなく具体的に>
```

**③ レビュー判定案** — `approve` / `request changes` / `comment` のいずれかと、その根拠（🔴が残る→request changes 等）。最終判断はユーザーが行う前提で「案」として示す。

末尾に却下件数とサマリ（🔴a/🟡b/🟢c、Pre-existing d）を添える。**`gh pr review` での投稿は行わない**（ユーザーが内容を吟味してから自分で返信する）。
