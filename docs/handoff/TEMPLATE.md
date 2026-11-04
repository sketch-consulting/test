# <task-id>: <タイトル>

> この記録は統括役だけが書く。各役の返答をそのまま貼るのではなく、根拠（実行コマンドと結果）を残して要約する。

## 結論
- 状態: 完了（PR 待ち） / 停止（人の判断待ち）
- 一言で:

## 受け入れ条件と確かめ方
| # | 条件 | 確かめ方 | 結果 |
|---|---|---|---|
| 1 | | | |

## 触ってよい範囲
-

## ブランチ
- 実装: `agent/<id>/implementer`（implementer だけが書く）
- 検証済みコミット: <hash>
- 統合: `task/<id>`（検証済みコミットから。統括役だけが書く。差分はこの記録だけ）

## 経過
| 回 | 役 | 対象コミット | 結果 | 要点 |
|---|---|---|---|---|
| 1 | implementer | | DONE / BLOCKED | |
| 1 | reviewer | | PASS / CHANGES_REQUESTED / BLOCK | |
| 1 | verifier | | PASS / FAIL / FLAKY / BLOCKED | |

差し戻し回数: 0 / 2

## 根拠（実際に実行したコマンドと結果）
```
```

## 変更なしの確認（reviewer / verifier の終了後）
- reviewer の worktree の `git status --porcelain` と HEAD（レビュー対象のハッシュと一致すること）:
- verifier の worktree の `git status --porcelain`:
- 統括役の作業ツリーの `git status --porcelain`:
- 実装ブランチの HEAD（依頼時 → 終了後）:

## 統合ブランチの確認
- `git diff --name-only <検証済み hash> task/<id>` の結果（`docs/handoff/<id>.md` だけであること）:

## 未確認事項
-

## 人の判断が必要なこと
-
