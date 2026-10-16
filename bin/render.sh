#!/usr/bin/env bash
# render.sh — 文書中の仮の名前（your-cpu-server など）を研究室の値に置き換えた「研究室版」を作る
#
# 使い方:
#   cp lab.conf.example lab.conf        # 右辺を自分の研究室の値に書き換える
#   bin/render.sh --lab OUTDIR          # 置き換え済みのコピーを OUTDIR に作る（元は変更しない）
#   bin/render.sh --check               # リポジトリ本体に、個人情報・研究室の実値が混入していないか検査（読み取り専用）
#
# 仕組み: このリポジトリは、サーバー名などを your-cpu-server のような**仮の名前**で書いてある（そのまま読める）。
#         --lab は、それを lab.conf の値に機械的に置き換えたコピーを作る。OUTDIR は新規または空のみ。
# 仮の名前: your-cpu-server your-gpu-server your-user your-github-id your-channel your-vpn your-lab

set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
MODE=${1:-}; OUT=${2:-}

# 仮の名前 → lab.conf のキー
PLACEHOLDERS=(
  "your-cpu-server:SERVER_CPU"
  "your-gpu-server:SERVER_GPU"
  "your-user:SERVER_USER"
  "your-github-id:GITHUB_USER"
  "your-channel:CHAT_CHANNEL"
  "your-vpn:VPN"
  "your-lab:LAB_NAME"
)

usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; }

case $MODE in
  --check)
    pat='[A-Za-z0-9._%+-]+@(gmail|yahoo|outlook|icloud)\.[a-z]+|([0-9]{1,3}\.){3}[0-9]{1,3}|/home/[a-z0-9_-]+/|/Users/[A-Za-z0-9_-]+/|[0-9]+\+[A-Za-z0-9-]+@users\.noreply'
    if [ -f "$HERE/lab.conf" ]; then
        # shellcheck disable=SC1091
        . "$HERE/lab.conf"
        for v in "${SERVER_CPU:-}" "${SERVER_GPU:-}" "${SERVER_USER:-}" "${GITHUB_USER:-}" "${CHAT_CHANNEL:-}" "${LAB_NAME:-}"; do
            case $v in ""|your-*) ;; *) pat="$pat|$v" ;; esac
        done
    fi
    # lab.conf・.git・このスクリプト自身は除外。/home/user/ 等の例示、文書用のIP(192.0.2.x)、例示のnoreply(12345+...)は許容
    if grep -rEn --exclude-dir=.git --exclude=lab.conf --exclude=render.sh "$pat" "$HERE" \
        | grep -v -E '/home/(<|your|user|\$)' | grep -v -E '(192\.0\.2\.|127\.0\.0\.1|0\.0\.0\.0|12345\+|[^0-9]1\+(t|ci)@)' ; then
        echo; echo "上の行に実値・個人情報の混入の疑いがあります（仮の名前に置き換えるか削除してください）。"; exit 1
    fi
    echo "混入は見つかりませんでした。"; exit 0 ;;
  --lab)
    [ -n "$OUT" ] || { usage; exit 1; }
    [ -f "$HERE/lab.conf" ] || { echo "lab.conf がありません。lab.conf.example をコピーして編集してください。" >&2; exit 1; }
    # shellcheck disable=SC1091
    . "$HERE/lab.conf"
    if [ -e "$OUT" ] && [ -n "$(ls -A "$OUT" 2>/dev/null)" ]; then echo "OUTDIR が空ではありません: $OUT" >&2; exit 1; fi
    mkdir -p "$OUT"
    (cd "$HERE" && tar --exclude=.git --exclude=lab.conf -cf - .) | (cd "$OUT" && tar -xf -)
    esc() { printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'; }
    for pair in "${PLACEHOLDERS[@]}"; do
        ph=${pair%%:*}; key=${pair##*:}
        val=${!key-}
        [ -n "$val" ] || { echo "  [注意] lab.conf に $key がありません（$ph はそのまま残ります）"; continue; }
        [ "$val" = "$ph" ] && continue
        while IFS= read -r -d '' f; do
            sed -i "s|$ph|$(esc "$val")|g" "$f"
        done < <(grep -rlIZ --exclude=render.sh --exclude=lab.conf.example -e "$ph" "$OUT" || true)
    done
    echo "作成しました: $OUT （研究室版）" ;;
  *) usage; exit 1 ;;
esac
