#!/usr/bin/env bash
# 品質ゲート: lint・型検査・テストをまとめて実行する。1 つでも失敗したら非ゼロで終わる。
# 何も設定されていない場合も失敗させる（「チェックが無いので通過」を防ぐため）。
# プロジェクトに合わせて自由に書き換えてよい。
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

ran=0; failed=0
run() {
  echo "▶ $*"
  ran=1
  if ! "$@"; then echo "✖ 失敗: $*"; failed=1; fi
}

has_npm_script() { node -e "process.exit(require('./package.json').scripts?.['$1']?0:1)" 2>/dev/null; }

if [ -f package.json ]; then
  for s in lint typecheck test; do
    has_npm_script "$s" && run npm run --silent "$s"
  done
fi

if [ -f pyproject.toml ] || [ -f requirements.txt ]; then
  command -v ruff   >/dev/null && run ruff check .
  command -v mypy   >/dev/null && [ -f mypy.ini -o -f pyproject.toml ] && run mypy .
  command -v pytest >/dev/null && run pytest -q
fi

if [ "$ran" -eq 0 ]; then
  echo "✖ 実行できるチェックがありません。scripts/check.sh をプロジェクトに合わせて設定してください。"
  exit 1
fi
[ "$failed" -eq 0 ] && echo "✔ すべてのチェックが通りました" || exit 1
