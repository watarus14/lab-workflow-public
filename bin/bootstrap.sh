#!/usr/bin/env bash
# bootstrap.sh — ホーム直下に研究室標準の骨格（projects writing notes src archive）を作る
#
# 使い方:
#   bin/bootstrap.sh            # 何を作るか表示するだけ（ドライラン。何も変更しない）
#   bin/bootstrap.sh --run      # 実際に作る
#   bin/bootstrap.sh --target DIR [--run]   # ホーム以外に作る（練習・テスト用）
#
# 安全性: 既存のファイル・ディレクトリは上書きも削除もしない。何度実行しても同じ結果（冪等）。

set -euo pipefail

RUN=0
TARGET=${HOME}
while [ $# -gt 0 ]; do
    case $1 in
        --run) RUN=1 ;;
        --target) shift; TARGET=${1:?--target にはディレクトリが必要}; ;;
        -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "不明な引数: $1" >&2; exit 2 ;;
    esac
    shift
done

HERE=$(cd "$(dirname "$0")" && pwd)
SKEL=$HERE/../skeleton
[ -d "$SKEL" ] || { echo "skeleton/ が見つかりません: $SKEL" >&2; exit 1; }

[ "$RUN" -eq 1 ] && echo "== 実行モード: $TARGET に作成します ==" \
                 || echo "== ドライラン（何も変更しません）: $TARGET =="

created=0; kept=0
for d in "$SKEL"/*/; do
    name=$(basename "$d")
    dest=$TARGET/$name
    if [ -d "$dest" ]; then
        echo "  [既にある] $dest"; kept=$((kept+1))
    else
        echo "  [作成]     $dest"; created=$((created+1))
        [ "$RUN" -eq 1 ] && mkdir -p "$dest"
    fi
    # 説明用の README.md は、無い場合だけ置く（既存の README は触らない）
    if [ -f "$d/README.md" ] && [ ! -e "$dest/README.md" ]; then
        echo "  [README]   $dest/README.md"
        [ "$RUN" -eq 1 ] && cp "$d/README.md" "$dest/README.md"
    fi
done

echo "作成予定/作成: $created、既存: $kept"
[ "$RUN" -eq 1 ] || echo "実際に作るには --run を付けて再実行してください。"
