#!/usr/bin/env bash
# init-project.sh — docs/01-design の設計に沿ったプロジェクトの雛形を作る
#
# 使い方（サーバーでもローカルでも同じ）:
#   ./scripts/init-project.sh <project_dir> [server-id ...]
# 例:
#   ./scripts/init-project.sh ~/projects/my-sim server-a server-b
#
# 既存ファイルは上書きしない。
# 運用の想定（編集場所をディレクトリ単位で分担）:
#   サーバーで編集: notebooks                       （カーネルが要るもの）
#   ローカルで編集: src scripts config paper docs （実行しなくても書けるもの）
#   ローカルのみ  : results/<server>/（サーバーの runs/ の回収先）
#   サーバー側とローカル側の両方で同じ構造を作っておく

set -euo pipefail

[ $# -ge 1 ] || { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
DIR=$1; shift
SERVERS=("$@")
NAME=$(basename "$DIR")
HERE=$(cd "$(dirname "$0")/../templates/project/scripts" && pwd)

mkdir -p "$DIR"/{src,notebooks,config,scripts,docs,paper/sections,paper/figures,data,runs,results/local}
# gitは空ディレクトリを追跡しないので、Git管理側の空ディレクトリには .gitkeep を置く
# （cloneしたサーバー側にも同じ構造ができるように）
for d in src docs paper/sections paper/figures; do
    [ -e "$DIR/$d/.gitkeep" ] || : > "$DIR/$d/.gitkeep"
done

for s in ${SERVERS[@]+"${SERVERS[@]}"}; do
    mkdir -p "$DIR/results/$s"
    [ -e "$DIR/config/$s.yml" ] || cat > "$DIR/config/$s.yml" <<EOF
# ${s} 固有の設定（パス・並列数・GPU等）。コードにはハードコードしない。
server: ${s}
EOF
done
[ -e "$DIR/config/local.yml" ] || printf '# ローカル用設定\nserver: local\n' > "$DIR/config/local.yml"

write_if_absent() { [ -e "$1" ] || cat > "$1"; }

write_if_absent "$DIR/.gitignore" <<'EOF'
# 大容量・生成物（READMEだけ追跡）
/data/*
!/data/README.md
/runs/
/results/*
!/results/README.md

# Jupyter / Python
.ipynb_checkpoints/
__pycache__/
*.pyc
*.o
*.so
build/

# モデルの重み・データ配列（巨大化しやすい。ここに無くても pre-commit フックが止める）
*.h5
*.hdf5
*.npy
*.npz
*.pt
*.pth
*.ckpt
*.safetensors
*.pkl
*.zip

# OS が作るごみ
.DS_Store
Thumbs.db

# LaTeX ビルド生成物（PDFは build/ に出す）
/paper/build/
*.aux
*.bbl
*.blg
*.fls
*.fdb_latexmk
*.synctex.gz
*.out
*.toc

# ログ・一時・秘密情報
*.log
/tmp/
.env
*.pem
id_*
EOF

# 改行コードをLFに固定（Windows/WSL と Mac/Linux の混在で差分が荒れるのを防ぐ）
write_if_absent "$DIR/.gitattributes" <<'EOF'
* text=auto eol=lf
EOF

write_if_absent "$DIR/README.md" <<EOF
# ${NAME}

目的: (ここに書く)

## サーバー
$(for s in ${SERVERS[@]+"${SERVERS[@]}"}; do echo "- ${s}"; done)

## 運用
研究室の運用ルール（lab-workflow）を参照。
- notebooks/: サーバーで編集（Jupyterで対話的に） → commit/push
- src scripts config paper docs: ローカルで編集 → commit/push。試すだけなら \`scripts/sync.sh <server> code-push\`
- commit/push は変更を作った場所で。サーバー側の pull は \`git pull --rebase --autostash\`
- ローカル: \`git pull --rebase\`、\`scripts/sync.sh <server> results-pull\`（結果の保管）
- 実行ごとに \`scripts/new-run.sh <tag>\` で runs/<run_id>/ を作る
- 論文の図: \`scripts/pick-figure.sh <server> <run_id> <path>\`
EOF

write_if_absent "$DIR/data/README.md" <<'EOF'
# data/
入力データ置き場（Git管理外）。各データの出所・取得日・サイズ・ライセンスをここに記録する。
EOF

write_if_absent "$DIR/results/README.md" <<'EOF'
# results/
サーバーの runs/ から回収した成果物（Git管理外）。サーバー側では runs/ がこれに対応する。
構造: results/<server>/<run_id>/{output,logs,meta}
run_id: YYYYMMDD-HHMM_<tag>_<git short hash>[-dirty]
古いrunは results/<server>/_archive/ へ退避。
EOF

write_if_absent "$DIR/notebooks/README.md" <<'EOF'
# notebooks/
対話的な探索用。命名: NN-topic.ipynb（例: 01-explore-input.ipynb）。
重い出力・図は notebook に埋め込まず runs/<run_id>/output/ へ保存する。
安定したロジックは src/ へ移し、notebook からは import して使う。
EOF

write_if_absent "$DIR/paper/README.md" <<'EOF'
# paper/
論文・文書（編集はローカル）。
- ビルド: `cd paper && latexmk -outdir=build main.tex`
- figures/: 採用した図だけ。`scripts/pick-figure.sh` で results/ から選んでコピーする（出所が SOURCES.tsv に残る）
EOF

# テンプレート（templates/project/scripts）の補助スクリプトをコピー
for f in sync.sh new-run.sh pick-figure.sh; do
    if [ -e "$HERE/$f" ] && [ ! -e "$DIR/scripts/$f" ]; then
        cp "$HERE/$f" "$DIR/scripts/$f"; chmod +x "$DIR/scripts/$f"
    fi
done

# pre-commit フック（大きいファイル・データ形式の誤コミットを止める）を配置
HOOK_SRC="$HERE/../../git-hooks/pre-commit"
if [ -e "$HOOK_SRC" ] && [ ! -e "$DIR/tools/git-hooks/pre-commit" ]; then
    mkdir -p "$DIR/tools/git-hooks"
    cp "$HOOK_SRC" "$DIR/tools/git-hooks/pre-commit"; chmod +x "$DIR/tools/git-hooks/pre-commit"
fi

[ -d "$DIR/.git" ] || git -C "$DIR" init -q

git -C "$DIR" config core.hooksPath tools/git-hooks 2>/dev/null || true
echo "作成しました: $DIR"
if command -v tree >/dev/null; then tree -L 2 -a -I .git "$DIR"; else ls -A "$DIR"; fi
