#!/usr/bin/env bash
# sync.sh — ローカルとサーバー間の「データ・結果」転送（＋commit前の .py 試行用 code-push）。コードの正式な受け渡しは git
#
# 使い方:
#   ./scripts/sync.sh <server> <action> [-n] [-r <run_id>] [-x <pattern>]...
#
# action:
#   code-push     ローカルの src/ scripts/ config/ → サーバー        （commit前の試行用。原則は git push → サーバーで git pull）
#                 未追跡の新規ファイルも送る（.gitignore対象は除く）。サーバー側の削除は反映しない。
#   results-pull  サーバーの runs/ → ローカルの results/<server>/   （結果の保管。主用途）
#   data-pull     サーバーの data/ → ローカルの data/               （入力データのバックアップ）
#   data-push     ローカルの data/ → サーバーの data/               （ローカル発の入力データを送る時）
#   status        サーバー上の run 一覧（新しい順に20件）
#
# オプション:
#   -n, --dry-run     実際には転送せず内容だけ表示（毎回まず付ける）
#   -r, --run ID      results-pull で特定の run_id だけ回収
#   -x, --exclude P   除外パターン（複数可）例: -x 'checkpoints/' -x '*.npy'
#
# 環境変数:
#   REMOTE_ROOT  サーバー側のプロジェクトパス（既定: projects/<project>、ホームからの相対）
#
# 前提: ~/.ssh/config に <server> の Host 定義があること。
#       project = このGitルートのディレクトリ名。--delete は使わない（消さない）。

set -euo pipefail

usage() { sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

[ $# -ge 2 ] || usage
SERVER=$1; ACTION=$2; shift 2

DRY=()
EXCL=()
RUN_ID=""
while [ $# -gt 0 ]; do
    case $1 in
        -n|--dry-run) DRY=(-n -v --stats) ;;   # -v: 転送予定のファイル名を一覧表示（これが無いと予行で何も見えない）
        -r|--run)     [ $# -ge 2 ] || usage; RUN_ID=$2; shift ;;
        -x|--exclude) [ $# -ge 2 ] || usage; EXCL+=(--exclude "$2"); shift ;;
        *)            usage ;;
    esac
    shift
done

ROOT=$(git rev-parse --show-toplevel)
PROJECT=$(basename "$ROOT")
REMOTE_ROOT=${REMOTE_ROOT:-"projects/${PROJECT}"}
RSYNC=(rsync -a --partial --info=progress2 -h ${DRY[@]+"${DRY[@]}"} ${EXCL[@]+"${EXCL[@]}"})

is_dry() { [ ${#DRY[@]} -gt 0 ]; }

# rsync 3.1 以上が必要（--info=progress2 / --files-from / --from0 を使うため）。
# macOS標準のrsyncは古い(2.6.9)か openrsync(15.4以降) なので brew install rsync。
require_rsync() {
    local ver
    ver=$(rsync --version 2>/dev/null | head -n 1 || true)
    if ! printf '%s\n' "$ver" | grep -Eq 'version (3\.[1-9]|[4-9]\.)'; then
        echo "rsync 3.1 以上が必要です（検出: ${ver:-なし}）。macOS: brew install rsync して PATH を確認（PLATFORM_MACOS.md）" >&2
        exit 1
    fi
}

echo "[sync] server=${SERVER} remote=~/${REMOTE_ROOT} action=${ACTION} dry=$(is_dry && echo yes || echo no)"

case $ACTION in
    code-push)
        # ローカル担当ディレクトリ（src scripts config）だけを送る。notebooks/ はサーバー担当なので対象外。
        echo "[warn] 未コミットのコードを送ります。サーバーのrunは -dirty になり、差分は meta/uncommitted.diff に残ります。"
        echo "[warn] 後でcommit/push したら、サーバーでは 'git pull --rebase --autostash' で受け取ること。"
        require_rsync
        is_dry || ssh "$SERVER" "mkdir -p '${REMOTE_ROOT}'"
        (cd "$ROOT" && git ls-files -z --cached --others --exclude-standard -- src scripts config \
            | "${RSYNC[@]}" --from0 --files-from=- ./ "${SERVER}:${REMOTE_ROOT}/")
        ;;
    results-pull)
        require_rsync
        if [ -n "$RUN_ID" ]; then
            src="${SERVER}:${REMOTE_ROOT}/runs/${RUN_ID}/"
            dest="$ROOT/results/${SERVER}/${RUN_ID}/"
        else
            src="${SERVER}:${REMOTE_ROOT}/runs/"
            dest="$ROOT/results/${SERVER}/"
        fi
        mkdir -p "$dest"
        "${RSYNC[@]}" "$src" "$dest"
        ;;
    data-pull)
        require_rsync
        mkdir -p "$ROOT/data"
        "${RSYNC[@]}" "${SERVER}:${REMOTE_ROOT}/data/" "$ROOT/data/"
        ;;
    data-push)
        require_rsync
        [ -d "$ROOT/data" ] || { echo "data/ がありません" >&2; exit 1; }
        is_dry || ssh "$SERVER" "mkdir -p '${REMOTE_ROOT}/data'"
        "${RSYNC[@]}" "$ROOT/data/" "${SERVER}:${REMOTE_ROOT}/data/"
        ;;
    status)
        ssh "$SERVER" "ls -1r '${REMOTE_ROOT}/runs' 2>/dev/null | head -n 20 || true"
        ;;
    *)
        usage
        ;;
esac
