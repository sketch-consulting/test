#!/usr/bin/env bash
# 品質ゲート: scripts/check.config に書かれた必須チェック（lint・型検査・テスト）を実行する。
#
# 終了コード
#   0 … 必須 3 項目がすべて「実行して成功」または「NA:<理由> と明示」
#   1 … どれかが実行されて失敗した
#   2 … どれかが未設定（空、NA の理由なし、設定ファイルなし）または設定不正。成功扱いにはしない
#
# コマンドの書き方
#   - 1 行の bash コマンド。`bash -euo pipefail -c` で実行するので、
#     `a && b`、`a; b`、`a | b` のどこで失敗しても全体が失敗になる。
#   - `||`、`set +e` / `set +o`、`trap` を含むコマンドは「失敗を隠せる」ため設定不正（exit 2）。
#     失敗を許したい事情があるなら、スクリプトファイルに切り出して人がレビューする。
#
# 環境変数 CHECK_CONFIG で設定ファイルの場所を変えられる（自己テスト用）。
set -uo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"
config="${CHECK_CONFIG:-$root/scripts/check.config}"

if [ ! -f "$config" ]; then
  echo "✖ 設定ファイルがありません: $config"
  echo "  scripts/check.config を作り、CHECK_LINT / CHECK_TYPECHECK / CHECK_TEST を設定してください。"
  exit 2
fi

# 設定を読む（source はしない。KEY=値 の行だけを文字列として取り出す）
get() { grep -E "^$1=" "$config" | tail -n 1 | cut -d= -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

required=(CHECK_LINT CHECK_TYPECHECK CHECK_TEST)
label() { case "$1" in CHECK_LINT) echo lint;; CHECK_TYPECHECK) echo typecheck;; CHECK_TEST) echo test;; esac; }

declare -A result
unconfigured=0; failed=0

for key in "${required[@]}"; do
  cmd="$(get "$key")"
  name="$(label "$key")"
  if [ -z "$cmd" ]; then
    result[$key]="未設定"; unconfigured=1; continue
  fi
  if [[ "$cmd" == NA:* ]]; then
    reason="${cmd#NA:}"; reason="${reason#"${reason%%[![:space:]]*}"}"
    if [ -z "$reason" ]; then result[$key]="未設定（NA の理由が空）"; unconfigured=1
    else result[$key]="対象外（$reason）"; fi
    continue
  fi
  # 失敗を握りつぶす書き方は設定不正として扱う（実行しない）
  if printf '%s' "$cmd" | grep -Eq '\|\||(^|[;&[:space:]])(set[[:space:]]+\+[eo]|trap[[:space:]])'; then
    result[$key]="設定不正（|| や set +e などで失敗を隠す書き方は使えない）"; unconfigured=1; continue
  fi
  echo "▶ [$name] $cmd"
  # -e: 途中のコマンドが失敗したら止める  -u: 未定義変数は失敗  pipefail: パイプ内の失敗を伝える
  if bash -euo pipefail -c "$cmd"; then result[$key]="成功"
  else result[$key]="失敗"; failed=1; fi
done

echo
echo "── 品質チェック結果 ──"
for key in "${required[@]}"; do printf '  %-10s %s\n' "$(label "$key")" "${result[$key]}"; done

if [ "$failed" -eq 1 ]; then
  echo "✖ 失敗したチェックがあります。"
  exit 1
fi
if [ "$unconfigured" -eq 1 ]; then
  echo "✖ 未設定の必須チェックがあります。scripts/check.config を設定してください（成功扱いにはしません）。"
  exit 2
fi
echo "✔ 必須チェックはすべて通りました"
exit 0
