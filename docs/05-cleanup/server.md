# サーバー側の整理

手元（WSL）の整理と同じ道具を、サーバーの中で使います。**手元への一括転送はしません**。

## なぜ「まとめて転送」しないか
- サーバーが**正本**のもの（notebook、`runs/`、サーバー生成データ）があり、手元に丸ごとコピーすると正本が二重になる
- 散らかった状態を、整理済みの手元に持ち込むことになる
- 容量・時間・quota の問題（共有ストレージの大きなデータは、動かすだけで重い）
- 必要なものは整理後に決まった道具で取り込める: コード＝`git pull`、結果＝`results-pull`、データ＝`data-pull`
- 例外: **git にも GitHub にも無く、他で再現できないもの**は、整理の前にバックアップを取る

## 手順
1. **ジョブが無いことを確認**（`qstat -u $USER` / `squeue -u $USER`）。走っている・待機中のジョブがある間は、ディレクトリを動かさない。対話ジョブや JupyterLab も止める（`qdel`）。
2. **棚卸し（読むだけ）**:
   ```bash
   # 手元から1回送る
   scp bin/home-inventory.sh bin/home-organize.sh your-cpu-server:
   # サーバーで
   ./home-inventory.sh --fast > ~/inventory.md     # --fast: 巨大ディレクトリのサイズ計算を15秒で打ち切る
   ```
3. **手元のリポジトリと照合**: 棚卸しの `origin=` が手元のリポジトリと同じなら、同じプロジェクトのサーバー側 clone。未commit・未pushは先に片付ける（`git add notebooks` のようにディレクトリを明示）。
4. **移動表を書く**（手元と同じ `moves.txt`）。サーバーの標準の置き場所:
   ```text
   ~/projects/<project>/    git clone ＋ data/ runs/
   ~/src/                   他人のリポジトリ
   ~/archive/               終わったもの（消さずに退避）
   ```
   ドライラン → 実行 → 困ったら undo。
5. **各プロジェクトを標準構造に合わせる**: `init-project.sh` は既存ファイルを上書きしない。散らかった古い結果は `runs/legacy-<YYYYMMDD>/` にまとめる。
6. **手元に必要なものだけ取り込む**: `git pull`、`scripts/sync.sh your-cpu-server results-pull -n`。

## バックアップ（整理の前、必要なものだけ）
```bash
# 手元で。-n -v で内容を確認してから。環境や巨大な生成物は除く
mkdir -p ~/archive/server-backup-$(date +%Y%m%d)
rsync -a -n -v --partial --info=progress2 -h \
  --exclude '.venv/' --exclude '__pycache__/' --exclude '.ipynb_checkpoints/' \
  your-cpu-server:important-dir/ ~/archive/server-backup-$(date +%Y%m%d)/important-dir/
```
- 対象は「git にも無く、再現もできないもの」だけ。仮想環境は**作り直せる**ので持ってこない。
- 持ってきたものは**プロジェクトの外**（`archive/`）に置く。

## サーバー特有の注意
- **共有ストレージ**: `du` や `find` を巨大ディレクトリに掛けない。棚卸しは `--fast`、空いた時間に。
- **scratch は保管場所ではない**: 結果は `results-pull` で手元に取る。
- **ホームの quota**: 空きを確認。足りなければ `data/` `runs/` を scratch への symlink に。
- **自分のホームの中だけ**を整理する（共同利用のディレクトリは他の人の作業を壊す）。
- `~/.vscode-server` `~/miniconda3` `~/.cache` などのツール管理の場所は動かさない。
