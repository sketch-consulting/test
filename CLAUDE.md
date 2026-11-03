# CLAUDE.md — 自律型AI開発チーム 共通ルール

このファイルは **Claude Code** のすべてのセッション・サブエージェントが最初に読む共通ルールです。
Codex など他の AI ツールはこのファイルもフックも読みません（`docs/other-agents.md` を参照）。
チーム設計の全体像は `docs/team-blueprint.md`、安全装置で防げる範囲は `docs/safety-boundaries.md` を参照してください。

## プロジェクト情報（導入時に必ず埋める）

- 技術構成: TODO（例: TypeScript / Node 20 / PostgreSQL）
- 品質ゲート: `scripts/check.sh`。必須の lint・型検査・テストは `scripts/check.config` に書く。
  - 終了コード 0 = 成功、1 = 失敗、2 = 未設定。0 以外の変更は完了扱いにしない。
  - 現在は未設定のため、常に 2 を返す。
- 既定ブランチ: `main`

## 最優先の原則

1. 速度より正確さと安全性を優先する。
2. 分からないことは推測で埋めない。存在を確認していない関数・パッケージ・API・ファイルを使わない。確認できなければ「不明」と書いて統括役に返す。
3. 差分は最小限にする。依頼範囲外のリファクタ・整形・改名はしない。

## 禁止事項（人の明示的な承認なしに実行しない）

- 破壊的コマンド: `rm -rf`、`git push --force` / `-f`、`git reset --hard`、`git clean -f`、`DROP` / `TRUNCATE` 文
- `main` への直接 push、PR のマージ、GitHub の権限・保護設定の変更
- DB スキーマ移行、課金が発生する外部 API の呼び出し、依存パッケージの追加
- `scripts/check.config` の変更（必須チェックを外す・NA にすることを含む）
- 他エージェントの worktree・ブランチへの書き込み
- テストの削除・skip・無効化、アサーションを弱めて通すこと
- `.env`、秘密情報、API キー、環境変数の値をログ・コミット・PR 本文に出すこと

※ 一部は `.claude/settings.json` とフックで機械的にも止めますが、完全ではありません。
  機械的に止まらなくても、ここに書いた約束は守ること。

## 作業環境（git worktree）

- 1 タスク × 1 役割 = 1 worktree。作成は `scripts/new-worktree.sh <task-id> <role>`。
  - implementer: ブランチ `agent/<task-id>/implementer` を作る（ここに実装をコミットする）
  - verifier: 作業用ブランチを作らず、検証対象のコミットを detached で取り出すための worktree
  - reviewer: worktree は不要（統括役の作業ツリーから git の読み取りだけで見る）
  - 場所: `../wt/<task-id>-<role>`
- worktree 間で共有されるのは **コミットだけ**。未コミットのファイルは他の役から見えない。

## 引き継ぎ記録（統括役だけが書く）

- 各役は結果を **返答として** 統括役に返す。ファイルには書かない（reviewer / verifier は書き込み禁止のため）。
- 統括役が返答を集約し、`docs/handoff/<task-id>.md`（書式は `docs/handoff/TEMPLATE.md`）に記録する。
- 記録は最後に PR ブランチへ統括役がコミットし、PR 本文にも要約を載せる。
  人は PR だけを見れば、根拠と残る判断をまとめて確認できるようにする。

## コミット規約

- Conventional Commits: `fix: ...` / `feat: ...` / `test: ...` / `refactor: ...` / `docs: ...` / `chore: ...`
- 1 コミット = 1 つの意図。本文に「なぜ」を書く（日本語で可）。
- 件名の末尾にタスク ID を付ける: `fix: 請求額の端数処理を修正 (T-123)`

## 統括役（メインセッション）の進め方

1. **受付**: 受け入れ条件（確かめ方つきで 3〜5 行）と触ってよい範囲を決め、引き継ぎ記録を作る。
   受け入れ条件が曖昧な新機能・リファクタ・移行は、先に `grilling` スキルで人に質問し、合意してから書く。
2. **準備**: `scripts/new-worktree.sh <id> implementer` と `scripts/new-worktree.sh <id> verifier`。
3. **実装**: `implementer` に依頼する。BLOCKED が返ったら、その時点で止めて人に判断を仰ぐ。
4. **レビュー**: `reviewer` に、ブランチ名と implementer が返した HEAD のハッシュを渡す。
5. **検証**: `verifier` に、検証用 worktree・同じハッシュ・reviewer の TEST_GAPS を渡す。
6. **変更なしの確認**: reviewer / verifier の終了後に次を確認する。変化があれば、その結果は採用せずに人へ報告する。
   - `git -C <verifier の worktree> status --porcelain` が空であること
   - 統括役の作業ツリーの `git status --porcelain` が、依頼前と同じであること
   - 実装ブランチの HEAD が、依頼時のハッシュから変わっていないこと
7. **差し戻し**: reviewer が CHANGES_REQUESTED、または verifier が FAIL / FLAKY なら、指摘を添えて implementer に戻す。
   差し戻しは **最大 2 回**（実装は合計 3 回まで）。3 回目の実装後もどちらかが PASS でなければ止めて、人に判断を仰ぐ。
   BLOCK / BLOCKED / 品質チェックの未設定（終了コード 2）は、回数に関係なくその場で止める。
8. **集約と PR**: 引き継ぎ記録を仕上げてコミットし、push して **ドラフト PR** を作る。
   PR 本文は「結論 / 根拠（実行コマンドと結果）/ 未確認事項 / 人の判断が必要なこと」で構成する。マージは人が行う。
