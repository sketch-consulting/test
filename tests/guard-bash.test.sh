#!/usr/bin/env bash
# .claude/hooks/guard-bash.sh の自己テスト。
# 「止める」ケースに加え、「止められない」ケースも明示的にテストしている。
# 止められないケースが通過するのは仕様（限界の記録）であり、ここが失敗したら
# docs/safety-boundaries.md の記述も見直すこと。
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
hook="$here/.claude/hooks/guard-bash.sh"
pass=0; fail=0

run() { printf '%s' "$1" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' | bash "$hook" 2>/dev/null; echo $?; }
blocked() { [ "$(run "$1")" = 2 ] && { pass=$((pass+1)); echo "ok   止める     | $1"; } || { fail=$((fail+1)); echo "FAIL 止まらない | $1"; }; }
allowed() { [ "$(run "$1")" = 0 ] && { pass=$((pass+1)); echo "ok   通す       | $1"; } || { fail=$((fail+1)); echo "FAIL 止まった   | $1"; }; }
limit()   { [ "$(run "$1")" = 0 ] && { pass=$((pass+1)); echo "ok   限界(通過) | $1"; } || { fail=$((fail+1)); echo "FAIL 限界の記録と違う（止まった）| $1"; }; }

r='rm'  # このファイル自体がフックに引っかからないよう分割
blocked "$r -rf build"
blocked "$r -fr /tmp/x"
blocked "find . -name '*.log' -delete"
blocked "python3 -c 'import shutil; shutil.rmtree(\"b\")'"
blocked "git push --force origin feature"
blocked "git push -f"
blocked "git push origin main"
blocked "git push origin HEAD:main"
blocked "git push origin :feature"
blocked "git reset --hard HEAD~1"
blocked "git clean -fd"
blocked "gh pr merge 3"
blocked "gh api repos/o/r/branches/main/protection -X DELETE"
blocked "psql -c 'DROP TABLE users'"
blocked "printenv"
blocked "env | grep KEY"
blocked "cat .env"
blocked "grep . .env.local"
blocked "source ./.env"

# 引用符・複数パス（dot の独立確認で見つかったケース。文字列をフックに渡すだけで、ファイルは読まない）
blocked 'cat ".env"'
blocked "cat '.env'"
blocked 'cat .env .env.example'
blocked 'cat .env.example .env'
blocked 'cat ".env.local"'
blocked 'head -n1 ./config/.env'
blocked 'cat <.env'
blocked 'git push origin "HEAD:main"'
blocked "git push origin 'main'"
blocked 'git push origin "HEAD:refs/heads/main"'
blocked 'git push "origin" "main"'
blocked 'git push origin HEAD:main && echo done'

allowed "git status"
allowed 'cat .env.example'
allowed 'cat ".env.example" .env.sample'
allowed 'ls .envrc'
allowed 'git push origin "agent/T-1/implementer"'
allowed 'git push origin feature/main-menu'
allowed 'echo "update maintenance doc"'
allowed "npm test"
allowed "git push -u origin agent/T-1/implementer"
allowed "cp .env.example .env.sample"
allowed "$r build/tmp.txt"

# 限界: 以下はフックでは止められない（GitHub 側の保護・運用・終了後の確認で補う）
limit "git push"                                  # 今いるブランチが main でも判別できない
limit "R=$r; \$R -rf build"                       # 変数経由
limit "bash cleanup.sh"                           # スクリプトファイルの中身は見えない
limit "node -e 'require(\"fs\").unlinkSync(\"a\")'" # 別言語からの単発削除
limit "echo x > src/a.js"                         # Bash 経由の書き込み（読み取り専用の役でも止まらない）
limit "base64 -d <<< Y2F0IC5lbnY= | sh"           # 難読化

# jq がない環境（python3 で取り出す経路）と、どちらもない環境（JSON 全体を見る経路）
json='{"tool_name":"Bash","tool_input":{"command":"git push origin \"HEAD:main\""}}'
for tools in "bash tr grep cat python3" "bash tr grep cat"; do
  d="$(mktemp -d)"; for c in $tools; do ln -s "$(command -v "$c")" "$d/$c"; done
  printf '%s' "$json" | env PATH="$d" bash "$hook" 2>/dev/null; got=$?
  [ "$got" = 2 ] && { pass=$((pass+1)); echo "ok   止める     | [PATH: $tools] git push origin \"HEAD:main\""; } \
                 || { fail=$((fail+1)); echo "FAIL 止まらない | [PATH: $tools] git push origin \"HEAD:main\""; }
  command rm -r -- "$d"
done

echo "guard-bash.sh: $pass 件成功 / $fail 件失敗"
[ "$fail" -eq 0 ]
