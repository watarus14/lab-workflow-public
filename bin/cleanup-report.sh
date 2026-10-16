#!/usr/bin/env bash
# cleanup-report.sh — どこが容量を食っているかの報告（読み取り専用。何も消さない）
#
# 使い方:
#   bin/cleanup-report.sh              # $HOME を調べる
#   bin/cleanup-report.sh --home DIR   # 別のディレクトリ（テスト用）
#
# 見るもの: 直下の大きい順 / 既知の肥大化しやすい場所（キャッシュ・conda環境・VS Code server）
# 消す作業は自動化しない。報告を見て、人間が判断して消す（docs/05-cleanup 参照）。

set -u
H=$HOME
while [ $# -gt 0 ]; do
    case $1 in
        --home) shift; H=${1:?--home にはディレクトリが必要} ;;
        -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "不明な引数: $1" >&2; exit 2 ;;
    esac
    shift
done

echo "== $H の容量レポート（読み取り専用） =="
echo; echo "## 直下の大きい順 (上位10)"
du -sk "$H"/* "$H"/.[!.]* 2>/dev/null | sort -rn | head -10 | awk '{printf "  %8.1f MB  %s\n", $1/1024, $2}'

echo; echo "## 肥大化しやすい既知の場所"
check() {  # 名前 パス 対処のヒント
    [ -e "$2" ] || return 0
    sz=$(du -sk "$2" 2>/dev/null | cut -f1)
    printf '  %8.1f MB  %s\n' "$(awk "BEGIN{print $sz/1024}")" "$2"
    echo "              → $3"
}
check "pip cache"      "$H/.cache/pip"          "pip cache purge（再取得できるキャッシュ）"
check "conda pkgs"     "$H/miniconda3/pkgs"     "conda clean --all（再取得できるキャッシュ）"
check "conda envs"     "$H/miniconda3/envs"     "使わない環境は conda env export > env/xxx.yml で控えてから conda env remove"
check "anaconda envs"  "$H/anaconda3/envs"      "同上。miniconda と二重に入れていないか確認"
check "vscode-server"  "$H/.vscode-server"      "古い bin/ 配下のバージョンは削除可（最新を残す）"
check "trash"          "$H/.local/share/Trash"  "空にしてよいか確認してから"

echo; echo "## 100MB超のファイル (上位10)"
find "$H" -xdev -type f -size +100M -not -path '*/.git/*' -printf '%s\t%p\n' 2>/dev/null \
  | sort -rn | head -10 | awk -F'\t' '{printf "  %8.1f MB  %s\n", $1/1048576, $2}'

echo; echo "## Gitに入っている巨大ファイル (各プロジェクト、上位3)"
for p in "$H"/projects/*/; do
    [ -d "$p/.git" ] || continue
    big=$(git -C "$p" ls-files -z 2>/dev/null | xargs -0 -r -I{} sh -c 'f="$1"; [ -f "$f" ] && stat -c "%s %n" "$f"' _ "$p/{}" 2>/dev/null | sort -rn | head -3 | awk '$1>5242880{printf "  %8.1f MB  %s\n",$1/1048576,$2}')
    [ -n "$big" ] && { echo " $(basename "$p"):"; echo "$big"; }
done
echo; echo "（以上。何も変更していません）"
