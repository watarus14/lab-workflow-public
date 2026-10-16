# Level 3 — 回す（実行を記録として残す）

## ゴールの状態
- 計算は「実行ごとに `run_id` のついた箱」に出力が入る。あとで「どのコード・設定で出た結果か」を辿れる。
- ジョブはジョブスケジューラ（PBS/Torque など）に投入し、ログがファイルに残る。
- 論文の図には出所の記録が付く。

## なぜ（原則）
**再現できる記録を残す。** 結果だけがあっても、どの版のコードか分からなければ再現も検証もできない。実行のたびに、コードの版(git hash)・未コミットの差分・設定・日時を一緒に保存する。

## run_id の意味
`YYYYMMDD-HHMM_<tag>_<git短縮hash>[-dirty]` 例: `20261016-1530_baseline_a1b2c3d`
- `tag`: 小文字英数字とハイフン（何の実験か）
- `-dirty`: 未コミットの変更があった印。再現には `meta/uncommitted.diff` も必要

箱の中身: `runs/<run_id>/{output, logs, meta}`。`meta/` に git hash・status・差分・環境が自動で入る。

## 手を動かす
### 1. 対話的に試す（計算ノードを確保する）
**ログインノードで `python` を直接実行してはいけません**（[運用ルール](../03-operate/01-server-rules.md)）。試すときは対話ジョブで計算ノードに入ります。
```bash
ssh your-cpu-server
qsub -I -l nodes=1:ppn=1 -l walltime=00:30:00     # 計算ノードのシェルに切り替わる
cd ~/projects/<project>
source ~/activate_env.sh                          # conda 環境を有効化（要・毎回）
RUN_ID=$(scripts/new-run.sh test-small)
echo $RUN_ID
python src/main.py --out runs/$RUN_ID/output 2>&1 | tee runs/$RUN_ID/logs/stdout.log
exit                                              # ノードを必ず開放する
```
### 2. ジョブとして投入する
雛形を作る道具がある（投入はしない）:
```bash
bin/qsub-run.sh --cores 4 --env <conda環境名> vqe-test -- python src/main.py --seed 1 > job-vqe-test.sh
less job-vqe-test.sh      # 資源量（ppn, gpus, walltime）と環境名を確認・編集
qsub job-vqe-test.sh      # 投入。状況は qstat -u "$USER"
```
- GPU は `--gpus 1`。書式は計算機ごとに違うので、研究室の既存のジョブスクリプトと見比べる。
- PBS では `#PBS` で始まる行だけが有効。`#$` は別方式（Grid Engine）の書式で**無視される**。
- 対応表: `qsub/qstat/qdel` ⇄ `sbatch/squeue/scancel`、`$PBS_O_WORKDIR` ⇄ `$SLURM_SUBMIT_DIR`。`--slurm` で Slurm 版。
- ジョブの詳細（対話ジョブ、GPU、状態確認）は [03 ジョブスケジューラ](../03-operate/03-pbs-jobs.md)。

### 3. 結果を手元に回収する
```bash
# 手元
scripts/sync.sh your-cpu-server results-pull -n
scripts/sync.sh your-cpu-server results-pull          # results/your-cpu-server/<run_id>/ に入る
```
### 4. 論文に使う図を選ぶ
```bash
scripts/pick-figure.sh your-cpu-server <run_id> fig/loss.pdf fig-loss.pdf
# paper/figures/fig-loss.pdf と、出所を記した SOURCES.tsv ができる
```

## よくある失敗
| 症状 | 対処 |
|---|---|
| ジョブが動かず資源指定が効かない | `#PBS` を使っているか確認（`#$` は無効）。Torque は `nodes=1:ppn=4`、PBS Pro は `select=1:ncpus=4` と書式が違う |
| ログインノードで python を動かしてしまった | すぐ `Ctrl+C`。以後は `qsub -I`（[運用ルール](../03-operate/01-server-rules.md)） |
| run_id に `-dirty` が付く | commit してから回す。やむを得ない時は meta の差分で再現 |
| 結果が上書きされた | 出力は必ず `runs/<run_id>/output/` に（固定の場所に書かない） |
| 巨大な出力で commit が止まる | 正常（フックの保護）。データ・結果は Git に入れない |
| notebook で重い図を出して肥大 | 出力は `runs/` に保存。notebook は nbstripout で出力を除く |

## チェックリスト
- [ ] 実行ごとに `new-run.sh` で箱を作った
- [ ] `meta/git-hash.txt` から、使ったコードの版が分かる
- [ ] 結果を `results-pull` で手元にも保管した
- [ ] 論文の図が `SOURCES.tsv` で出所を辿れる

次: [Level 4 — 保つ](level4-maintain.md)
