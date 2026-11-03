# CLAUDE.md — 自律型AI開発チーム 共通ルール

このファイルはすべてのセッション・サブエージェントが最初に読む共通ルールです。
チーム設計の全体像は `docs/team-blueprint.md` を参照してください。

## プロジェクト情報（導入時に必ず埋める）

- 技術構成: TODO（例: TypeScript / Node 20 / PostgreSQL）
- 品質ゲート: `scripts/check.sh`（lint・型検査・テストをまとめて実行。これが通らない変更は完了扱いにしない）
- 既定ブランチ: `main`

## 最優先の原則

1. 速度より正確さと安全性を優先する。
2. 分からないことは推測で埋めない。存在を確認していない関数・パッケージ・API・ファイルを使わない。確認できなければ「不明」と書いて統括役に返す。
3. 差分は最小限にする。依頼範囲外のリファクタ・整形・改名はしない。

## 禁止事項（人の明示的な承認なしに実行しない）

- 破壊的コマンド: `rm -rf`、`git push --force` / `-f`、`git reset --hard`、`git clean -f`、`DROP` / `TRUNCATE` 文
- `main` への直接 push、PR のマージ
- DB スキーマ移行、課金が発生する外部 API の呼び出し、依存パッケージの追加
- 他エージェントの worktree・ブランチへの書き込み
- テストの削除・skip・無効化、アサーションを弱めて通すこと
- `.env`、秘密情報、API キー、環境変数の値をログ・コミット・PR 本文に出すこと

※ 上記の一部は `.claude/settings.json` と `.claude/hooks/guard-bash.sh` で機械的にも止めています。

## 作業環境（git worktree）

- 1 タスク × 1 役割 = 1 worktree = 1 ブランチ。
- 作成は必ず `scripts/new-worktree.sh <task-id> <role>` を使う。
  - ブランチ: `agent/<task-id>/<role>`
  - 場所: `../wt/<task-id>-<role>`
- 自分に割り当てられた worktree の外のファイルは編集しない。

## 引き継ぎ（共有メモリ）

- タスクごとに `docs/handoff/<task-id>.md` を 1 つ作り、各役割は自分の節だけに追記する。
- 書式は `docs/handoff/TEMPLATE.md` に従う。会話の記憶に頼らず、必要な情報はすべてここに書く。

## コミット規約

- Conventional Commits: `fix: ...` / `feat: ...` / `test: ...` / `refactor: ...` / `docs: ...` / `chore: ...`
- 1 コミット = 1 つの意図。本文に「なぜ」を書く（日本語で可）。
- 件名の末尾にタスク ID を付ける: `fix: 請求額の端数処理を修正 (T-123)`

## 統括役（メインセッション）の進め方

1. タスクを受けたら `docs/handoff/<task-id>.md` を作り、受け入れ条件を 3〜5 行で書く。
2. 実装は `implementer`、レビューは `reviewer`、検証は `verifier` サブエージェントに依頼する。依頼文には task-id、worktree のパス、受け入れ条件、触ってよいファイルの範囲を必ず入れる。
3. `reviewer` と `verifier` の両方が PASS になるまで、差し戻しは最大 2 回まで。3 回目が必要なら止めて人に判断を仰ぐ。
4. PR を作るのは統括役だけ。マージは人が行う。
