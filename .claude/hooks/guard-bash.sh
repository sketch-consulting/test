#!/usr/bin/env bash
# PreToolUse フック（Bash ツールのみ）: 危険な操作の「よくある書き方」を実行前に止める。
#
# これは補助的な安全網であり、完全な安全境界ではない。
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

# 1. JSON からコマンド文字列を取り出す（jq → python3 → 取り出せなければ JSON 全体を対象にする）
cmd=""
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
elif command -v python3 >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | python3 -I -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input",{}).get("command",""))
except Exception: pass' 2>/dev/null)"
fi
[ -z "$cmd" ] && cmd="$input"

# 2. 正規化: 小文字化し、引用符とバックスラッシュを取り除く
#    （"HEAD:main" → HEAD:main、".env" → .env のように、引用符で隠れないようにする）
norm="$(printf '%s' "$cmd" | tr '[:upper:]' '[:lower:]' | tr -d "\"'\\\\")"
match() { printf '%s' "$norm" | grep -Eq "$1"; }

# 区切り: 空白・行末・コマンド区切り
E='([[:space:];&|)},]|$)'   # } , は JSON 全体を見るフォールバック時の区切り

# 削除
match 'rm[[:space:]]+(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r|--recursive|-r[[:space:]]+-f)' && block "再帰削除 (rm -rf)"
match 'find[[:space:]][^;&|]*-delete' && block "find -delete"
match '(shutil\.rmtree|rimraf|fs\.rm(sync)?\([^)]*recursive)' && block "再帰削除（スクリプト経由）"

# git の破壊的操作・main への反映
match "git[[:space:]]+push[^;&|]*(--force|[[:space:]]-f$E|--mirror|--delete|[[:space:]]:[a-z])" && block "強制 push / リモートブランチ削除"
match "git[[:space:]]+push[^;&|]*[[:space:]](origin[[:space:]]+)?(main|master)$E" && block "main への直接 push"
match "git[[:space:]]+push[^;&|]*:(refs/heads/)?(main|master)$E" && block "main への直接 push (HEAD:main)"
match 'git[[:space:]]+reset[[:space:]]+--hard' && block "git reset --hard"
match 'git[[:space:]]+clean[[:space:]]+-[a-z]*f' && block "git clean -f"
match 'git[[:space:]]+worktree[[:space:]]+remove[^;&|]*--force' && block "worktree の強制削除"
match "git[[:space:]]+branch[[:space:]]+-d[[:space:]]+-f|git[[:space:]]+branch[[:space:]]+-ff?[[:space:]]+(main|master)$E" && block "ブランチの強制操作"
match 'gh[[:space:]]+pr[[:space:]]+merge' && block "PR のマージ"
match 'gh[[:space:]]+api[^;&|]*(protection|rulesets|/merge)' && block "GitHub の保護設定・マージ API"

# データベース
match '(drop[[:space:]]+(table|database|schema)|truncate[[:space:]]+table)' && block "テーブル・DB の削除"

# 秘密情報: 環境変数の一覧
match "(^|[[:space:];&|(])(printenv|env)[[:space:]]*($|[;&|)])" && block "環境変数の一覧出力"

# 秘密情報: .env ファイルへの参照（トークンごとに判定。例示用の .env.example などは除く）
while IFS= read -r tok || [ -n "$tok" ]; do   # 最後のトークン（改行なし）も読む
  [ -z "$tok" ] && continue
  base="${tok##*/}"
  if printf '%s' "$base" | grep -Eq '^\.env(\.[a-z0-9_-]+)?$' \
     && ! printf '%s' "$base" | grep -Eq '^\.env\.(example|sample|template)$'; then
    block ".env への参照 ($tok)"
  fi
done < <(printf '%s' "$norm" | tr ' \t\n;&|<>()`=,{}' '\n\n\n\n\n\n\n\n\n\n\n\n\n\n')

exit 0
