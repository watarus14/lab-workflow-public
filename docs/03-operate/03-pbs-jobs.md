# 03 ジョブスケジューラ（PBS/Torque）

> 前提: [01 サーバー運用ルール](01-server-rules.md)（計算は必ずジョブで）と [02 Python環境](02-python-env.md)。
> ここでは **PBS（Torque）** を例に説明します。他のスケジューラ（PBS Pro・Slurm など）との対応は §9。

## 1. ジョブスケジューラとは
研究室の計算ノードはみんなで共有する資源です。各自が好き勝手に使うと、同じ CPU コアや GPU を複数人が奪い合い、どちらも遅くなる／落ちます。これを防ぐ「**受付係**」がジョブスケジューラで、仕事は2つです。
1. **受付（順番待ち）**: 「この計算をやりたい」という依頼（＝**ジョブ**）を受け取り、待ち行列に並べる。
2. **割り当て**: 空いた計算ノードを探し、「あなたの計算はこのノードのこのコア／GPUでどうぞ」と割り当てる。

利用者は計算ノードを直接触らず、「こういう資源で、この計算をしたい」とお願いするだけ。これが `qsub`（ジョブを**投げる**）です。

> 🍱 食堂の整理券と同じです。空席（計算ノード）に勝手に座らず、整理券（ジョブ）を取って順番に案内してもらう。勝手に座る＝ログインノードや直接 ssh で回す、であり、それが禁止される理由です。

## 2. 最初に覚える3コマンド
| コマンド | 由来 | 一言で |
|---|---|---|
| `qsub` | queue submit | ジョブを待ち行列に入れる（投入） |
| `qstat` | queue status | 行列とジョブの状態を見る |
| `qdel` | queue delete | ジョブを消す（取り消し） |

### 用語
| 用語 | 意味 |
|---|---|
| ジョブ (job) | スケジューラに投げる「計算の依頼」1件 |
| ジョブスクリプト | 「どんな資源で・何を実行するか」を書いた `.sh`。`qsub` で投入する |
| JobID | 投入時に振られる受付番号（例 `12345.サーバー名`）。`qstat` / `qdel` で使う |
| ノード (node) | 1台の計算機 |
| ppn | 1ノードで使う CPU コア数（processors per node） |
| walltime | 実時間での最大実行時間。超えると強制終了（短すぎ＝途中で切れる／長すぎ＝資源を無駄に占有） |
| キュー (queue) | ジョブの待ち行列。用途別に複数ある場合もある |
| バッチジョブ | スクリプトを投げて放っておく実行（基本形） |
| 対話ジョブ | ノードを確保して、その場のシェルで対話的に作業する実行（`qsub -I`） |

### ジョブの一生
```text
 qsub ──▶  待ち行列 (Q) ──▶  実行 (R) ──▶  完了 (C)
 投入       順番待ち          計算中        結果がファイルに残る
              ▲
              └─ qstat で今どの状態かを確認 ／ qdel で取り消し
```
`qstat -u "$USER"` の `S`（State）列に Q / R / C が出ます。完了すると標準出力・エラーがファイル（例 `myjob.o<JobID>`）に残ります。

## 3. バッチジョブ（基本）
`qsub script.sh` で投げて放置します。**投入後は `ssh` を切断しても、PCを閉じても、ジョブは計算ノードで走り続けます**（あなたの ssh セッションとは独立）。結果は出力ファイルに残るので、後でログインして回収すればよい。

### ジョブスクリプトの基本形
```bash
#!/bin/bash
#PBS -N myjob                  # ジョブ名
#PBS -l nodes=1:ppn=4          # ノード数:1ノードあたりコア数
#PBS -j oe                     # 標準出力と標準エラーを1ファイルにまとめる

cd "$PBS_O_WORKDIR"            # qsub したディレクトリへ移動
source ~/activate_env.sh       # conda 環境を有効化（02 参照）
export MPLBACKEND=Agg          # 計算ノードは画面なし → matplotlib は Agg に固定

python src/main.py             # 本処理
```
- `#PBS` で始まる行が資源の宣言。**`#$` で始まる行は別方式（Grid Engine）の書式で、PBS では無視されます。**
- 複数コアを使うなら `ppn` を増やし、プログラム側も並列化（OpenMP/MPI/プロセス並列）すること。増やしただけでは速くなりません。
- 雛形は `bin/qsub-run.sh` が作れます:
  ```bash
  bin/qsub-run.sh --cores 4 --env my-sim vqe-test -- python src/main.py > job-vqe-test.sh
  ```

### 投入・確認・取消
```bash
qsub  job-vqe-test.sh          # 投入（JobID が返る）
qstat -u "$USER"               # 自分のジョブ一覧
qstat -n <JobID>               # そのジョブがどのノードで走っているか
qstat -f <JobID>               # ジョブの詳細（資源・状態）
qdel  <JobID>                  # 取り消し
```
```text
$ qsub job-vqe-test.sh
12345.server
$ qstat -u "$USER"
server:
                                                            Req'd  Req'd   Elap
Job ID         Username Queue   Jobname     SessID NDS TSK Memory Time  S Time
-------------- -------- ------- ----------- ------ --- --- ------ ----- - -----
12345.server   user     batch   vqe-test     18452   1   4    --  00:30 R 00:00
```
`S` 列: Q=順番待ち、R=実行中、終わると一覧から消える。表示は Torque の版で多少変わります。

### 実行記録（run_id）との組み合わせ
ジョブスクリプトの中で `scripts/new-run.sh <tag>` を呼び、出力を `runs/<run_id>/` に保存すれば、ジョブの結果もコードの版に結びつきます（[Level 3](../02-setup/level3-run.md)）。

## 4. 対話ジョブ（試行錯誤・デバッグ）
`qsub -I` でノードを1つ確保し、その上のシェルで手で実行します。「ちょっと試したい」「デバッグしたい」ときに、**ログインノードで回す代わりに**使います。
```bash
qsub -I -l nodes=1:ppn=4 -l walltime=01:00:00
# → プロンプトが計算ノードに切り替わる。python などを実行してよい。exit で開放。
```
- バッチと逆に、**シェルを閉じる／`exit` するとジョブも終わる**。切れずに作業を続けたいなら `tmux`（[05 鍵と接続](../01-design/05-keys-and-sessions.md)）を併用する。
- 要点: バッチは「投げたら放置でOK」。対話ジョブ・`qjupyterlab` は「接続を保つ／使い終わりに開放（`exit`・`qdel`）」が必要。

> **❓ `qstat` の `Time Use` が増えないのはなぜ？** その列は **CPU時間**で、経過時間ではありません。対話ジョブでプロンプトに座っているだけだと CPU をほぼ使わないので `00:00:00` のままです。経過時間は `qstat -a` の `Elap Time` や `qstat -f <JobID>` の `resources_used.walltime`。
> **⚠ ただし `Time Use` が 0 でも、確保したノードは占有したまま**です（`exit` か walltime 切れまで開放されない）。使い終わったら必ず `exit` / `qdel`。

## 5. ノード・キューの状況を見る
```bash
pbsnodes -a                    # 全ノードの状態（空き・使用中）
pbsnodes -l                    # 使えない（down / offline）ノード一覧
qstat -q                       # キュー一覧と空き状況
```
`pbsnodes -a` で各ノードに見るのは3つ:
```text
node01
     state = free          ← free なら割当可（job-exclusive / offline / down は不可）
     np = 24               ← そのノードの総コア数
     jobs = 0/120.server   ← 使用中コアの一覧（無い＝全コア空き。np に近い＝ほぼ満杯）
```
空きノード名だけを手早く知る:
```bash
pbsnodes -a | awk '/^[^ \t]/{node=$1} /state = free/{print node}'
```

### ノードを名指しする（必要なときだけ）
通常は `nodes=1:ppn=1` のように台数とコア数だけを要求し、どのノードかはスケジューラに任せます。次のときだけ名指しします: ベンチマークを同じ CPU に揃えたい／1台に全コアをまとめたい／調子の悪いノードを避けたい。
```bash
#PBS -l nodes=node01:ppn=4     # ★node01 を名指しで4コア要求
```
確認は `qstat -n <JobID>`。**名指ししても「割り込み」ではありません。** 指定ノードが埋まっていれば空くまで Q のまま待ちます。スケジューラを飛ばして直接 ssh で入るのは禁止です。

## 6. GPU（your-gpu-server 側）— 対話とバッチの使い分け
|  | JupyterLab（対話） | バッチジョブ |
|---|---|---|
| 向く用途 | 試行錯誤・デバッグ・可視化 | 長時間の学習・大量実験・回して放置 |
| GPU の解放 | **手動**（Notebook を止める or `qdel` するまで占有） | 処理が終われば**自動** |
| PC との接続 | ssh トンネルを張り続ける必要あり | 投入後は切断してOK |
| 結果の受け取り | Notebook 上ですぐ確認 | 出力ファイル・保存物を後で回収 |

**試すときは JupyterLab、本番の学習はバッチ**と使い分けると、GPU を無駄に占有しません。

### 6-1. JupyterLab で対話的に使う（`qjupyterlab`）
GPU を確保した JupyterLab をジョブとして起動し、その notebook 上で計算します（研究室が用意したスクリプト）。**Notebook を開いている間ずっと GPU を占有する**点に注意。
```bash
ssh your-gpu-server
# GPU を1枚確保して JupyterLab をジョブ起動（資源は qsub のオプションで指定）
qsub -l nodes=1:gpus=1 -F "--source ~/venv_script" /opt/scripts/qjupyterlab
#        └ ノード:GPU枚数 ┘   └ conda を使える状態にする ┘ └ スクリプト（フルパス）
```
- GPU 2枚なら `gpus=2`。CPU コアを増やすなら `-l nodes=1:ppn=4:gpus=1`。
- `~/venv_script` は [02 Python環境](02-python-env.md) Step 2 で用意したもの。環境（env）は Notebook の**カーネル選択**で選ぶ。

起動後の接続（接続方法は `qjl.out`、トークンは `qjl.log` に出力される）:
```bash
qstat -u "$USER"               # 1) ジョブが R（実行中）か確認
cat qjl.out                    # 2) ssh トンネルのコマンドと URL が書かれている
#   例: ssh -L 8888:node01:8888 user@server
#       Then open http://localhost:8888/
```
3. **自分のPC**（VPN接続中）の**新しいターミナル**で、`qjl.out` に書かれた `ssh -L …` をそのまま実行してトンネルを張る。
4. ブラウザで `http://localhost:<port>/?token=…` を開く（トークンは `cat qjl.log`）。

> **⚠ 最重要**: JupyterLab は**計算ノード**で動いています。`ssh` でログインノードに入るだけ、またはブラウザに URL を貼るだけでは届きません。**`qjl.out` の `ssh -L …` を自分のPCで実行**して、そのトンネルを張ったまま開きます（トンネル用の ssh を閉じると接続も切れます）。

トンネルの形（左の番号＝PC側のポート、右＝ `qjl.out` の値そのまま）:
```bash
ssh -L 41555:node01:41555 user@server       # 形1: そのまま
ssh -L 41556:node01:41555 your-gpu-server    # 形2: ssh config の別名を使い、PC側ポートをずらす → ブラウザは localhost:41556
```
- `Could not resolve hostname`: PC が名前を解決できない → `~/.ssh/config` に `Host` / `HostName` / `User` を書く（[05 鍵と接続](../01-design/05-keys-and-sessions.md) §7）。学外からは your-vpn 接続中であること。
- 「ログインはできるのにブラウザで開かない」: そのポートを別のトンネルが使用中（1ポートにつき1本）。古いトンネルを閉じるか、PC側ポートをずらす。`ssh -o ExitOnForwardFailure=yes -L …` を付けると衝突時に即エラーで気づける。

**使い終わったら必ず開放**:
```bash
qstat -u "$USER"               # JobID を確認
qdel <JobID>                   # 終了
```
GPU は台数が限られた共有資源です。放置したトンネルにも注意。

### 6-2. GPU をバッチで回す（回して放置）
```bash
#!/bin/bash
#PBS -N gpu_train
#PBS -l nodes=1:gpus=1       # GPU を1枚要求（gpus= の書式は環境依存・要確認）
#PBS -j oe

cd "$PBS_O_WORKDIR"
source ~/activate_env.sh               # conda 環境（GPU 用）
echo "PBS_GPUFILE = $PBS_GPUFILE"; cat "$PBS_GPUFILE"    # 割り当てられた GPU を記録
nvidia-smi

python src/train.py                    # 本処理（終われば GPU は自動で解放される）
```
投入・確認・結果回収は CPU のバッチと同じ（`qsub` / `qstat` / `cat gpu_train.o<JobID>`）。処理が終わればジョブが自動終了して GPU が解放されるので、占有しっぱなしになりません。

> Torque は割り当てた GPU を `$PBS_GPUFILE`（一覧ファイル）で渡し、多くの設定では `$CUDA_VISIBLE_DEVICES` も自動セットされます。自動設定されない環境では `$PBS_GPUFILE` の中身から自分で組み立てます（**要確認**）。
> 研究室の運用として、GPU のバッチでは `walltime` を設定しない方針の場合があります（終われば自動解放されるため）。迷ったらサーバー係に確認。

## 7. GPU の状態確認
```bash
nvidia-smi                     # GPU 使用率・メモリ・使っているプロセス
watch -n 1 nvidia-smi          # 1秒ごとに更新（Ctrl-C で終了）
nvidia-smi -L                  # 搭載 GPU の一覧
export CUDA_VISIBLE_DEVICES=0  # 使う GPU を限定（例: 0番だけ）
python -c "import torch; print(torch.cuda.is_available(), torch.cuda.device_count())"
```
```text
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
|   0  NVIDIA GeForce RTX 3090  | 00000000:1A:00.0 Off |                  N/A |
| 41%   62C    P2   210W / 350W |   3124MiB / 24576MiB |     97%      Default |
```
- `GPU-Util`: その瞬間の使用率。学習中は80〜100%近く、待ちなら0%。
- `Memory-Usage`: 使用中／総メモリ。学習が載るかの目安。
- `Processes`: どのPIDがGPUを掴んでいるか。空けたいのに使用中なら、自分のジョブか確認。

## 8. プロセス・負荷の確認（`top`）
自分の計算が実際にCPUを使えているか、メモリが足りているかを見ます。
- 対話ジョブの中（`qsub -I` で確保した計算ノード上）で、自分の計算の様子を見る。
- バッチジョブの資源使用は `qstat -f <JobID>` の `resources_used.*`（cput / mem / walltime）。
```bash
top                              # q で終了
```
- `load average`: 直近 1/5/15 分の「実行中＋実行待ち」プロセス数の平均。コア数を継続的に大きく超えれば過負荷。
- `%Cpu(s)`: `us`=ユーザ計算、`sy`=システム、`id`=アイドル、`wa`=I/O待ち。
- `%CPU`: 100% = 1コア、800% ≒ 8コア使用（並列が効いているかの確認）。
- キー: `1`=コアごとに表示、`P`=CPU順、`M`=メモリ順、`u`→ユーザ名=自分だけ、`q`=終了。GPU の使用状況は `top` では見えない → `nvidia-smi`。

## 9. 他のスケジューラとの対応
| やりたいこと | PBS/Torque | PBS Pro | Slurm |
|---|---|---|---|
| 投入 | `qsub job.sh` | `qsub job.sh` | `sbatch job.sh` |
| 状況 | `qstat -u $USER` | `qstat -u $USER` | `squeue -u $USER` |
| 取消 | `qdel ID` | `qdel ID` | `scancel ID` |
| 対話 | `qsub -I` | `qsub -I` | `srun --pty bash` / `salloc` |
| 資源（ジョブスクリプト内） | `#PBS -l nodes=1:ppn=4` | `#PBS -l select=1:ncpus=4` | `#SBATCH -c 4` |
| 提出ディレクトリ | `$PBS_O_WORKDIR` | `$PBS_O_WORKDIR` | `$SLURM_SUBMIT_DIR` |
