#!/usr/bin/env bash
# new-run.sh — runs/<run_id>/ を作り、再現用のメタ情報を保存して run_id を標準出力に出す
#
# 使い方（サーバー上、プロジェクト内のどこからでも可）:
#   RUN_ID=$(./scripts/new-run.sh baseline [config/server-a.yml])
#
# 作られるもの:
#   runs/<run_id>/{output,logs,meta}
#   meta/git-hash.txt        実行時のコミット
#   meta/git-status.txt      未コミットの変更一覧（ノートブック編集中でも辿れる）
#   meta/uncommitted.diff    追跡済みファイルの未コミット差分
#   meta/env.txt             日時・ホスト・OS
# 未コミットの変更がある場合、run_id の末尾に -dirty が付く。

set -euo pipefail

TAG=${1:?"usage: new-run.sh <tag> [config-file]"}
CONF=${2:-}
case $TAG in
    *[!a-z0-9-]*) echo "tag は小文字英数字とハイフンのみ" >&2; exit 1 ;;
esac

ROOT=$(git rev-parse --show-toplevel)
HASH=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo nocommit)
STATUS=$(git -C "$ROOT" status --porcelain)
DIRTY=""
[ -n "$STATUS" ] && DIRTY="-dirty"

RUN_ID="$(date +%Y%m%d-%H%M)_${TAG}_${HASH}${DIRTY}"
RUN="$ROOT/runs/$RUN_ID"
mkdir -p "$RUN"/{output,logs,meta}

git -C "$ROOT" rev-parse HEAD > "$RUN/meta/git-hash.txt" 2>/dev/null || echo nocommit > "$RUN/meta/git-hash.txt"
printf '%s\n' "$STATUS" > "$RUN/meta/git-status.txt"
git -C "$ROOT" diff HEAD > "$RUN/meta/uncommitted.diff" 2>/dev/null || : > "$RUN/meta/uncommitted.diff"
[ -n "$CONF" ] && cp "$CONF" "$RUN/meta/"
{ date +%Y-%m-%dT%H:%M:%S%z; hostname; uname -sr; } > "$RUN/meta/env.txt"   # date -I はBSD(mac)に無いので使わない

echo "$RUN_ID"
