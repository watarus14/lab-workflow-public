#!/usr/bin/env bash
# home-organize.sh — moves.tsv に書いた移動を、安全に実行する。★削除は一切しない★
#
# 使い方:
#   ./home-organize.sh moves.tsv                 # ドライラン（既定。何も動かさない）
#   ./home-organize.sh moves.tsv --run           # 実行。元に戻すための undo-<日時>.tsv を作る
#   ./home-organize.sh undo-XXXX.tsv --run       # 元に戻す（undoファイルも同じ形式）
#
# 移動表: 1行1件。「移動元 -> 移動先」（またはタブ区切り）。~/ からの相対パス（または絶対パス）。
#            空行と、行頭が#の行は無視（行末コメントは使えない）。例:
#              QML_Project -> projects/qml-project
#              Rinko -> notes/rinko
#
# 安全装置:
#   - 移動先がすでに存在したら、その行は実行しない（上書きしない）
#   - ドットで始まる項目（.bashrc, .ssh, .conda など）は拒否
#   - ホームの外、'..' を含むパスは拒否。自分自身の中への移動も拒否
#   - 移動元が無ければ飛ばす
#   - 実行した行は undo ファイルに逆順で記録する

set -u
FILE=${1:-}
MODE=${2:-dry}
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
fi
RUN=0
[ "$MODE" = "--run" ] && RUN=1

HOME_REAL=$(cd "$HOME" && pwd -P)
UNDO_TMP=$(mktemp)
trap 'rm -f "$UNDO_TMP"' EXIT

abs() { case $1 in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$HOME_REAL" "$1" ;; esac; }

ok=0; skip=0
SEEN_SRC=""; SEEN_DST=""
while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    [ -z "${line//[[:space:]]/}" ] && continue
    case $line in '#'*) continue ;; esac
    case $line in
        *$'\t'*)  src=${line%%$'\t'*}; dst=${line#*$'\t'} ;;
        *' -> '*) src=${line%% -> *};  dst=${line#* -> } ;;
        *) echo "[NG] 形式が違います（'移動元 -> 移動先' かタブ区切り）: $line"; skip=$((skip+1)); continue ;;
    esac
    case "$src$dst" in *' #'*) echo "[NG] 行末コメントは使えません（コメントは別の行に）: $line"; skip=$((skip+1)); continue ;; esac
    if [ -z "$src" ] || [ -z "$dst" ]; then echo "[NG] 移動元か移動先が空です: $line"; skip=$((skip+1)); continue; fi
    case "$src$dst" in *..*) echo "[NG] '..' を含むパスは拒否: $src -> $dst"; skip=$((skip+1)); continue ;; esac

    s=$(abs "$src"); d=$(abs "$dst")
    s=${s%/}; d=${d%/}
    case $s in "$HOME_REAL"/*) ;; *) echo "[NG] ホームの外は拒否: $src"; skip=$((skip+1)); continue ;; esac
    case $d in "$HOME_REAL"/*) ;; *) echo "[NG] ホームの外は拒否: $dst"; skip=$((skip+1)); continue ;; esac

    rel=${s#"$HOME_REAL"/}; top=${rel%%/*}
    case $top in .*) echo "[NG] ドット項目は拒否: $src"; skip=$((skip+1)); continue ;; esac
    case "$d/" in "$s"/*) echo "[NG] 自分自身の中へは移動できません: $src -> $dst"; skip=$((skip+1)); continue ;; esac

    if [ ! -e "$s" ] && [ ! -L "$s" ]; then echo "[--] 移動元がありません（飛ばす）: $src"; skip=$((skip+1)); continue; fi
    if [ -e "$d" ] || [ -L "$d" ]; then echo "[NG] 移動先が既に存在: $dst"; skip=$((skip+1)); continue; fi

    # 同じ移動元・移動先が複数行にあるのを、ドライランの段階で検出する
    case "$SEEN_SRC" in *"|$s|"*) echo "[NG] 同じ移動元が複数行にあります: $src"; skip=$((skip+1)); continue ;; esac
    case "$SEEN_DST" in *"|$d|"*) echo "[NG] 同じ移動先が複数行にあります: $dst"; skip=$((skip+1)); continue ;; esac
    SEEN_SRC="$SEEN_SRC|$s|"; SEEN_DST="$SEEN_DST|$d|"

    if [ "$RUN" = 1 ]; then
        mkdir -p -- "$(dirname -- "$d")" || { echo "[NG] 作成失敗: $(dirname -- "$d")"; skip=$((skip+1)); continue; }
        if mv -n -- "$s" "$d" && [ ! -e "$s" ] && [ -e "$d" ]; then
            echo "[OK] $src -> $dst"
            printf '%s\t%s\n' "$d" "$s" >> "$UNDO_TMP"
            ok=$((ok+1))
        else
            echo "[NG] mv に失敗: $src -> $dst"; skip=$((skip+1))
        fi
    else
        echo "[dry] $src -> $dst"
        ok=$((ok+1))
    fi
done < "$FILE"

echo
if [ "$RUN" = 1 ]; then
    if [ -s "$UNDO_TMP" ]; then
        UNDO="undo-$(date +%Y%m%d-%H%M%S).tsv"
        awk '{a[NR]=$0} END{for(i=NR;i>=1;i--)print a[i]}' "$UNDO_TMP" > "$UNDO"
        echo "実行: ${ok}件 / 実行しなかった: ${skip}件"
        echo "元に戻す: ./$(basename "$0") $UNDO --run"
    else
        echo "実行: 0件 / 実行しなかった: ${skip}件"
    fi
else
    echo "ドライラン: 実行できる ${ok}件 / 実行しない ${skip}件。問題なければ --run を付けて再実行"
fi
