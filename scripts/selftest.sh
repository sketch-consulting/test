#!/usr/bin/env bash
# このリポジトリ自身の仕組み（品質チェックと安全フック）の自己テスト。
# プロジェクトの品質チェック（scripts/check.sh）とは別物。
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
rc=0
python3 -m json.tool .claude/settings.json >/dev/null && echo "ok   settings.json は正しい JSON" || { echo "FAIL settings.json"; rc=1; }
bash tests/check.test.sh      || rc=1
bash tests/guard-bash.test.sh || rc=1
exit $rc
