#!/usr/bin/env bash
# 使い方: scripts/new-worktree.sh <task-id> <role>
#   role: implementer | reviewer | verifier
# ブランチ agent/<task-id>/<role> を main から作り、../wt/<task-id>-<role> に worktree を置く。
# 既に存在する場合は上書きせずに止める（他エージェントの作業を壊さないため）。
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: $0 <task-id> <role>" >&2
  exit 1
fi

task="$1"; role="$2"
case "$role" in implementer|reviewer|verifier) ;; *) echo "role は implementer|reviewer|verifier のいずれか" >&2; exit 1;; esac
[[ "$task" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "task-id は英数字と . _ - のみ" >&2; exit 1; }

root="$(git rev-parse --show-toplevel)"
branch="agent/${task}/${role}"
dir="$(cd "$root/.." && pwd)/wt/${task}-${role}"

if git -C "$root" show-ref --verify --quiet "refs/heads/${branch}"; then
  echo "ブランチ ${branch} は既に存在します。上書きしません。" >&2; exit 1
fi
if [ -e "$dir" ]; then
  echo "${dir} は既に存在します。上書きしません。" >&2; exit 1
fi

base="main"
if git -C "$root" fetch --quiet origin main 2>/dev/null; then base="origin/main"; fi

mkdir -p "$(dirname "$dir")"
git -C "$root" worktree add -b "$branch" "$dir" "$base"
echo "worktree: $dir"
echo "branch:   $branch"
