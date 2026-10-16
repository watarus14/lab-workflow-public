# 04 運ぶ道具（git と rsync の使い分け）

## 使い分けの基準
| | git | rsync |
|---|---|---|
| 得意 | 小さな**テキスト**の変更履歴 | 大きなファイルの**コピー・同期** |
| 履歴 | 全ての版を残す | 残さない（今の状態を揃えるだけ） |
| 対象 | コード、notebook、設定、文章 | データ、計算結果、ログ |

## 手元とサーバーの流れ
```text
コード:   手元で編集 → git commit → git push → サーバーで git pull --rebase --autostash
notebook: サーバーで編集 → git commit → git push → 手元で git pull --rebase
結果:     サーバーの runs/ → (rsync) → 手元の results/<server>/
```
- commit/push は**変更を作った場所**で行う。
- `git add` は `git add src scripts config` のように**ディレクトリを明示**する（`git add -A` は意図しないものまで入る）。
- push の前に必ず `git pull --rebase`（図解は [03 Git](03-git.md)）。

### commit 前に手元のコードをサーバーで試したいとき
`scripts/sync.sh <server> code-push -n` で `src/ scripts/ config/` だけ送る（サーバー側の削除は反映しない）。このときサーバー側の run は `-dirty` になり、送った差分は `meta/uncommitted.diff` に残る。

## rsync 早見表
```bash
rsync -a --partial --info=progress2 -h SRC/ DEST/
```
| オプション | 意味 |
|---|---|
| `-a` | アーカイブ。権限・時刻・リンクを保ち、ディレクトリを再帰的に |
| **`-n`** | **ドライラン（予行）。何も転送しない。毎回まず付ける** |
| **`-v`** | **転送する（予行なら「する予定の」）ファイル名を一覧表示。`-n` と必ず併用する。無いと予行で何も見えない** |
| `--stats` | 転送件数・サイズの統計を最後に表示 |
| `--partial` | 中断しても途中のファイルを残し、再開できる |
| `--info=progress2` | 全体の進捗を1行で表示 |
| `-h` | サイズを `3.2G` のように読みやすく |
| `-z` | 圧縮。遅い回線・テキスト中心のときだけ（圧縮済みデータでは CPU の無駄） |
| `--exclude=PAT` | 除外（例 `--exclude='*.npy'`） |
| `--delete` | **送信元に無いファイルを送信先から消す。原則使わない** |

`scripts/sync.sh ... -n` は `-n -v --stats` を自動で付けます。

### 最重要: 末尾のスラッシュ
```text
rsync -a src/ dest/   # src の「中身」を dest の中へ
rsync -a src  dest/   # src ディレクトリ「自体」を dest/src として
```
送信元の末尾に `/` を付けると決めれば事故りません。

### 予行の読み方
```bash
rsync -a -n -v --stats server-a:projects/p/runs/ results/server-a/
```
- 一覧に出た名前が「これから送られるもの」。想定外の巨大ファイルがないか確認する。
- 最後の `Total transferred file size` で総量を見る。
- 納得したら `-n` と `-v` を外して（または `-n` だけ外して）本番。

## 容量の上限（quota）と作業領域（scratch）— 該当する環境だけ読めばよい節
> **必須ではありません。** 共有の計算機サーバーには「ホームに使える量の上限がある」「大容量の作業領域が別にある」ことが多く、その場合に必要になる話です。**まず自分の環境がそうかを調べ**（下の「1. 調べる」）、該当しなければ読み飛ばして構いません。

### 何のための仕組みか
共有サーバーでは、誰かが大量のデータを置くと全員のディスクが埋まります。そこで管理者は次のように領域を分けます。

| 用語 | 意味 | 特徴 |
|---|---|---|
| **quota（クォータ）** | ユーザー（またはグループ）ごとの**使用量の上限** | 超えると新しい書き込みができなくなる（ジョブが途中で失敗する、`git` や `ssh` が不調になる等）。普通はホーム（`~`）に掛かる |
| **scratch（スクラッチ）** | 一時作業用の**大容量領域**（`/scratch` `/work` `/data` などの名前が多い） | 容量は大きいが、**一定期間（例: 30日）触らないと自動削除**されることがある。バックアップも無いことが多い |
| 長期保存領域 | 研究室や学科が用意する保管用のストレージ | 容量は中くらい、消えない。名前と場所は管理者に聞く |

```text
ホーム ~       : 小さい(quota あり)・消えない   → コード、設定、環境、小さな結果
scratch       : 大きい・消える可能性あり       → 巨大な入力データ、実行中の大きな出力
長期保存領域   : 中くらい・消えない             → 回収した結果、最終データ
```
**結論**: 大きいものは scratch で扱い、**消えて困るものは必ず別に保管**する。この運用では、結果を手元へ `results-pull` することがバックアップを兼ねます。

### 1. 調べる（自分の環境がどうなっているか）
まず、使うコマンドの意味から。

| コマンド | 意味 | 見方 |
|---|---|---|
| `df -h ~` | **d**isk **f**ree。ホームがあるディスクの容量と空き | `Avail`（空き）と `Use%`（使用率） |
| `du -sh ~` | **d**isk **u**sage。ホーム以下の合計使用量（`-s`=合計のみ、`-h`=読みやすく） | 自分が実際に使っている量 |
| `du -sh ~/* \| sort -hr \| head` | ホーム直下を**大きい順**に10個 | 容量を食っている犯人探し |
| `quota -s` | あなたの quota（上限）と現在の使用量 | `limit` が上限、`space` が使用量 |

```bash
df -h ~
```
```text
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       1.8T  1.2T  520G  70% /home
```
`Size` はディスク全体の大きさです。**これはあなたの上限ではありません**（他の人の分も含む）。あなた個人の上限は `quota -s` で分かります（`quota` が使えない・何も出ない環境もあります）:
```bash
quota -s
```
```text
Disk quotas for user you (uid 1001):
     Filesystem   space   quota   limit   grace   files   quota   limit   grace
      /dev/sda1  42356M  50000M  55000M            9012       0       0
```
この例では、使用量 `42356M`（約41GB）に対して、警告の目安 `quota`=50GB、絶対上限 `limit`=55GB です。**上限に近いなら対処が必要**です。

次に、**大きなディレクトリを探す**:
```bash
du -sh ~/* 2>/dev/null | sort -hr | head -5
```
```text
31G	/home/user/projects
8.2G	/home/user/miniconda3
1.1G	/home/user/archive
```
そして scratch があるか、**管理者のマニュアル・先輩に聞く**（`ls /scratch` `echo $SCRATCH` で見つかることもあります）。「消える条件」（何日で消えるか）も必ず確認してください。

> 共有ストレージで `du` を巨大なディレクトリ全体に掛けると、サーバーが遅くなります。範囲を狭くし、空いた時間に。

### 2. 設定する（ホームが足りないとき、scratch へ逃がす）
`data/` と `runs/` は Git 管理外なので、**実体を scratch に置き、プロジェクトからはシンボリックリンクで見えるようにする**だけで済みます（[06 UNIX基本](06-unix-basics.md) §5）。
```bash
mkdir -p /scratch/$USER/<project>/{data,runs}      # scratch 側に実体を作る（$USER=自分のユーザー名）
cd ~/projects/<project>
# すでに data/ runs/ に中身があるなら、先に中身を scratch へ移す（mv）。空なら不要:
rmdir data runs 2>/dev/null                          # 空のときだけ消える（中身があれば失敗して無害）
ln -s /scratch/$USER/<project>/data data             # data → scratch の実体
ln -s /scratch/$USER/<project>/runs runs
ls -l                                                # data -> /scratch/... と出れば成功
```
コードは何も変えずに、`data/…` `runs/…` に書き込めば実体は scratch に入ります。

### 3. 消える前提で運用する
- 大きな結果は定期的に `results-pull` で**手元（または長期保存領域）へ回収**する（頻度の目安: 週1回、または大きな実行の後）。
- 「消える日」を過ぎる前に、必要な入力データを再取得できる手順（`data/README.md` の「作り方」）を残す。
- scratch の中身を、ホームから `ls -l` で見えるシンボリックリンクにしておくと、場所が分かる。

## サーバーでの注意
- 共有ストレージで `du` や `find` を巨大なディレクトリに掛けると、自分も他の人も遅くなる。空いている時間に、浅い範囲で。
- 共同利用のディレクトリは動かさない。**自分のホームの中だけ**を整理する。
