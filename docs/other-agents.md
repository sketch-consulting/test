# Claude Code 以外の AI（Codex、dot など）との関係

この設定は **Claude Code 専用** です。他の AI ツールにリポジトリを渡しても、
CLAUDE.md・フック・権限ルール・サブエージェントは自動では働きません。

## そのまま使えるもの（ツールに依存しない）
| もの | 理由 |
|---|---|
| `scripts/check.sh` と `scripts/check.config` | ただのシェルスクリプト。どのツールからでも実行でき、終了コードの意味も同じ |
| `scripts/new-worktree.sh` | git の機能だけを使う |
| `docs/handoff/TEMPLATE.md` | 書式なので、誰が書いても使える |
| 役割分担・差し戻し上限・PR で人が判断する、という運用 | 考え方として移せる |
| GitHub 側の保護（`docs/safety-boundaries.md` の 4 章） | GitHub が強制するので、ツールに関係なく効く。**複数の AI を使うなら最優先** |

## Codex で別途設定が必要なもの
| Claude Code | Codex で必要なこと |
|---|---|
| `CLAUDE.md` | Codex はリポジトリの `AGENTS.md` を読む。ルール部分を `AGENTS.md` に写す（2 つを同期させる手間が出る） |
| `.claude/settings.json` の権限ルール | 読まれない。Codex 側の承認モード・サンドボックス設定で代わりを作る |
| `.claude/hooks/guard-bash.sh` | 読まれない。同じ仕組みはないので、Codex の承認設定と GitHub 側の保護で補う |
| `.claude/agents/*.md`（サブエージェント） | 読まれない。役ごとに別のセッションを立てて、手で分担する |
| `.claude/skills/` | Claude Code の場所にあるので読まれない。Codex で使う場合は、Codex 側のやり方に合わせて置き直す |

## dot などの対話型 AI
リポジトリを直接操作しない AI（レビューや指示文の作成に使う AI）には、
`docs/team-blueprint.md` とこのファイルを渡せば、仕組みと限界を正しく伝えられます。
「読み取り専用」「危険操作を防止」と書かれている箇所は、`docs/safety-boundaries.md` の範囲の意味です。
