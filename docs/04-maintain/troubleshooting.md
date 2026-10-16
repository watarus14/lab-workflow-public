# つまずき集（実際に踏んだもの）

整理作業で実際に出た症状と、効いた対処です。

| 症状 | 原因 | 対処 |
|---|---|---|
| `ssh -A` で入ったのに `ssh-add -l` が `communication with agent failed`。GitHub へ繋ぐと、サーバー自身の鍵のパスフレーズを聞かれる | `ControlMaster` で**古い接続を使い回し**、死んだ agent を渡している | `ssh -A -o ControlMaster=no -o ControlPath=none <host>` で入り直す。恒久的には `ssh -O exit <host>` と、config で `ControlMaster no` |
| push で `Password for 'https://…'` と聞かれる | remote が HTTPS。SSH 鍵は使われない | `git remote set-url origin git@github.com:USER/REPO.git` |
| `GH007: Your push would publish a private email address` | commit の作者メールが非公開設定のアドレス | 全拠点で noreply を設定。未pushの commit が複数なら `git reset --soft origin/main` → 再commit（`--amend` は最後の1つしか直せない） |
| `git branch -M main` が `refname refs/heads/master not found` | 最初の commit 前は枝が存在しない | `git init -b main`（または `git symbolic-ref HEAD refs/heads/main`） |
| 重み（`.h5` 等）の大物が commit に入った | `git add` の範囲が広い、`.gitignore` に無い | pre-commit フック。未push なら `git reset --soft HEAD~1` で取り消し |
| `git rm --cached a b` が全部失敗する | 1つでも存在しないパスがあると全体が中止 | 先に `git ls-files \| grep …` で実在を確認 |
| `Repository not found`（clone） | GitHub にまだ作っていない／名前違い／push前 | 作る → push → clone の順 |
| ipynb の出力で履歴が太る | 出力が埋め込まれている | nbstripout。**clone ごとに** `nbstripout --install --attributes .gitattributes` |
| 手元・サーバー・GitHub でリポジトリ名が食い違う | 途中で名前を変えた | 3か所をそろえる（`sync.sh` はディレクトリ名からサーバーのパスを決める）。GitHub は Settings で改名すれば旧URLは転送される |
| 他人のリポジトリに push できない | 書き込み権限が無い | commit しない。変更は `git diff > x.patch`。公開してよければ fork |
| 同じデータが何GBも重複している | 試行錯誤で複数フォルダに展開 | `cp -al`（ハードリンク）で実体を共有。消す前に `diff -rq` で中身まで確認 |
| コードが `../data-x/…` のような相対パスや `~/foo/…` の絶対パスで読む | データの置き場所を決め打ち | 前者は `src/data-x -> ../data/data-x` の symlink。後者は設定に出して直す |
| ジョブ用スクリプトのオプションが無視される | スケジューラの書式違い（`#PBS` は PBS、`#$` は Grid Engine、`#SBATCH` は Slurm） | `qsub` の種類を確認し、その書式で |
| 移動スクリプトが見つからない | `bin/` の下にある | `bin/home-organize.sh`。**ジョブが走っていないこと（`qstat`/`squeue` が空）を先に確認** |
| rsync の予行（`-n`）で何も表示されない | `-v` が無い | `-n -v`。`sync.sh` は自動で付ける |
| rsync で `change_dir ... failed` | サーバー側パスが違う | `REMOTE_ROOT` を確認（既定は `~/projects/<名前>`） |

## 整理作業の進め方（実績のある順）
1. 棚卸し（読むだけ）
2. 新しい構成を**横に作る**（元は触らない）。データは `cp -al`、コードは `cp -a`
3. git 化（`.gitignore` → ディレクトリ指定で `add` → サイズ確認 → commit → push）
4. 別の拠点で clone して同期を確認
5. 元のディレクトリは `archive/` へ**移動**（削除はしない）。重複データの削除は、検証が済んでから最後に
