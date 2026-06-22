---
disable-model-invocation: true
description: 自分の作業差分（未コミット or --staged）を3つの観点別レビュアーで並列レビューし、verifierで事実確認・採用判定したうえで「自分が直す指摘リスト」を出す。コミット前の自己レビュー用。
argument-hint: "[--staged]"
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git rev-parse:*), Read, Grep, Glob, Agent
---

あなたはコードレビューの**オーケストレーター**。自分の作業差分を、観点別レビュアー3体（並列）→ verifier の順に通し、最後に「直すべき指摘リスト」へ整形する。実装の修正はしない（指摘のみ。修正はユーザーが判断する）。

## 手順

### 1. 差分を取得しスコープを決める
- 引数 `$ARGUMENTS` に `--staged` が含まれれば `git diff --staged`、無ければ `git diff`（working tree）を実行。
- 変更ファイル一覧を把握する。review-rubric のスキップ規則（生成物・lock・migration・`.env*`）に該当するファイルは除外する。
- 対象の実コードが無ければ「レビュー対象の差分なし」と伝えて終了。

### 2. 3つの Claude finder ＋ Codex holistic を**並列**で走らせる
**(a) 3つの finder を1メッセージで並列 spawn** — `Agent` ツールで `correctness-reviewer` / `design-reviewer` / `convention-reviewer` を**同時に**起動する（直列にしない＝待ち時間を最小化）。各エージェントへのプロンプトには次を渡す:
- レビュー対象の **diff 全文**（全員が同一のコードを見るように、各自で git diff を打ち直させず、ここで取得した diff を渡す）
- レビュー対象ファイルのパス一覧
- 作業ディレクトリ（リポジトリのルート。各自が `CLAUDE.md` や関連ファイルを Read/Grep できるように）
- 「review-rubric の基準と出力フォーマットに従い、担当観点だけを返すこと」

**(b) Codex holistic レビューを Bash で起動** — 別AI(Codex)に「コードベース全体を俯瞰し、ファイル横断の相互作用・データフローの不整合」を見させる。3 finder が観点ごとに縦に見るのに対し、Codex は横断結合バグ（呼び出し側↔定義側、コンポーネント間 state 同期など）を拾う担当。Claude 予算を食わない別アカウント実行。
```bash
codex review --uncommitted "差分(未コミット変更)を中心に、ファイル横断の相互作用・データフローの不整合、コンポーネント間のstate同期、エントリ→lib呼び出しの既定値齟齬に注目してレビュー。file:line/重要度/理由/修正案で。read-only。" < /dev/null
```
- **`< /dev/null` 必須**（stdin が開いていると Codex は追加入力待ちでハングする）。
- Codex が未導入/未認証で失敗した場合は、その旨を一言メモして 3 finder のみで続行する（フォールバック）。
- Codex の出力は自由形式。次の verifier がフォーマットを正規化するのでそのまま渡してよい。

### 3. 指摘をマージする
3 finder ＋ Codex の戻り値（計4ソース）を集約し、同一 `file:line`・実質同義の指摘を1ブロックに統合する（観点・出典タグは併記）。Codex の指摘は**未検証**なので、必ず次の verifier に通す（Codex 単体の誤検出を素通しさせない）。

### 4. verifier を spawn する
`Agent` ツールで `review-verifier` を起動し、マージ済み指摘リスト・diff・リポジトリパスを渡す。verifier は各指摘を実装で裏取りし、採用/却下・確定 severity・Pre-existing 判定を返す。

### 5. 「直すリスト」として出力する
verifier の**採用指摘のみ**を severity 順（🔴→🟡→🟢）で提示する。各指摘は `file:line`・理由・最小修正案つき。末尾に「却下された指摘の件数と主な理由」「サマリ（🔴a/🟡b/🟢c、Pre-existing d）」を簡潔に添える。

提案のみで自動修正はしない。🔴 が1件でもあればコミット前に対応を促す一言を添える。
