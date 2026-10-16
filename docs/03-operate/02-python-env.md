# 02 Python 環境（miniconda）

## 標準: miniconda で環境を管理する
CPU 側（your-cpu-server）でも GPU 側（your-gpu-server）でも、**Python 環境は miniconda で用意する**ことを標準にします。

### なぜ miniconda か
- **手順が同じ**: `environment.yml` から `conda env create` するだけ。サーバーごとに作法を変えなくてよい。
- **システムに依存しない**: 計算ノードに入っているソフト（版や有無が環境によって違う）に左右されず、自分のホーム配下で完結する。
- **再現性**: 必要なパッケージを `environment.yml` に固定でき、壊れても作り直せる。GPU は `pytorch-cuda` の版をノードに合わせるだけ。

### pip と conda を混ぜない
**同じ環境の中で `pip install` と `conda install` を混在させない**でください。両方が同じパッケージを別々に管理して、依存関係が壊れる原因になります。
- まず `conda install -c conda-forge <パッケージ>` を試す。
- conda に無いものだけ `pip install` する。その場合も**最後に**、一度にまとめて入れる。
- 本リポジトリの道具も conda で入れる: `conda install -c conda-forge nbstripout jupytext`

### 作成はログインノードでOK、計算はジョブで
`conda env create`（パッケージのダウンロード）はログインノードでやってよい。ただし `python train.py` のような重い実行はジョブに出す（[01 ルール](01-server-rules.md)）。

## Step 1. miniconda をインストールする（初回のみ）
ログインノード（CPU 側は your-cpu-server、GPU 側は your-gpu-server）に入り、**ホーム配下**にインストールします。**それぞれのホームが別なら、それぞれに必要**です（共有ホームなら1回でよい — 要確認）。
```bash
ssh your-cpu-server

mkdir -p ~/miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3     # -b:対話なし -u:既存を更新 -p:インストール先
rm ~/miniconda3/miniconda.sh

~/miniconda3/bin/conda init bash        # シェルに conda を通す（~/.bashrc に書き込まれる）
source ~/.bashrc                        # 今のシェルに反映（またはログインし直す）

conda config --add channels conda-forge
conda update conda
conda --version                         # conda 24.x などが出れば成功
```
`conda init bash` で `~/.bashrc` に設定が書かれ、次回ログインから `conda` が直接使えます。ログインのたびに `base` 環境へ自動で入るのが嫌なら `conda config --set auto_activate_base false`。

## Step 2. シェル設定を揃える（`.bashrc` / `.bash_profile` / `~/venv_script`）
bash は**シェルの種類によって読むファイルが違う**ため、`.bashrc` だけだと「`ssh` で入ると conda が使えるのに、ジョブでは使えない」というズレが起きます。

| ファイル | いつ読まれる | 何のため |
|---|---|---|
| `~/.bashrc` | 非ログインの対話シェル（新しい端末など） | conda 初期化の本体（`conda init bash` が書く。基本は触らない） |
| `~/.bash_profile` | ログインシェル（`ssh` で入った直後） | `.bashrc` を読み込ませる。無いと入った直後に conda が使えない |
| `~/venv_script` | JupyterLab 起動ジョブ（`qjupyterlab`）のシェル | 同じ conda 初期化を渡す。**ジョブのシェルは `.bashrc` を読まない**ため |

覚え方: **ログイン＝`.bash_profile`／対話＝`.bashrc`／qjupyterlab＝`~/venv_script`**。`.bash_profile` が `.bashrc` を読み、`~/venv_script` は `.bashrc` の conda 部分の複製、と捉えるとつながります。

```bash
# ~/.bash_profile — ログインシェルでも .bashrc を読み込む
[ -f ~/.bashrc ] && source ~/.bashrc
```
`~/venv_script` は、`~/.bashrc` にある `>>> conda initialize >>>` から `<<< conda initialize <<<` までのブロックを**そのままコピー**します（ブロック内のパスは `conda init` が自動で入れたあなたのホームのものになります）。

## Step 3. 環境を作る
プロジェクトの `environment.yml` から作ります。
```bash
conda env create -f environment.yml     # environment.yml の name: に書かれた名前で作られる
conda activate <env名>
conda env list                          # 環境の一覧
```
- GPU 版は `pytorch-cuda` の版を、ノードの GPU/ドライバに合わせる（`nvidia-smi` の `CUDA Version` を確認）。
- 環境は**プロジェクト単位**で名前を付ける（例 `my-sim`）。何でも `base` に入れない。

### 環境を「宣言」として保存する（再現性の要）
環境そのものは壊れますが、**宣言（`environment.yml`）があれば作り直せます**。環境を変えたら、必ず書き出して commit します。
```bash
conda env export --from-history > environment.yml    # 自分が入れたものだけ（移植しやすい）
git add environment.yml && git commit -m "Update environment"
```
`--from-history` は、手で入れたパッケージだけを書き出します（依存関係の細かい版まで固定したいときは付けない）。

## Step 4. ジョブの中で環境を有効化する
`conda activate` は**シェル単位**なので、バッチジョブのスクリプトでも、`qsub -I` で入った計算ノードでも、**その都度**有効化が必要です。
```bash
source "$HOME/miniconda3/etc/profile.d/conda.sh" && conda activate <env名>
```
毎回2行書く代わりに、小さなスクリプトにまとめて `source` するのが楽です。
```bash
# ~/activate_env.sh
CONDA_HOME="$HOME/miniconda3"
ENV_NAME="my-sim"
source "$CONDA_HOME/etc/profile.d/conda.sh"
conda activate "$ENV_NAME"
```
```bash
# ジョブスクリプト内
source ~/activate_env.sh
python src/main.py
```
`bin/qsub-run.sh --env <env名>` が作るジョブ雛形は、この2行を最初から含みます。

## チェックリスト
- [ ] `conda --version` が出る
- [ ] ログイン直後（新しい `ssh`）でも `conda` が使える
- [ ] プロジェクトの `environment.yml` から環境を作れた
- [ ] 同じ環境で pip と conda を混ぜていない
- [ ] 環境を変えたら `environment.yml` を commit した
