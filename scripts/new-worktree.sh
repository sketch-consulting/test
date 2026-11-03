#!/usr/bin/env bash
# 使い方: scripts/new-worktree.sh <task-id> <role>
#   implementer … ブランチ agent/<task-id>/implementer を main から作り、../wt/<task-id>-implementer に置く
#   verifier    … ブランチを作らず、main を detached で ../wt/<task-id>-verifier に置く
#                 （検証時に対象コミットを git checkout --detach <hash> で取り出す）
# reviewer は worktree 不要（統括役の作業ツリーから git の読み取りだけで見る）。
# 既に存在する場合は上書きせずに止める（他エージェントの作業を壊さないため）。
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: $0 <task-id> <implementer|verifier>" >&2
  exit 1
fi

task="$1"; role="$2"
case "$role" in implementer|verifier) ;; *) echo "role は implementer|verifier のいずれか（reviewer は worktree 不要）" >&2; exit 1;; esac
[[ "$task" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "task-id は英数字と . _ - のみ" >&2; exit 1; }

root="$(git rev-parse --show-toplevel)"
dir="$(cd "$root/.." && pwd)/wt/${task}-${role}"
[ -e "$dir" ] && { echo "${dir} は既に存在します。上書きしません。" >&2; exit 1; }

base="main"
if git -C "$root" remote get-url origin >/dev/null 2>&1 && git -C "$root" fetch --quiet origin main 2>/dev/null; then
  base="origin/main"
fi
mkdir -p "$(dirname "$dir")"

if [ "$role" = implementer ]; then
  branch="agent/${task}/implementer"
  if git -C "$root" show-ref --verify --quiet "refs/heads/${branch}"; then
    echo "ブランチ ${branch} は既に存在します。上書きしません。" >&2; exit 1
  fi
  git -C "$root" worktree add -q -b "$branch" "$dir" "$base"
  echo "branch:   $branch"
else
  git -C "$root" worktree add -q --detach "$dir" "$base"
  echo "branch:   (detached)"
fi
echo "worktree: $dir"
echo "base:     $base ($(git -C "$dir" rev-parse --short HEAD))"
