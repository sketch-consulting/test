#!/usr/bin/env bash
# PreToolUse フック: 破壊的・秘密漏洩につながる Bash コマンドを止める。
# 標準入力にツール呼び出しの JSON が来る。exit 2 でブロックし、stderr が Claude に返る。
# settings.json の deny と二重の防御（deny はパターンの書き方次第で抜けるため）。
set -u
input="$(cat)"

block() {
  echo "BLOCKED by guard-bash.sh: $1 — 人の承認が必要です。統括役に返してください。" >&2
  exit 2
}

# 判定は大文字小文字を区別しない
lc="$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')"

match() { printf '%s' "$lc" | grep -Eq "$1"; }

match 'rm[[:space:]]+(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r|--recursive|-r[[:space:]]+-f)' && block "再帰削除 (rm -rf)"
match 'git[[:space:]]+push[^"]*(--force|[[:space:]]-f([[:space:]]|"|$)|--mirror|--delete|[[:space:]]:[a-z])' && block "強制 push / リモートブランチ削除"
match 'git[[:space:]]+push[^"]*[[:space:]](origin[[:space:]]+)?(main|master)([[:space:]]|"|$)' && block "main への直接 push"
match 'git[[:space:]]+reset[[:space:]]+--hard' && block "git reset --hard"
match 'git[[:space:]]+clean[[:space:]]+-[a-z]*f' && block "git clean -f"
match 'git[[:space:]]+worktree[[:space:]]+remove[^"]*--force' && block "worktree の強制削除"
match '(drop[[:space:]]+(table|database|schema)|truncate[[:space:]]+table)' && block "テーブル・DB の削除"
match '(^|[[:space:];&|"])(printenv|env)([[:space:]]*($|[;&|"]))' && block "環境変数の一覧出力"
match '(cat|less|more|head|tail|bat)[[:space:]]+[^"]*\.env([[:space:]."]|$)' && block ".env の表示"
match 'gh[[:space:]]+pr[[:space:]]+merge' && block "PR のマージ"

exit 0
