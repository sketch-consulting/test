#!/usr/bin/env bash
# 役割ごとの作業場所（git worktree）を作る。作るのは統括役。既にあれば上書きせずに止める。
#
# 使い方:
#   scripts/new-worktree.sh <task-id> implementer            … ブランチ agent/<id>/implementer を main から作る（実装役専用）
#   scripts/new-worktree.sh <task-id> verifier               … ブランチなし。main を detached で置く（検証時に対象コミットへ切り替える）
#   scripts/new-worktree.sh <task-id> reviewer <commit>      … ブランチなし。レビュー対象のコミットに固定（detached）
#   scripts/new-worktree.sh <task-id> integration <commit>   … ブランチ task/<id> を「検証済みコミット」から作る（統括役専用）
#
# 場所はすべて ../wt/<task-id>-<role>。
set -euo pipefail

usage() { echo "usage: $0 <task-id> implementer|verifier  /  $0 <task-id> reviewer|integration <commit>" >&2; exit 1; }
[ $# -ge 2 ] || usage
task="$1"; role="$2"; commit="${3:-}"
[[ "$task" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "task-id は英数字と . _ - のみ" >&2; exit 1; }
case "$role" in
  implementer|verifier) [ -z "$commit" ] || usage ;;
  reviewer|integration) [ -n "$commit" ] || { echo "$role にはコミット（ハッシュ）の指定が必要です" >&2; exit 1; } ;;
  *) usage ;;
esac

root="$(git rev-parse --show-toplevel)"
dir="$(cd "$root/.." && pwd)/wt/${task}-${role}"
[ -e "$dir" ] && { echo "${dir} は既に存在します。上書きしません。" >&2; exit 1; }

if [ -n "$commit" ]; then
  commit="$(git -C "$root" rev-parse --verify --quiet "${commit}^{commit}")" || { echo "コミット ${3} が見つかりません" >&2; exit 1; }
fi

base="main"
if git -C "$root" remote get-url origin >/dev/null 2>&1 && git -C "$root" fetch --quiet origin main 2>/dev/null; then
  base="origin/main"
fi
mkdir -p "$(dirname "$dir")"

new_branch() {
  local branch="$1" from="$2"
  if git -C "$root" show-ref --verify --quiet "refs/heads/${branch}"; then
    echo "ブランチ ${branch} は既に存在します。上書きしません。" >&2; exit 1
  fi
  git -C "$root" worktree add -q -b "$branch" "$dir" "$from"
  echo "branch:   $branch"
}

case "$role" in
  implementer) new_branch "agent/${task}/implementer" "$base" ;;
  integration) new_branch "task/${task}" "$commit" ;;
  verifier)    git -C "$root" worktree add -q --detach "$dir" "$base"; echo "branch:   (detached)" ;;
  reviewer)    git -C "$root" worktree add -q --detach "$dir" "$commit"; echo "branch:   (detached, レビュー対象に固定)" ;;
esac
echo "worktree: $dir"
echo "HEAD:     $(git -C "$dir" rev-parse HEAD)"
