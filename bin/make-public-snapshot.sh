#!/usr/bin/env bash
# make-public-snapshot.sh — 公開用の「履歴なし」コピーを作る（元のリポジトリは変更しない）
#
# 使い方:
#   bin/make-public-snapshot.sh OUTDIR     # OUTDIR は新規または空のディレクトリ
#
# 何をするか:
#   1. 混入検査（bin/render.sh --check）を通す。通らなければ中止
#   2. 現在の内容だけを OUTDIR にコピーする（.git と lab.conf は含めない）
#   3. OUTDIR で git init し、コミットを1つだけ作る
# なぜ: private のリポジトリをそのまま public にすると、過去の全コミットが公開される。
#       昔の版に個人名や研究室の情報が入っていたら漏れるため、履歴を持ち込まない新しいリポジトリにする。
# この後: 中身を目で確認 → GitHub に新しい空のリポジトリを作る → OUTDIR から push（手順は README / Level 5）

set -euo pipefail
OUT=${1:-}
[ -n "$OUT" ] || { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
HERE=$(cd "$(dirname "$0")/.." && pwd)

if [ -e "$OUT" ] && [ -n "$(ls -A "$OUT" 2>/dev/null)" ]; then echo "OUTDIR が空ではありません: $OUT" >&2; exit 1; fi
command -v git >/dev/null || { echo "git がありません" >&2; exit 1; }
name=$(git config --global user.name 2>/dev/null || true); mail=$(git config --global user.email 2>/dev/null || true)
[ -n "$name" ] && [ -n "$mail" ] || { echo "git の user.name / user.email（noreply）を先に設定してください" >&2; exit 1; }
case $mail in *noreply.github.com) ;; *) echo "警告: user.email が noreply ではありません（$mail）。公開すると履歴に載ります。" >&2 ;; esac

echo "== 1. 混入検査 =="
"$HERE/bin/render.sh" --check

echo "== 2. コピー =="
mkdir -p "$OUT"
(cd "$HERE" && tar --exclude=.git --exclude=lab.conf -cf - .) | (cd "$OUT" && tar -xf -)

echo "== 3. 履歴なしの新しいリポジトリ =="
git -C "$OUT" init -q -b main
git -C "$OUT" add .
git -C "$OUT" commit -q -m "Initial public release"
git -C "$OUT" log --oneline
echo "作成しました: $OUT （コミット1つ）。中身を確認してから、新しい空の GitHub リポジトリへ push してください。"
