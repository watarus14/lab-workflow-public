#!/usr/bin/env bash
# home-inventory.sh — ホーム直下を「読むだけ」で棚卸しし、Markdownで出力する。
# ★何も変更・削除・移動しない★（git status 等の読み取りコマンドだけを使う）
#
# 使い方:
#   ./home-inventory.sh > ~/inventory.md            # 既定の対象は $HOME
#   ./home-inventory.sh /path/to/dir > inv.md
#   ./home-inventory.sh --fast > ~/inventory.md     # サーバー向け: サイズ計算を短時間で打ち切る
#
# 出力:
#   1. ドットなしの項目ごとに 種類・サイズ・最終更新・中身の目印・gitの状態
#   2. 入れ子になっているgitリポジトリ（例: ~/github/ 以下）の状態
#   3. ドット項目（設定・ツール管理）の一覧とサイズ
#   4. 実行中・待機中のジョブ（Slurm、または qstat 系の PBS / Grid Engine が使えれば）と、容量・クォータ
#      → 整理（移動）の前に「走っているジョブが無い」ことを確認するため
#
# 注意: サイズ計算(du)は大きなディレクトリ（miniconda3 や .cache など）で時間がかかることがある。
# 公開してよいか確認してから貼ること（リポジトリのURLが出る）。

set -u
FAST=0
ROOT=""
for a in "$@"; do
    case $a in
        --fast) FAST=1 ;;
        -*) echo "不明なオプション: $a" >&2; exit 1 ;;
        *) ROOT=$a ;;
    esac
done
ROOT=${ROOT:-$HOME}
cd "$ROOT" || { echo "cd できません: $ROOT" >&2; exit 1; }

# GNU find の -printf が使えるか（Macの標準findでは使えない）
HAVE_PRINTF=0
find . -maxdepth 0 -printf '' >/dev/null 2>&1 && HAVE_PRINTF=1

# 共有ファイルシステム（NFS / Lustre）で巨大なディレクトリを延々と数えないための打ち切り
if command -v timeout >/dev/null 2>&1; then TMO="timeout 15"; else TMO=""; fi

size_of() {  # $1=path
    if [ "$FAST" = 1 ]; then
        local r
        r=$($TMO du -sh -- "$1" 2>/dev/null | cut -f1)
        if [ -z "$r" ]; then printf '>15秒'; else printf '%s' "$r"; fi
    else
        du -sh -- "$1" 2>/dev/null | cut -f1
    fi
}

newest() {   # 最終更新日。GNU findのみ。分からなければ n/a
    local r=""
    if [ "$FAST" = 1 ]; then printf 'skip'; return; fi
    if [ "$HAVE_PRINTF" = 1 ]; then
        r=$(find "$1" -type f -not -path '*/.git/*' -printf '%TY-%Tm-%Td\n' 2>/dev/null | sort | tail -n 1)
    fi
    printf '%s' "${r:-n/a}"
}

cnt() {      # $1=dir $2=name pattern : 深さ3までのファイル数
    find "$1" -maxdepth 3 -type f -name "$2" -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null \
        | wc -l | tr -d ' '
}

git_info() { # $1=repo dir
    local d=$1 br dirty ahead remote
    br=$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
    dirty=$(git -C "$d" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if git -C "$d" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
        ahead=$(git -C "$d" rev-list --count '@{u}..HEAD' 2>/dev/null || echo "?")
    else
        ahead="追跡ブランチなし"
    fi
    remote=$(git -C "$d" remote get-url origin 2>/dev/null || echo "なし")
    printf 'branch=%s / 未commit=%s / 未push=%s / origin=%s' "$br" "$dirty" "$ahead" "$remote"
}

markers() {  # $1=dir : 中身の目印
    local d=$1 m="" n
    n=$(cnt "$d" '*.ipynb');  [ "$n" != 0 ] && m="$m ipynb=$n"
    n=$(cnt "$d" '*.tex');    [ "$n" != 0 ] && m="$m tex=$n"
    n=$(cnt "$d" '*.py');     [ "$n" != 0 ] && m="$m py=$n"
    n=$(cnt "$d" '*.jl');     [ "$n" != 0 ] && m="$m jl=$n"
    n=$(cnt "$d" '*.md');     [ "$n" != 0 ] && m="$m md=$n"
    n=$(cnt "$d" '*.def');    [ "$n" != 0 ] && m="$m def=$n"
    for f in environment.yml requirements.txt pyproject.toml uv.lock pixi.lock Dockerfile; do
        [ -e "$d/$f" ] && m="$m $f"
    done
    # 移動すると壊れる仮想環境
    n=$(find "$d" -maxdepth 4 -name pyvenv.cfg 2>/dev/null | wc -l | tr -d ' ')
    [ "$n" != 0 ] && m="$m [venv=$n:移動で壊れる]"
    n=$(find "$d" -maxdepth 3 -name conda-meta -type d 2>/dev/null | wc -l | tr -d ' ')
    [ "$n" != 0 ] && m="$m [condaenv=$n:移動で壊れる]"
    printf '%s' "${m# }"
}

NESTED=$(mktemp)
trap 'rm -f "$NESTED"' EXIT

echo "# ホーム棚卸し: $ROOT （$(date +%Y-%m-%d)）"
echo
echo "## 1. ドットなしの項目"
echo
echo "| 名前 | 種類 | サイズ | 最終更新 | 中身の目印 | git |"
echo "|---|---|---|---|---|---|"
for p in *; do
    [ -e "$p" ] || [ -L "$p" ] || continue
    if [ -L "$p" ]; then
        printf '| %s | symlink→%s | - | - | - | - |\n' "$p" "$(readlink "$p")"
        continue
    fi
    size=$(size_of "$p")
    if [ -d "$p" ]; then
        mk=$(markers "$p")
        if [ -d "$p/.git" ]; then
            g=$(git_info "$p")
        else
            nrep=$(find "$p" -maxdepth 3 -name .git -type d -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
            if [ "$nrep" != 0 ]; then
                g="中にリポジトリ ${nrep}個（projects/ や src/ なら正常。それ以外なら整理の対象）"
                find "$p" -maxdepth 3 -name .git -type d -not -path '*/node_modules/*' 2>/dev/null \
                    | sed 's|/\.git$||' >> "$NESTED"
            else
                g="gitなし"
            fi
        fi
        printf '| %s/ | dir | %s | %s | %s | %s |\n' "$p" "$size" "$(newest "$p")" "${mk:--}" "$g"
    else
        printf '| %s | file | %s | %s | - | - |\n' "$p" "$size" "$(newest "$p")"
    fi
done

echo
echo "## 2. 入れ子のgitリポジトリ"
echo
if [ -s "$NESTED" ]; then
    echo "| パス | 状態 |"
    echo "|---|---|"
    sort "$NESTED" | while IFS= read -r r; do
        printf '| %s | %s |\n' "$r" "$(git_info "$r")"
    done
else
    echo "（なし）"
fi

echo
echo "## 3. ドット項目（設定・ツール管理。基本は触らない）"
echo
echo "| 名前 | サイズ |"
echo "|---|---|"
for p in .[!.]*; do
    [ -e "$p" ] || [ -L "$p" ] || continue
    printf '| %s | %s |\n' "$p" "$(size_of "$p")"
done

echo
echo "## 4. 実行中・待機中のジョブと、容量"
echo
echo "（ジョブがある間は、ディレクトリを動かさないこと。投入済みのスクリプトが古いパスを参照して失敗する）"
echo
found=0
if command -v squeue >/dev/null 2>&1; then
    found=1; echo "### Slurm"; echo '```'
    squeue -u "$(id -un)" 2>&1 | head -n 30
    echo '```'
fi
if command -v qstat >/dev/null 2>&1; then
    found=1; echo "### qstat（PBS / Torque / Grid Engine）"; echo '```'
    qstat -u "$(id -un)" 2>&1 | head -n 30
    echo '```'
fi
[ "$found" = 0 ] && echo "（squeue / qstat が見つからない。ジョブの有無は別の方法で確認すること）"
if command -v tmux >/dev/null 2>&1; then
    echo; echo "### tmux セッション"; echo '```'
    tmux ls 2>/dev/null | head -n 10 || true
    tmux ls >/dev/null 2>&1 || echo '（セッションなし）'
    echo '```'
fi
echo; echo "### 容量"; echo '```'
df -h "$ROOT" 2>&1 | head -n 5
command -v quota >/dev/null 2>&1 && quota -s 2>&1 | head -n 10
echo '```'
