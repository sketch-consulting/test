#!/usr/bin/env bash
# scripts/new-worktree.sh の自己テスト。使い捨てのリポジトリで、
# 「reviewer は main ではなくレビュー対象のコミットを見る」「integration は検証済みコミットから始まる」を確かめる。
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'command rm -r -- "$tmp"' EXIT
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   $1"; }
ng()   { fail=$((fail+1)); echo "FAIL $1"; }
G() { git -c user.name=t -c user.email=t@example.invalid "$@"; }

repo="$tmp/repo"; mkdir -p "$repo/scripts"
cd "$repo" && git init -q -b main
cp "$here/scripts/new-worktree.sh" scripts/
echo "main の内容" > target.txt
G add -A && G commit -qm init

# 実装役のブランチに、main と区別できる内容をコミットする
scripts/new-worktree.sh T-9 implementer >/dev/null
impl="$tmp/wt/T-9-implementer"
echo "実装ブランチの内容" > "$impl/target.txt"
G -C "$impl" commit -qam "実装"
h="$(git -C "$impl" rev-parse HEAD)"

# reviewer: 対象コミットに固定され、main ではなく実装の内容が見える
scripts/new-worktree.sh T-9 reviewer "$h" >/dev/null
rv="$tmp/wt/T-9-reviewer"
[ "$(git -C "$rv" rev-parse HEAD)" = "$h" ] && ok "reviewer の HEAD がレビュー対象のコミット" || ng "reviewer の HEAD が違う"
grep -q "実装ブランチの内容" "$rv/target.txt" && ok "reviewer の作業場所で実装の内容が読める（main ではない）" || ng "reviewer が main を見ている"
[ -z "$(git -C "$rv" branch --show-current)" ] && ok "reviewer はブランチを持たない（detached）" || ng "reviewer がブランチ上にいる"
grep -q "main の内容" "$repo/target.txt" && ok "統括役の作業場所は main のまま（ここで Read すると main を見てしまう）" || ng "統括役の作業場所が変わった"

# reviewer にコミット指定がなければ止まる
scripts/new-worktree.sh T-8 reviewer >/dev/null 2>&1 && ng "reviewer をコミット指定なしで作れてしまう" || ok "reviewer はコミット指定が必須"

# integration: 検証済みコミットから task/<id> を作る。実装役のブランチは変わらない
scripts/new-worktree.sh T-9 integration "$h" >/dev/null
it="$tmp/wt/T-9-integration"
[ "$(git -C "$it" branch --show-current)" = "task/T-9" ] && ok "integration のブランチは task/T-9" || ng "integration のブランチ名が違う"
[ "$(git -C "$it" rev-parse HEAD)" = "$h" ] && ok "integration は検証済みコミットから始まる" || ng "integration の起点が違う"
mkdir -p "$it/docs/handoff" && echo "記録" > "$it/docs/handoff/T-9.md"
G -C "$it" add -A && G -C "$it" commit -qm "docs: 記録 (T-9)"
[ "$(git -C "$repo" rev-parse agent/T-9/implementer)" = "$h" ] && ok "統括役の記録コミットは実装役のブランチに入らない" || ng "実装役のブランチが変わった"
[ "$(git -C "$repo" diff --name-only "$h" task/T-9)" = "docs/handoff/T-9.md" ] && ok "検証済みコミットからの差分は引き継ぎ記録だけ" || ng "検証済みコミット以外の差分がある"

# 既存の作業場所・ブランチは上書きしない
scripts/new-worktree.sh T-9 integration "$h" >/dev/null 2>&1 && ng "既存の integration を上書きできてしまう" || ok "既存の作業場所は上書きしない"

echo "new-worktree.sh: $pass 件成功 / $fail 件失敗"
[ "$fail" -eq 0 ]
