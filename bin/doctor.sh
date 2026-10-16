#!/usr/bin/env bash
# doctor.sh — 研究環境の健康診断（読み取り専用。何も変更しない）
#
# 使い方:
#   bin/doctor.sh              # ホーム($HOME)を診断
#   bin/doctor.sh --home DIR   # 別のディレクトリをホームとみなして診断（テスト用）
#
# 出力: [OK] 問題なし / [注意] 直した方がよい / [要修正] 直すべき
# 終了コード: 0 = 要修正なし、1 = 要修正あり
# 各項目には「どうすれば直るか」のヒントが付く。

# shellcheck disable=SC2088  # 表示用の文字列に ~ を使う（展開させない）
set -u   # 注意: set -e は付けない（1項目が失敗しても最後まで診断を続けるため）

H=$HOME
while [ $# -gt 0 ]; do
    case $1 in
        --home) shift; H=${1:?--home にはディレクトリが必要} ;;
        -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "不明な引数: $1" >&2; exit 2 ;;
    esac
    shift
done

ng=0; warn=0; ok=0
ok_()   { echo "[OK]      $1"; ok=$((ok+1)); }
warn_() { echo "[注意]    $1"; [ -n "${2:-}" ] && echo "          → $2"; warn=$((warn+1)); }
ng_()   { echo "[要修正]  $1"; [ -n "${2:-}" ] && echo "          → $2"; ng=$((ng+1)); }
section() { echo; echo "## $1"; }

section "1. 道具"
for c in git ssh rsync; do
    if command -v "$c" >/dev/null 2>&1; then ok_ "$c がある"
    else ng_ "$c がない" "sudo apt install $c  （Macは brew install $c）"; fi
done

if command -v conda >/dev/null 2>&1; then ok_ "conda がある"
else warn_ "conda がない" "miniconda を入れる（docs/03-operate/02-python-env.md）"; fi

section "2. Git の自己紹介"
name=$(git config --global user.name 2>/dev/null || true)
mail=$(git config --global user.email 2>/dev/null || true)
[ -n "$name" ] && ok_ "user.name = $name" || ng_ "user.name が未設定" "git config --global user.name \"Your Name\""
if [ -z "$mail" ]; then
    ng_ "user.email が未設定" "GitHub の noreply アドレスを設定（例: 12345+id@users.noreply.github.com）"
elif echo "$mail" | grep -q 'noreply.github.com$'; then ok_ "user.email は noreply ($mail)"
else warn_ "user.email が noreply ではない ($mail)" "GitHub で『メールを非公開』にしていると push が GH007 で拒否される"; fi
br=$(git config --global init.defaultBranch 2>/dev/null || true)
[ "$br" = main ] && ok_ "init.defaultBranch = main" || warn_ "init.defaultBranch が main ではない (${br:-未設定})" "git config --global init.defaultBranch main"

section "3. SSH"
if ls "$H"/.ssh/id_* >/dev/null 2>&1; then
    n=0
    for k in "$H"/.ssh/id_*; do case $k in *.pub) ;; *) [ -e "$k" ] && n=$((n+1)) ;; esac; done
    if [ "$n" -gt 0 ]; then
        if [ -n "${SSH_CONNECTION:-}" ]; then
            warn_ "秘密鍵がこの（リモート）マシンにある" "秘密鍵は手元(WSL/Mac)にだけ置き、サーバーへは ssh -A（agent転送）で入る"
        else ok_ "手元に鍵がある"; fi
    else ok_ "秘密鍵なし（公開鍵のみ）"; fi
else
    if [ -n "${SSH_CONNECTION:-}" ]; then ok_ "リモートに秘密鍵なし（正しい状態）"
    else warn_ "~/.ssh に鍵がない" "ssh-keygen -t ed25519 で作り、公開鍵(.pub)だけGitHub/サーバーに登録"; fi
fi
if [ -n "${SSH_AUTH_SOCK:-}" ] && command -v ssh-add >/dev/null 2>&1; then
    ssh-add -l >/dev/null 2>&1; rc=$?
    if [ $rc -eq 0 ]; then ok_ "ssh-agent に鍵が載っている"
    elif [ $rc -eq 1 ]; then warn_ "ssh-agent は動いているが鍵が空" "手元で ssh-add（または keychain）"
    else warn_ "ssh-agent に接続できない"; fi
else warn_ "ssh-agent が動いていない (環境変数 SSH_AUTH_SOCK が未設定)" "agent=秘密鍵を一度だけ解錠して覚えておく係。無いと push/ssh のたびにパスフレーズを聞かれ、サーバーでの agent 転送(ssh -A)も効かない。手元で: sudo apt install keychain → ~/.bashrc に eval \$(keychain --eval --quiet id_ed25519) を追記（docs/02-setup 参照）"; fi

section "4. ホームの骨格"
for d in projects writing notes src archive; do
    [ -d "$H/$d" ] && ok_ "~/$d がある" || warn_ "~/$d がない" "bin/bootstrap.sh --run"
done

section "5. プロジェクト（~/projects/*）"
if [ -d "$H/projects" ]; then
    found=0
    for p in "$H"/projects/*/; do
        [ -d "$p" ] || continue
        found=1; pn=$(basename "$p")
        if [ ! -d "$p/.git" ]; then warn_ "$pn: Git管理されていない" "git init または clone"; continue; fi
        git -C "$p" remote | grep -q . && ok_ "$pn: remote あり" || warn_ "$pn: remote が無い" "GitHubにprivateリポジトリを作り git remote add origin <SSH URL>"
        url=$(git -C "$p" remote get-url origin 2>/dev/null || true)
        case $url in https://*) warn_ "$pn: remote が HTTPS ($url)" "git remote set-url origin git@github.com:<user>/<repo>.git" ;; esac
        hp=$(git -C "$p" config core.hooksPath 2>/dev/null || true)
        if [ -d "$p/tools/git-hooks" ]; then
            [ -n "$hp" ] && ok_ "$pn: pre-commit フック有効" || warn_ "$pn: フックが未有効" "git -C $p config core.hooksPath tools/git-hooks"
        fi
        if [ -n "$(git -C "$p" status --porcelain 2>/dev/null | head -1)" ]; then
            warn_ "$pn: 未コミットの変更あり" "git status で確認 → commit するか破棄するか決める"
        fi
        [ -e "$p/.gitignore" ] || warn_ "$pn: .gitignore がない" "bin/init-project.sh のテンプレートを参考に"
        if ls "$p"/notebooks/*.ipynb >/dev/null 2>&1; then
            grep -qs nbstripout "$p/.git/config" && ok_ "$pn: nbstripout 有効" \
              || warn_ "$pn: notebook があるが nbstripout が未設定" "conda install -c conda-forge nbstripout（または pip）→ nbstripout --install --attributes .gitattributes（clone ごとに必要）"
        fi
    done
    [ $found -eq 0 ] && warn_ "~/projects が空" "bin/init-project.sh ~/projects/<名前> で作成、または既存を clone"
fi

section "6. ホーム直下の散らかり（conda本体の miniconda3 等は道具置き場として許容）"
if [ -d "$H" ]; then
    loose=$(find "$H" -maxdepth 1 -mindepth 1 -not -name '.*' -not -name projects -not -name writing -not -name notes -not -name src -not -name archive -not -name miniconda3 -not -name anaconda3 -not -name miniforge3 -not -name mambaforge -printf '%f\n' 2>/dev/null | sort)
    if [ -z "$loose" ]; then ok_ "骨格以外のものはない"
    else
        c=$(echo "$loose" | wc -l)
        warn_ "骨格以外が $c 個ある" "bin/home-inventory.sh で一覧 → bin/home-organize.sh で移動（docs/05-cleanup）"
        echo "$loose" | head -8 | sed 's/^/            - /'
        [ "$c" -gt 8 ] && echo "            ...ほか $((c-8)) 個"
    fi
fi

echo
echo "== 結果: OK $ok / 注意 $warn / 要修正 $ng =="
[ $ng -eq 0 ]
