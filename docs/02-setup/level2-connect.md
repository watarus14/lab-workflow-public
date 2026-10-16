# Level 2 — つなぐ（サーバーへの接続と、運ぶ道具の使い分け）

## ゴールの状態
- `ssh your-cpu-server` の一言でサーバーに入れる（パスワード入力なし）。
- サーバー側でも同じ骨格（`~/projects` など）と、同じ名前のプロジェクトがある。
- 「コードは git、データ・結果は rsync」と使い分けられる。
- 手元とサーバーのどちらで何を編集するか、ディレクトリ単位で決まっている。

## 先に知っておくこと（サーバーの構造）
サーバーには**ログインノード**（入口。`your-cpu-server` / `your-gpu-server`）と**計算ノード**（実際に計算する機械）があります。`ssh` で入るのはログインノードで、**ここでは計算しません**（編集・git・転送・環境づくりまで）。計算はジョブスケジューラ経由です。必読: [サーバー運用ルール](../03-operate/01-server-rules.md)。
学外から接続するときは your-vpn への接続が必要です。

## なぜ（原則）
- **運ぶ道具は種類で決める。** 小さくて履歴が要るもの(コード・notebook)は git、大きくて履歴が要らないもの(データ・結果)は rsync。混ぜると履歴が膨らみ、片方が壊れる。
- **編集場所を1つにする。** 同じファイルを両方で編集すると衝突する。ディレクトリ単位で「編集する場所」を分ける:

| ディレクトリ | 編集する場所 | 理由 |
|---|---|---|
| `notebooks/` | サーバー | 計算カーネルが要る |
| `src scripts config paper docs` | 手元(WSL) | 実行しなくても書ける |
| `data/` `runs/` | サーバー（手元へは回収） | 大きい・生成物 |
| `results/<server>/` | 手元 | サーバーの `runs/` の回収先 |

## 手を動かす
### 1. 接続名を決める（`~/.ssh/config`、手元）
```
Host your-cpu-server
    HostName <サーバーのアドレス>
    User your-user
    ForwardAgent yes
```
```bash
ssh-copy-id your-cpu-server      # 公開鍵(.pub)をサーバーに登録（初回のみ）
ssh your-cpu-server              # パスワードなしで入れればOK
ssh-add -l                  # サーバー内で実行。鍵が見えれば agent 転送成功（サーバーに秘密鍵は無い）
```
`ForwardAgent yes` が `ssh -A` と同じ効果で、手元の鍵を一時的に借りてサーバーから GitHub に push/pull できる。

### 2. サーバー側にも骨格を作る
```bash
ssh your-cpu-server
mkdir -p ~/projects && cd ~/projects
git clone git@github.com:your-github-id/lab-workflow.git
cd lab-workflow && bin/bootstrap.sh --run && bin/doctor.sh
```

### 3. プロジェクトを両側にそろえる
手元で作って push → サーバーで clone。**同じ名前**にする。
```bash
# サーバー
cd ~/projects && git clone git@github.com:your-github-id/<project>.git
cd <project> && conda install -c conda-forge nbstripout   # 環境を有効化してから（pip と conda は混ぜない）
nbstripout --install --attributes .gitattributes            # clone ごとに必要
```

### 4. コードの流れ（git）
```
手元で編集 → git commit → git push → サーバーで git pull --rebase --autostash
サーバーで notebooks を編集 → git commit → git push → 手元で git pull --rebase
```

### 5. データ・結果の流れ（rsync）— 必ず `-n` から
プロジェクト内で（`scripts/sync.sh` が使える）:
```bash
scripts/sync.sh your-cpu-server results-pull -n      # まず予行（何も転送しない）
scripts/sync.sh your-cpu-server results-pull         # 問題なければ本番
scripts/sync.sh your-cpu-server status               # サーバー上の run 一覧
```
**`--delete` は使わない**（消さない）。大物を除くには `-x '*.npy' -x 'checkpoints/'`。

## よくある失敗
| 症状 | 原因 | 対処 |
|---|---|---|
| ssh で毎回パスワード | 公開鍵が未登録 | `ssh-copy-id` |
| サーバーで `Permission denied (publickey)`（GitHub） | agent転送されていない | 手元で `ssh-add -l`。古い共有接続なら `ssh -O exit your-cpu-server` で切って入り直す |
| `Password for 'https://...'` | remote が HTTPS | `git remote set-url origin git@github.com:...` |
| rsync で `change_dir ... failed` | サーバー側パスが違う | `REMOTE_ROOT` を確認（既定は `~/projects/<名前>`） |
| 両側で編集して git が衝突 | 編集場所の分担違反 | 上の表に戻す。衝突時は `git status` を見て片方を採用 |
| 件数・サイズが合わない | 転送途中・除外・上書き | `-n` の出力と `du -sh` で両側を比較してから判断 |

## チェックリスト
- [ ] `ssh your-cpu-server` がパスワードなしで通る
- [ ] サーバーで `ssh -T git@github.com` が成功（秘密鍵はサーバーに無い）
- [ ] 手元とサーバーで `projects/<名前>` が同名
- [ ] `sync.sh ... -n` を必ず先に実行する習慣
- [ ] コードは git、データは rsync と説明できる

次: [Level 3 — 回す](level3-run.md)
