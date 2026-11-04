#!/usr/bin/env bash
# scripts/check.sh の自己テスト。設定ファイルを差し替えて終了コードを確かめる。
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'command rm -r -- "$tmp"' EXIT
pass=0; fail=0

expect() { # <説明> <期待する終了コード> <設定ファイルの中身>
  printf '%s\n' "$3" > "$tmp/cfg"
  CHECK_CONFIG="$tmp/cfg" bash "$here/scripts/check.sh" > "$tmp/out" 2>&1
  local got=$?
  if [ "$got" -eq "$2" ]; then pass=$((pass+1)); echo "ok   $1 (exit $got)"
  else fail=$((fail+1)); echo "FAIL $1: 期待 $2 / 実際 $got"; sed 's/^/     /' "$tmp/out"; fi
}

expect "空の設定ファイル → 未設定"           2 ""
CHECK_CONFIG="$tmp/none" bash "$here/scripts/check.sh" >/dev/null 2>&1; got=$?
if [ "$got" -eq 2 ]; then pass=$((pass+1)); echo "ok   設定ファイルが存在しない (exit 2)"; else fail=$((fail+1)); echo "FAIL 設定ファイルが存在しない: 実際 $got"; fi

expect "全部空 → 未設定"                     2 $'CHECK_LINT=\nCHECK_TYPECHECK=\nCHECK_TEST='
expect "lint だけ設定 → 未設定（成功しない）" 2 $'CHECK_LINT=true\nCHECK_TYPECHECK=\nCHECK_TEST='
expect "3 つとも成功 → 成功"                 0 $'CHECK_LINT=true\nCHECK_TYPECHECK=true\nCHECK_TEST=true'
expect "テスト失敗 → 失敗"                   1 $'CHECK_LINT=true\nCHECK_TYPECHECK=true\nCHECK_TEST=false'
expect "失敗と未設定が混在 → 失敗を優先"     1 $'CHECK_LINT=false\nCHECK_TYPECHECK=\nCHECK_TEST=true'
expect "NA に理由あり → 成功（対象外と表示）" 0 $'CHECK_LINT=true\nCHECK_TYPECHECK=NA: 型のない言語\nCHECK_TEST=true'
expect "NA の理由が空 → 未設定"              2 $'CHECK_LINT=true\nCHECK_TYPECHECK=NA:\nCHECK_TEST=true'
expect "項目の行がない → 未設定"             2 $'CHECK_LINT=true\nCHECK_TEST=true'

# 複数コマンド・パイプでの失敗が隠れないこと（dot の独立確認で見つかったケース）
base=$'CHECK_LINT=true\nCHECK_TYPECHECK=true\nCHECK_TEST='
expect "パイプの前段が失敗 (false | cat) → 失敗"   1 "${base}false | cat"
expect "パイプの後段が失敗 (true | false) → 失敗"  1 "${base}true | false"
expect "; の前が失敗 (false; true) → 失敗"         1 "${base}false; true"
expect "&& の前が失敗 (false && true) → 失敗"      1 "${base}false && true"
expect "&& の後が失敗 (true && false) → 失敗"      1 "${base}true && false"
expect "すべて成功 (true && true | cat) → 成功"    0 "${base}true && true | cat"
expect "|| で握りつぶし → 設定不正"                2 "${base}false || true"
expect "set +e で握りつぶし → 設定不正"            2 "${base}set +e; false; true"
expect "trap で握りつぶし → 設定不正"              2 "${base}trap 'exit 0' EXIT; false"
expect "未定義変数 → 失敗"                         1 "${base}echo \$UNDEFINED_VAR_FOR_TEST"

# 現行仕様の記録: 3 つとも NA にすると成功する（変えるかどうかは人の判断。docs/safety-boundaries.md 参照）
expect "全部 NA（現行仕様）→ 成功"                 0 $'CHECK_LINT=NA: a\nCHECK_TYPECHECK=NA: b\nCHECK_TEST=NA: c'

echo "check.sh: $pass 件成功 / $fail 件失敗"
[ "$fail" -eq 0 ]
