# lab-workflow — 研究環境の標準運用

手元の PC（WSL / Linux）と計算機サーバーの間で、**ファイル・Git・環境を迷わず扱う**ための、初学者向けの手引きと道具一式です。
「ファイルをどこに置くか」「何で運ぶか」「どう守るか」を、**お箸の持ち方から**説明します。すでにホームが散らかっている人が直すための道具もあります。

- 対象: 研究で Linux / WSL と計算機サーバー（ジョブスケジューラ付き）を使い始める人
- 例として PBS/Torque を使い、PBS Pro・Slurm の対応表を併記しています
- Mac は付録（実機未検証）

## 最短の始め方
```bash
mkdir -p ~/projects && cd ~/projects
git clone https://github.com/your-github-id/lab-workflow.git     # ← あなたのリポジトリの URL に
cd lab-workflow
bin/bootstrap.sh          # 何が作られるか確認（何も変更しない）
bin/bootstrap.sh --run    # ホームに骨格（projects writing notes src archive）を作る
bin/doctor.sh             # 環境の健康診断
tests/run.sh              # （任意）道具の自動テスト
```
`.sh` が何か分からない人は、先に [docs/scripts/00-what-is-sh.md](docs/scripts/00-what-is-sh.md) を読んでください。

## 読む順番
1. [docs/00-overview.md](docs/00-overview.md) — 全体像（1枚）
2. 手を動かす: [Level 0 骨格](docs/02-setup/level0-map.md) → [Level 1 Git と SSH](docs/02-setup/level1-git-ssh.md) → [Level 2 つなぐ](docs/02-setup/level2-connect.md) → [Level 3 回す](docs/02-setup/level3-run.md) → [Level 4 保つ](docs/02-setup/level4-maintain.md) → [Level 5 チームで](docs/02-setup/level5-team.md)
   - すでに散らかっている人は [docs/05-cleanup](docs/05-cleanup/README.md)
3. **サーバーを使う前に必読**: [docs/03-operate](docs/03-operate/README.md)（運用ルール・conda・ジョブスケジューラ）
4. 設計の考え方: [docs/01-design/](docs/01-design/README.md)（原則・ディレクトリ・Git・運ぶ道具・鍵・UNIX早見表・用語集）
5. スクリプトの解説: [docs/scripts/README.md](docs/scripts/README.md)、困ったとき: [つまずき集](docs/04-maintain/troubleshooting.md)

## 構成
`bin/`(道具) `skeleton/`(ホーム骨格の見本) `templates/`(プロジェクト雛形・Git フック) `docs/`(文書) `tests/`(自動テスト: `tests/run.sh`)

## 研究室用に使う（サーバー名などを自分の環境の値にする）
文書中のサーバー名・ユーザー名などは、`your-cpu-server` `your-gpu-server` `your-user` `your-github-id` `your-channel` `your-vpn` `your-lab` という**仮の名前**で書いてあります（そのまま読めます）。自分の研究室の値にするには:
```bash
cp lab.conf.example lab.conf            # lab.conf は Git に入れない設定（.gitignore 済み）
$EDITOR lab.conf                        # 右辺を自分の研究室の値に書き換える
bin/render.sh --lab ~/lab-workflow-lab  # 仮の名前が置き換わった「研究室版」のコピーができる
```
- **`lab.conf.example` は書き換えず、`lab.conf` にコピーして編集**します（example は見本として残す）。
- 研究室版は、元のリポジトリの外に作られます。研究室で配るなら、その `lab-workflow-lab` を研究室の private リポジトリにします。
- 元のリポジトリを直したいとき（誤りの修正など）は、仮の名前のまま直して PR を出します（[CONTRIBUTING.md](CONTRIBUTING.md)）。

## 公開するとき
このリポジトリには、個人情報や特定の研究室の情報を入れていません（`bin/render.sh --check` で検査できます）。ただし **private のリポジトリをそのまま public にすると、過去のコミット履歴が全部公開されます**。公開は次のように、履歴を持ち込まない新しいリポジトリで行ってください。
```bash
bin/make-public-snapshot.sh ~/lab-workflow-public     # 検査 → 履歴なしのコピー（コミット1つ）
cd ~/lab-workflow-public
# GitHub で新しい空のリポジトリを作ってから
git remote add origin git@github.com:<あなた>/lab-workflow.git
git push -u origin main
```

## ライセンス・貢献
[MIT License](LICENSE)。誤りの報告・改善は [CONTRIBUTING.md](CONTRIBUTING.md) へ。実機未検証の箇所（鍵の方式 B・C、Mac 付録など）には「未検証」と明記してあります。
