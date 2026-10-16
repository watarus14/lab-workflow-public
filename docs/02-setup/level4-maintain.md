# Level 4 — 保つ（壊れない・失わない・戻せる状態を続ける）

## ゴールの状態
- 環境が**宣言**（`environment.yml`）として残り、壊れても作り直せる。
- 結果が**手元にも**ある。サーバーのディスクが飛んでも、scratch が自動削除されても困らない。
- 容量・散らかりに**早めに**気づける。
- 節目（論文投稿など）の状態に、あとで正確に戻れる。

## なぜ（原則）
作るより**保つほうが長い**。放っておくと、容量が埋まり、環境は壊れ、「どれが最新か」が分からなくなります。ここでの方針は、**壊れる前提で、戻せる準備をしておく**ことです。
- 再現できる記録 → 環境も結果も「作り直せる」か「別の場所に残っている」かのどちらか。
- 確認してから、消さずに動かす → 消すのは最後。

## 1. 何を、どこに、何で残すか（バックアップ表）
| もの | 正本 | 失ったとき戻すには | 残す手段 |
|---|---|---|---|
| コード・notebook・設定・文書 | GitHub | `git clone` | `git push`（こまめに） |
| 環境 | `environment.yml`（Git内） | `conda env create -f environment.yml` | 変えたら commit |
| 入力データ（再取得できる） | 元の入手先 | `data/README.md` の「作り方」 | 手順を書く |
| 入力データ（再取得できない） | 手元＋長期保存領域 | rsync で戻す | `sync.sh <server> data-pull` |
| 計算結果 | サーバーの `runs/` | 手元の `results/` から | `sync.sh <server> results-pull`（定期） |
| 論文の図 | `paper/figures/`（Git内） | `git checkout` | commit。出所は `SOURCES.tsv` |
| 秘密鍵 | 手元のみ | 作り直して公開鍵を再登録 | **コピーを持ち歩かない** |

「どれか1つの場所が消えても、別の場所に残っている」ことを確認するのが目的です。

## 2. 定期の点検（習慣にする）
### 週1回（5分）
```bash
bin/doctor.sh                                   # 健康診断。要修正を0に
ssh your-cpu-server 'cd ~/projects/<project> && git status --short'   # 未コミットの変更が溜まっていないか
scripts/sync.sh your-cpu-server results-pull -n   # 予行 → 問題なければ -n を外して回収
```
### 月1回（15分）
```bash
bin/cleanup-report.sh                           # 容量の内訳。肥大化していないか
conda env list                                  # 使わない環境が溜まっていないか
git branch -a                                   # 取り込み済みの古い枝を整理（git fetch --prune）
```
容量が逼迫していたら、[整理の手順書](../05-cleanup/README.md) の「5. 容量を減らす」を、**再取得できるキャッシュ → conda 環境（yml を控えてから） → archive**の順で。

### 節目（論文投稿・大きな実験の前後）
1. `git status` が空であることを確認（未コミットなし）。
2. 結果を回収（`results-pull`）し、使った図を `pick-figure.sh` で取り込む。
3. **タグを付ける**: `git tag -a paper-<venue>-<yyyymm> -m "submission snapshot" && git push origin paper-<venue>-<yyyymm>`（[03 Git](../01-design/03-git.md)）。
4. `environment.yml` を最新にして commit。
5. 必要なら `archive/` に結果の固まりを退避（日付つきの名前で）。

## 3. 環境を保つ
- **環境は `environment.yml` が正本**。環境を変えたら必ず書き出す: `conda env export --from-history > environment.yml`。
- **pip と conda を混ぜない**（[02 Python環境](../03-operate/02-python-env.md)）。壊れたら、環境を消して作り直すのが最速です。
  ```bash
  conda env remove -n <env名>
  conda env create -f environment.yml
  ```
- 古い環境を消す前に、`conda env export > env/<名前>-YYYYMMDD.yml` で控える（`date +%Y%m%d` で日付を付ける）。
- プロジェクトを移動・改名したら、**editable install** と Jupyter カーネルの定義を入れ直す（[整理の手順書](../05-cleanup/README.md)）。

## 4. サーバー固有の保守
- **quota**: 上限に近づく前に `du -sh ~/* | sort -hr | head` で確認（[04 運ぶ道具](../01-design/04-transport.md)）。
- **scratch の自動削除**: 結果は定期的に回収。「消える日」を把握しておく。
- **clone ごとの設定**: 新しい clone では必ず（1）`git config core.hooksPath tools/git-hooks`、（2）notebook があるなら `nbstripout --install --attributes .gitattributes`。`bin/doctor.sh` が抜けを指摘します。
- **ジョブの放置**: 対話ジョブ・JupyterLab を放置していないか `qstat -u "$USER"` で確認し、不要なら `qdel`。

## 5. 困ったとき（レスキュー）
| 状況 | 対処 |
|---|---|
| 直前の commit を取り消したい（まだ push していない） | `git reset --soft HEAD~1`（変更は残る） |
| 間違った作者メールで commit した | [つまずき集](../04-maintain/troubleshooting.md)（GH007） |
| 大きなファイルを commit してしまった（未 push） | `git reset --soft HEAD~1` → `.gitignore` に追加 → やり直し |
| 大きなファイルを push してしまった | **一人で履歴を書き換えない。サーバー係に相談**（履歴の書き換えは他の clone と食い違う） |
| サーバーのディスクが飛んだ | `git clone` → `conda env create -f environment.yml` → 手元の `results/` から必要分を `data-push` |
| ファイルを消してしまった | Git 管理下なら `git checkout -- <path>`。管理外（data, runs）は手元の rsync コピーから |
| 環境が壊れた | 作り直す（上の §3） |

## チェックリスト
- [ ] 週次の点検を習慣にした（`bin/doctor.sh` と `results-pull`）
- [ ] `environment.yml` が最新で commit されている
- [ ] 「失ったら戻せるか」を上の表で自分のプロジェクトについて確認した
- [ ] 節目にはタグを付ける手順を知っている

次: [Level 5 — チームで](level5-team.md)
