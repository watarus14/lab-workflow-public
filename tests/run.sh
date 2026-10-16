#!/usr/bin/env bash
# tests/run.sh — 全スクリプトの自動テスト。使い方: tests/run.sh
# 一時ディレクトリだけを使い、本物のホームには触れない。
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); B=$ROOT/bin
pass=0; fail=0
t() { # 名前 コマンド...
    local n=$1; shift
    if "$@" >/dev/null 2>&1; then echo "  ok   $n"; pass=$((pass+1)); else echo "  FAIL $n"; fail=$((fail+1)); fi
}
neg() { local n=$1; shift; if "$@" >/dev/null 2>&1; then echo "  FAIL $n"; fail=$((fail+1)); else echo "  ok   $n"; pass=$((pass+1)); fi; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

echo "# 構文"
for f in "$B"/*.sh "$ROOT"/templates/project/scripts/*.sh "$ROOT"/templates/git-hooks/pre-commit; do t "bash -n $(basename "$f")" bash -n "$f"; done
if command -v shellcheck >/dev/null; then for f in "$B"/*.sh; do t "shellcheck $(basename "$f")" shellcheck -S warning "$f"; done; else echo "  skip shellcheck (未インストール)"; fi

echo "# bootstrap"
H=$TMP/home1; mkdir -p "$H"
t "ドライランは何も作らない" bash -c "'$B/bootstrap.sh' --target '$H' && [ -z \"\$(ls -A '$H')\" ]"
t "--run で5つ作る" bash -c "'$B/bootstrap.sh' --target '$H' --run && [ -d '$H/projects' ] && [ -d '$H/archive' ]"
echo mine > "$H/notes/README.md"; "$B/bootstrap.sh" --target "$H" --run >/dev/null
t "冪等・既存READMEを上書きしない" grep -q '^mine$' "$H/notes/README.md"
neg "不明な引数はエラー" "$B/bootstrap.sh" --bogus

echo "# doctor"
export HOME=$TMP/home2; mkdir -p "$HOME"; "$B/bootstrap.sh" --run >/dev/null
chmod -R a-w "$HOME"; before=$(find "$HOME" | sort | md5sum)
"$B/doctor.sh" --home "$HOME" >/dev/null 2>&1; rc=$?
chmod -R u+w "$HOME"; after=$(find "$HOME" | sort | md5sum)
t "読み取り専用（何も増減しない）" [ "$before" = "$after" ]
t "git user未設定なら要修正で終了コード1" [ "$rc" -eq 1 ]
git config --global user.name T; git config --global user.email "1+t@users.noreply.github.com"; git config --global init.defaultBranch main
"$B/doctor.sh" --home "$HOME" 2>&1 | grep -q "OK.*user.email は noreply" && { echo "  ok   noreply を認識"; pass=$((pass+1)); } || { echo "  FAIL noreply認識"; fail=$((fail+1)); }
mkdir "$HOME/messy-dir"
"$B/doctor.sh" --home "$HOME" 2>&1 | grep -q "messy-dir" && { echo "  ok   散らかりを検出"; pass=$((pass+1)); } || { echo "  FAIL 散らかり検出"; fail=$((fail+1)); }

echo "# init-project"
t "雛形が作れる" "$B/init-project.sh" "$HOME/projects/demo" srvA
t "pre-commitが配置・有効" bash -c "[ -x '$HOME/projects/demo/tools/git-hooks/pre-commit' ] && [ \"\$(git -C '$HOME/projects/demo' config core.hooksPath)\" = tools/git-hooks ]"
echo "== hook =="; P=$HOME/projects/demo
dd if=/dev/zero of="$P/src/big.bin" bs=1M count=6 2>/dev/null; git -C "$P" add -f src/big.bin
neg "6MBファイルのコミットをフックが止める" git -C "$P" commit -qm x
git -C "$P" reset -q; rm "$P/src/big.bin"; : > "$P/src/a.h5"; git -C "$P" add -f src/a.h5
neg ".h5 のコミットをフックが止める" git -C "$P" commit -qm x
git -C "$P" reset -q; rm "$P/src/a.h5"
echo hi > "$P/src/ok.py"; git -C "$P" add src/ok.py
t "通常ファイルはコミットできる" git -C "$P" commit -qm ok

echo "# qsub-run"
t "Torque雛形: #PBS と nodes=1:ppn=4" bash -c "'$B/qsub-run.sh' t1 -- echo hi | grep -q 'nodes=1:ppn=4'"
t "Torque雛形に PBS_O_WORKDIR" bash -c "'$B/qsub-run.sh' t1 -- echo hi | grep -q 'PBS_O_WORKDIR'"
t "GPU指定で gpus=1" bash -c "'$B/qsub-run.sh' --gpus 1 t1 -- echo hi | grep -q 'ppn=4:gpus=1'"
t "walltime は指定時のみ" bash -c "! '$B/qsub-run.sh' t1 -- echo hi | grep -q walltime && '$B/qsub-run.sh' --walltime 01:00:00 t1 -- echo hi | grep -q 'walltime=01:00:00'"
t "PBS Pro 書式" bash -c "'$B/qsub-run.sh' --pbspro t1 -- echo hi | grep -q 'select=1:ncpus=4'"
t "Slurm雛形に SBATCH" bash -c "'$B/qsub-run.sh' --slurm t1 -- echo hi | grep -q '#SBATCH -J t1'"
t "conda activate に --env の名前" bash -c "'$B/qsub-run.sh' --env gpudemo t1 -- echo hi | grep -q 'conda activate gpudemo'"
t "生成物が構文OK" bash -c "'$B/qsub-run.sh' t1 -- echo 'a b' > '$TMP/job.sh' && bash -n '$TMP/job.sh'"
neg "tagに大文字は不可" "$B/qsub-run.sh" Bad -- echo

echo "# render"
cp -r "$ROOT" "$TMP/repo"; rm -rf "$TMP/repo/.git"; echo 'ssh your-cpu-server as your-user (your-lab) gh:your-github-id' > "$TMP/repo/docs/_t.md"
printf 'SERVER_CPU=cpu1\nSERVER_GPU=gpu1\nSERVER_USER=taro\nGITHUB_USER=labx\nCHAT_CHANNEL=srv\nVPN=wg\nLAB_NAME=labx\n' > "$TMP/repo/lab.conf"
t "--lab で置換" bash -c "'$TMP/repo/bin/render.sh' --lab '$TMP/lab' && grep -q 'ssh cpu1 as taro (labx) gh:labx' '$TMP/lab/docs/_t.md'"
t "lab.conf 自体は出力に含めない" bash -c "[ ! -e '$TMP/lab/lab.conf' ]"
t "元のファイルは変更されない" grep -q 'your-cpu-server' "$TMP/repo/docs/_t.md"
neg "既存の非空OUTDIRは拒否" "$TMP/repo/bin/render.sh" --lab "$TMP/lab"
rm "$TMP/repo/lab.conf"
neg "lab.confが無ければ --lab は失敗" "$TMP/repo/bin/render.sh" --lab "$TMP/lab2"
rm "$TMP/repo/docs/_t.md"
t "--check が現在のリポジトリで通る" "$B/render.sh" --check
echo "mail me: someone@gm""ail.com" > "$TMP/repo/docs/_leak.md"
neg "--check が混入を検出（メール）" "$TMP/repo/bin/render.sh" --check
rm "$TMP/repo/docs/_leak.md"; printf 'SERVER_CPU=realhost\n' > "$TMP/repo/lab.conf"; echo 'ssh realhost' > "$TMP/repo/docs/_leak2.md"
neg "--check が lab.conf の実値の混入を検出" "$TMP/repo/bin/render.sh" --check

echo "# make-public-snapshot"
S=$TMP/snap
t "履歴1コミットの公開コピーを作れる" bash -c "'$B/make-public-snapshot.sh' '$S' && [ \"\$(git -C '$S' rev-list --count HEAD)\" = 1 ] && [ ! -e '$S/lab.conf' ]"
neg "空でない OUTDIR は拒否" "$B/make-public-snapshot.sh" "$S"

echo "# normalize-names"
N=$TMP/nn; mkdir -p "$N/projects/QML_Project" "$N/projects/My Data" "$N/projects/ok-name" "$N/projects/Foo_Bar" "$N/projects/foo-bar" "$N/projects/実験"
out=$(HOME=$N "$B/normalize-names.sh" 2>/dev/null)
echo "$out" | grep -q '^projects/QML_Project -> projects/qml-project$' && { echo "  ok   大文字と_を直す案"; pass=$((pass+1)); } || { echo "  FAIL 大文字と_"; fail=$((fail+1)); }
echo "$out" | grep -q '^projects/My Data -> projects/my-data$' && { echo "  ok   空白をハイフンに"; pass=$((pass+1)); } || { echo "  FAIL 空白"; fail=$((fail+1)); }
echo "$out" | grep -q '^# 衝突: projects/Foo_Bar' && { echo "  ok   衝突を検出"; pass=$((pass+1)); } || { echo "  FAIL 衝突"; fail=$((fail+1)); }
echo "$out" | grep -q '^# 要手動: projects/実験' && { echo "  ok   日本語は手動扱い"; pass=$((pass+1)); } || { echo "  FAIL 日本語"; fail=$((fail+1)); }
echo "$out" | grep -q 'ok-name' && { echo "  FAIL 正しい名前に触れた"; fail=$((fail+1)); } || { echo "  ok   正しい名前は対象外"; pass=$((pass+1)); }
t "案は home-organize のドライランで受理される" bash -c "HOME='$N' '$B/normalize-names.sh' 2>/dev/null | grep -v '^#' > '$TMP/mv.txt'; HOME='$N' '$B/home-organize.sh' '$TMP/mv.txt'"
t "案を出すだけで何も変更しない" bash -c "[ -d '$N/projects/QML_Project' ] && [ ! -e '$N/projects/qml-project' ]"

echo "# cleanup-report"
t "読み取りで動く" "$B/cleanup-report.sh" --home "$HOME"

echo; echo "結果: pass=$pass fail=$fail"; [ "$fail" -eq 0 ]
