#!/usr/bin/env bash
# PreToolUse フック（Bash ツールのみ）: 危険な操作の「よくある書き方」を実行前に止める。
#
# これは補助的な安全網であり、完全な防御ではない。
#  - コマンド文字列を正規表現で見るだけなので、スクリプトファイルの中身、変数・エイリアス経由、
#    python/node など別言語からの操作、Bash 以外のツール（Write、MCP）は止められない。
#  - 文字列として含むだけでも止まる（例: コミットメッセージに "rm -rf" と書く）。
# 防げる範囲と防げない範囲は docs/safety-boundaries.md と tests/guard-bash.test.sh を参照。
#
# 標準入力にツール呼び出しの JSON が来る。exit 2 でブロックし、stderr が Claude に返る。
set -u
input="$(cat)"

block() {
  echo "BLOCKED by guard-bash.sh: $1 — 人の承認が必要です。統括役に返してください。" >&2
  exit 2
}

lc="$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')"
match() { printf '%s' "$lc" | grep -Eq "$1"; }

# 削除
match 'rm[[:space:]]+(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r|--recursive|-r[[:space:]]+-f)' && block "再帰削除 (rm -rf)"
match 'find[[:space:]][^"]*-delete' && block "find -delete"
match '(shutil\.rmtree|rimraf|fs\.rm(sync)?\([^)]*recursive)' && block "再帰削除（スクリプト経由）"

# git の破壊的操作・main への反映
match 'git[[:space:]]+push[^"]*(--force|[[:space:]]-f([[:space:]]|"|$)|--mirror|--delete|[[:space:]]:[a-z])' && block "強制 push / リモートブランチ削除"
match 'git[[:space:]]+push[^"]*[[:space:]](origin[[:space:]]+)?(main|master)([[:space:]]|"|$)' && block "main への直接 push"
match 'git[[:space:]]+push[^"]*:(refs/heads/)?(main|master)([[:space:]]|"|$)' && block "main への直接 push (HEAD:main)"
match 'git[[:space:]]+reset[[:space:]]+--hard' && block "git reset --hard"
match 'git[[:space:]]+clean[[:space:]]+-[a-z]*f' && block "git clean -f"
match 'git[[:space:]]+worktree[[:space:]]+remove[^"]*--force' && block "worktree の強制削除"
match 'git[[:space:]]+branch[[:space:]]+-d[[:space:]]+-f|git[[:space:]]+branch[[:space:]]+-ff?[[:space:]]+(main|master)' && block "ブランチの強制操作"
match 'gh[[:space:]]+pr[[:space:]]+merge' && block "PR のマージ"
match 'gh[[:space:]]+api[^"]*(protection|rulesets|/merge)' && block "GitHub の保護設定・マージ API"

# データベース
match '(drop[[:space:]]+(table|database|schema)|truncate[[:space:]]+table)' && block "テーブル・DB の削除"

# 秘密情報
match '(^|[[:space:];&|"])(printenv|env)([[:space:]]*($|[;&|"]))' && block "環境変数の一覧出力"
match '(^|[[:space:];&|"/])\.env(\.[a-z0-9_-]+)?([[:space:];&|"]|$)' && ! match '\.env\.(example|sample|template)' && block ".env への参照"

exit 0
