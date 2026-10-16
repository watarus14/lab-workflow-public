#!/usr/bin/env bash
# normalize-names.sh — 名前を「小文字 + ハイフン」に直す移動案を作る（案を出すだけ。何も変更しない）
#
# 使い方:
#   bin/normalize-names.sh                 # ~/projects の直下を調べる
#   bin/normalize-names.sh ~/writing       # 別のディレクトリ
#   bin/normalize-names.sh > moves.txt     # 案をファイルに保存 → 確認・編集 → home-organize.sh へ
#
# 変換規則: 大文字→小文字、_ と空白→ハイフン、連続ハイフンを1つに、前後のハイフンを除去
#   例: QML_Project -> qml-project / My Data -> my-data
#   ※ CamelCase（MyProject）は語の切れ目が不確かなので myproject になる。必要なら案を手で直す。
# 出力は home-organize.sh の移動表の形式（「移動元 -> 移動先」）。ホームの外を調べた場合は絶対パス。
# 自動では直せないもの（日本語等・衝突）は「# 要手動:」「# 衝突:」の行で知らせる。
#
# 注意: プロジェクト内の相対パス・設定・editable install・Jupyter カーネルは、名前を変えると
#       壊れることがある。実行前に moves.txt を home-organize.sh のドライランで確認すること。

set -u
BASE=${1:-$HOME/projects}
[ -d "$BASE" ] || { echo "ディレクトリがありません: $BASE" >&2; exit 1; }
BASE=$(cd "$BASE" && pwd -P)
HOME_REAL=$(cd "$HOME" && pwd -P)
case $BASE in "$HOME_REAL"/*) PREFIX=${BASE#"$HOME_REAL"/} ;; *) PREFIX=$BASE ;; esac

norm() {
    printf '%s' "$1" | tr 'A-Z' 'a-z' | sed -e 's/[_[:space:]]\{1,\}/-/g' -e 's/-\{2,\}/-/g' -e 's/^-//' -e 's/-$//'
}

declare -A seen=()
changed=0
while IFS= read -r -d '' p; do
    name=${p##*/}
    case $name in .*) continue ;; esac
    if printf '%s' "$name" | LC_ALL=C grep -q '[^ -~]'; then
        echo "# 要手動: $PREFIX/$name （非ASCII文字を含むため自動では決められません）"; continue
    fi
    new=$(norm "$name")
    [ "$new" = "$name" ] && continue
    if [ -e "$BASE/$new" ] || [ -n "${seen[$new]:-}" ]; then
        echo "# 衝突: $PREFIX/$name -> $PREFIX/$new （同名が既にある／他の案と重複）"; continue
    fi
    seen[$new]=1
    echo "$PREFIX/$name -> $PREFIX/$new"; changed=$((changed+1))
done < <(find "$BASE" -mindepth 1 -maxdepth 1 -print0 | sort -z)

echo "# 変更案: $changed 件（確認してから home-organize.sh へ。このスクリプトは何も変更していません）" >&2
