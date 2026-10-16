#!/usr/bin/env bash
# pick-figure.sh — 回収済みの結果から「論文に採用する図」を paper/figures/ へコピーし、出所を記録する
#
# 使い方（ローカル）:
#   ./scripts/pick-figure.sh <server> <run_id> <output内の相対パス> [保存名]
# 例:
#   ./scripts/pick-figure.sh server-a 20261014-1530_baseline_a1b2c3d fig/loss.pdf fig-loss.pdf
#
# 元:   results/<server>/<run_id>/output/<相対パス>   （results-pull 済みであること）
# 先:   paper/figures/<保存名>                        （省略時は元のファイル名）
# 記録: paper/figures/SOURCES.tsv に 保存名・server・run_id・元パス・日時 を追記
# 既存の保存名は上書きしない。更新する時は FORCE=1 を付ける。

set -euo pipefail

[ $# -ge 3 ] || { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
SERVER=$1; RUN_ID=$2; REL=$3
NAME=${4:-$(basename "$REL")}

ROOT=$(git rev-parse --show-toplevel)
SRC="$ROOT/results/$SERVER/$RUN_ID/output/$REL"
[ -f "$SRC" ] || { echo "見つかりません: $SRC （先に results-pull しましたか?）" >&2; exit 1; }

DEST_DIR="$ROOT/paper/figures"
mkdir -p "$DEST_DIR"
if [ -e "$DEST_DIR/$NAME" ] && [ -z "${FORCE:-}" ]; then
    echo "既に存在: paper/figures/$NAME （上書きするなら FORCE=1、または別名を指定）" >&2
    exit 1
fi

case $RUN_ID in
    *-dirty) echo "[warn] この run は未コミットの変更あり。再現には results/$SERVER/$RUN_ID/meta/uncommitted.diff も確認" >&2 ;;
esac

cp "$SRC" "$DEST_DIR/$NAME"

LOG="$DEST_DIR/SOURCES.tsv"
[ -e "$LOG" ] || printf 'name\tserver\trun_id\tsource\tpicked_at\n' > "$LOG"
printf '%s\t%s\t%s\t%s\t%s\n' "$NAME" "$SERVER" "$RUN_ID" "$REL" "$(date +%Y-%m-%dT%H:%M:%S%z)" >> "$LOG"

echo "copied: paper/figures/$NAME"
