# 05 鍵と接続（SSH鍵・deploy key・tmux・Jupyter）

## 1. 鍵の基本
SSH 鍵は**ペア**です。
- **公開鍵**（`.pub`）: 相手（サーバー、GitHub）に渡してよい「錠」。
- **秘密鍵**: 自分だけが持つ「鍵」。**コピー・送付・貼り付け禁止**。パスフレーズを必ず付ける。

鍵が必要な場面は2つあります。
1. **手元 → サーバー**にログインする（サーバーには公開鍵だけを置く）
2. **GitHub へ push/pull** する（GitHub に公開鍵を登録する）

「**秘密鍵は手元の1か所だけ**」が方針です。ではサーバーから GitHub へ push/pull するにはどうするか — 3つの方式があります。

| 方式 | 秘密鍵の置き場 | サーバーで push/pull | 向く場面 |
|---|---|---|---|
| **A. agent forwarding（推奨）** | 手元のみ | `ssh -A` で入っている間だけ可 | 自分専用・信頼できるサーバー |
| B. deploy key | 手元 ＋ サーバー（そのリポジトリ専用の鍵） | いつでも可 | 長時間ジョブから push したい、共有サーバー |
| C. サーバーが GitHub に出られない | 手元のみ | GitHub 経由は不可（迂回） | 学内限定ネットワーク等 |

## 2. 方式A: agent forwarding
手元の ssh-agent（解錠した鍵を預かる係）を、接続の間だけサーバーが借りる仕組みです。鍵そのものはサーバーに行きません。
```text
# ~/.ssh/config（手元）
Host server-a
    ForwardAgent yes        # 信頼できるサーバーだけに書く。Host * には書かない
```
```bash
ssh -A server-a             # 入ってから確認:  ssh -T git@github.com
```
### agent の基本操作（`ssh-add`）
`ssh-add` は、agent に鍵を預けたり、預けた状況を見たりするコマンドです。
| コマンド | 意味 |
|---|---|
| `ssh-add -l` | agent が今預かっている鍵の**一覧**（l=list）。「鍵が見えるか」の確認に使う |
| `ssh-add ~/.ssh/id_ed25519` | 鍵を agent に**預ける**（パスフレーズを1回入力する） |
| `ssh-add -t 8h ~/.ssh/id_ed25519` | 8時間だけ預ける（時間が来たら自動で忘れる） |
| `ssh-add -c ~/.ssh/id_ed25519` | 預けるが、**鍵を使うたびに確認ダイアログを出す**（c=confirm）。誰かが勝手に使ったら気づける |
| `ssh-add -D` | 預けた鍵を**全部忘れさせる**（D=Delete all。鍵ファイルは消えない） |

```bash
ssh-add -l
```
```text
256 SHA256:AbCd... you@laptop (ED25519)      ← 鍵が1本見える。成功
```
```text
The agent has no identities.                 ← agent は動いているが鍵が空 → ssh-add で預ける
```
```text
Could not open a connection to your authentication agent.   ← agent 自体が動いていない
```

注意:
- 接続中は、サーバーの管理者（root）が**理論上**あなたの鍵を借りられる。自分専用・信頼できるサーバーだけで使う。気になる場合は、上の `ssh-add -c`（使うたびに確認する形で預ける）が選べる。ただし必須ではない。
- git の pull/push は **`ssh -A` で入った普通のターミナル**で行う。tmux の中や Jupyter のターミナルは、agent への接続が古くなって使えないことがある。
- 手元の agent への鍵登録は OS ごと（WSL/Linux は keychain、Mac はキーチェーン）。[WSL](../02-setup/platform-wsl.md) / [Mac](../appendix/platform-macos.md) を参照。

## 3. 方式B: deploy key
**deploy key** = **1つのリポジトリだけ**に登録できる専用の鍵（読み取り専用にもできる）。サーバーで鍵ペアを作り、**公開鍵**を GitHub のそのリポジトリの Settings → Deploy keys に登録します。
```bash
# サーバーで（リポジトリ専用の鍵）
ssh-keygen -t ed25519 -f ~/.ssh/deploy-<project> -C "deploy <project>@server-a"
cat ~/.ssh/deploy-<project>.pub     # → GitHub の Deploy keys へ。push が要るなら "Allow write access"
```
利点: 漏れても被害がそのリポジトリだけ、失効も簡単。欠点: 鍵がサーバーに存在する（盗まれるリスク）、リポジトリごとに鍵が要る。

> ⚠ **この方式は本リポジトリの作成時に実機で試していません。手順は一般的な説明です。実環境で確認してから使ってください。**

## 4. 方式C: サーバーが GitHub に出られない場合
手元から**サーバーを git の remote** として使う（GitHub 不要）。
```bash
git remote add server-a server-a:projects/<project>
git pull --rebase server-a main               # サーバー → 手元
git push server-a main:inbox                  # 手元 → サーバー（別名の枝へ）
ssh server-a 'cd projects/<project> && git merge --ff-only inbox && git branch -d inbox'
```
サーバーが今使っている枝（`main`）へは直接 push できない（`branch is currently checked out` で拒否される）ため、`inbox` という別名の枝へ送って取り込みます。

> ⚠ **未検証です。** 手元のローカル環境（サーバー役のディレクトリ）での動作確認しかしていません。実際のサーバーでは未テスト。研究室のネットワークで試して、結果をこの文書に反映してください。

## 5. tmux
**tmux** = ターミナルを**切断しても生き残らせる**道具。切断すると終わってしまう作業（**対話ジョブ**）を、接続が切れても続けられます。
```bash
tmux new -s work          # 名前付きのセッションを作る
# （ここで作業。Ctrl+b を押してから d で離脱＝バックグラウンドに残る）
tmux ls                   # セッション一覧
tmux attach -t work       # 戻る
```
使いどころ: **ログインノードで tmux を起動 → その中で `qsub -I`（対話ジョブ）を取る**。接続が切れてもセッションが残り、戻れば計算ノードのシェルがそのままあります。

> ⚠ **ログインノードで重い処理（学習・Jupyter サーバー）を tmux の中で直接動かすのは禁止です。** tmux は「接続を保つ」道具で、「計算してよい場所を作る」道具ではありません（[運用ルール](../03-operate/01-server-rules.md)）。
> スケジューラ（`qsub`）に投入したバッチジョブは、tmux が無くても切断に耐えます。

## 6. サーバーの Jupyter に手元のブラウザからつなぐ
Jupyter は**計算ノードで**動かします（ログインノードでは動かさない）。
- **GPU**: `qjupyterlab` を `qsub` で起動し、`qjl.out` に書かれた `ssh -L …` を自分のPCで実行（[03 ジョブスケジューラ §6](../03-operate/03-pbs-jobs.md)）。
- **CPU**: 対話ジョブを取り、その計算ノード上で Jupyter を起動し、ポート転送でつなぐ:
```bash
# サーバー（tmux の中で）
qsub -I -l nodes=1:ppn=4 -l walltime=02:00:00     # 計算ノードに入る
source ~/activate_env.sh
hostname                                          # 計算ノード名を控える（例 node01）
jupyter lab --no-browser --port 8888              # 起動時に token 付き URL が出る

# 手元（新しいターミナル。VPN接続中）
ssh -N -L 8888:node01:8888 your-cpu-server         # 左=PC側ポート、右=計算ノード:ポート
# → ブラウザで http://localhost:8888 （表示された token 付き URL）
```
終わったら Jupyter を `Ctrl+C` で止め、`exit` でノードを開放します。

## 7. ~/.ssh/config の例
```text
Host server-a
    HostName 192.0.2.10
    User username
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    LocalForward 8888 localhost:8888       # Jupyter 用
    ForwardAgent yes                       # 信頼できるサーバーだけ

Host server-b
    HostName cluster.example.ac.jp
    User username
    ServerAliveInterval 60
    # 踏み台が必要なら: ProxyJump gateway
```
接続の使い回し（`ControlMaster`）は連続 rsync を速くしますが、古い接続を使い回すと agent 転送が壊れることがあります（[つまずき集](../04-maintain/troubleshooting.md)）。迷ったら無効のままにします。
