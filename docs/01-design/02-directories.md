# 02 ディレクトリ設計

## 1. ホームの骨格
```text
~/
├── projects/   計算を伴う研究プロジェクト（1つ = 1ディレクトリ = 1 Gitリポジトリ）
├── writing/    計算を伴わない文章（申請書・スライド・レポート・学位論文の下書き 等）
├── notes/      メモ・議事録・論文を読んだノート
├── src/        他人のコードの clone（読む・参考にするだけ）
├── archive/    終わった・当面使わないもの（消す前の一時置き場）
└── .*          設定（.bashrc, .ssh など。触らない）
```
ホーム直下の非ドット項目は **5〜8個**。`miniconda3` のようなツール本体は例外として許容します（動かすと壊れる）。

### `projects/` の中の `paper/` と、`writing/` は何が違うのか
基準は1つです: **「図や数値の出所が、そのプロジェクトの計算結果（`runs/`）か」**。

| | `projects/<p>/paper/` | `writing/<名前>/` |
|---|---|---|
| 何を書く | そのプロジェクトの計算結果を載せる論文 | 計算結果に直接ひも付かない文章 |
| 例 | 手法を実装して実験した成果の投稿論文 | 研究計画書、輪講スライド、授業レポート、助成金申請書、実験をまとめた学位論文の統合版 |
| 図の出所 | `runs/<run_id>/` から選んで取り込む（出所が記録される） | 手で作る／他から借りる |
| Git | プロジェクトのリポジトリの一部 | 文書ごとに別リポジトリ（必要なら） |
| サーバーに置くか | **不要**（手元で書く） | **不要**（手元と GitHub だけで完結） |

迷ったら: 「この図を再生成するのにプロジェクトのコードが要るか？」要るなら `paper/`、要らないなら `writing/`。
**論文だけ別リポジトリにする**のは、共著者と Overleaf 等で共有する／論文だけ公開・提出する／論文の履歴が計算側を埋もれさせる、のどれかのとき。

### `src/`（ホーム直下）と `projects/<p>/src/`
- `~/src/`: **他人の**リポジトリ。編集しない。編集し始めたら fork して `projects/` へ。
- `projects/<p>/src/`: **そのプロジェクト自身の** Python モジュール。

## 2. プロジェクトの中身（サーバー側）
```text
~/projects/<project>/
├── README.md             目的と使い方
├── .gitignore            Git に入れないものの指定
├── .gitattributes        notebook の出力除去・改行コード固定
├── src/                  [Git] Python モジュール（手元で編集）
├── notebooks/            [Git] 探索用 ipynb（サーバーで編集）
├── config/               [Git] サーバー別設定 server-a.yml, local.yml（手元で編集）
├── scripts/              [Git] new-run.sh, sync.sh 等（手元で編集）
├── docs/                 [Git] 設計メモ・実験ノート（手元で編集）
├── paper/                [Git] 論文（手元で編集。サーバーでは使わない）
├── data/                 [Git外] 入力データ（README だけ追跡）
└── runs/                 [Git外] 計算の出力先 ← ここを手元へ回収
    └── 20261014-1530_baseline_a1b2c3d/      ← run_id
        ├── output/       計算結果・図
        ├── logs/         ログ
        └── meta/         再現用の記録（git hash・差分・設定・環境）
```
`paper/` と `docs/` はサーバーにも clone されますが、**サーバーでは読みも編集もしません**（git が丸ごと持ってくるだけ）。邪魔なら `git sparse-checkout set src notebooks config scripts` で表示から外せます（戻すには `git sparse-checkout disable`）。

## 3. 手元側のディレクトリ構造
サーバーと同じ形です。`runs/` の代わりに、**サーバー別**の `results/<server>/` を持ちます。
```text
~/projects/<project>/
├── （src, notebooks, config, scripts, docs, paper はサーバーと同じ。notebooks は読むだけ）
├── data/                 [Git外] 必要なら回収してバックアップ
└── results/              [Git外] サーバーから回収した成果物
    ├── server-a/20261014-1530_baseline_a1b2c3d/{output,logs,meta}
    └── server-b/
```
| サーバー | 手元 |
|---|---|
| `runs/<run_id>/` | `results/<server>/<run_id>/` |

## 4. 入力データの置き方（具体例）
`data/` は Git に入れませんが、**中身が何か分かる**ようにします。例（画像分類の研究）:
```text
data/
├── README.md                 出所・取得日・サイズ・ライセンスの一覧表
├── raw/                      もらった・ダウンロードしたそのままのデータ（編集しない）
│   └── sensor-log-20260915/  2026年9月15日に取得したセンサーログ
├── processed/                加工済み（raw から再生成できるもの）
│   └── sensor-log-20260915-clean/
└── external/                 他人が配布する公開データセット
    └── cifar-10/
```
`data/README.md` の書き方:
| 名前 | 出所 | 取得日 | サイズ | ライセンス | 作り方 |
|---|---|---|---|---|---|
| `raw/sensor-log-20260915` | 装置Aの出力 | 2026-09-15 | 3.2 GB | 学内限定 | 共有ストレージからコピー |
| `processed/sensor-log-20260915-clean` | 上の加工 | 2026-09-20 | 800 MB | 同上 | `scripts/clean.py` で再生成可 |

原則: **raw は触らない。加工物は raw から作り直せるようにスクリプトを残す。**

## 5. 命名規則と、その理由
**ディレクトリ・ファイル・リポジトリ名は「小文字 + ハイフン」。空白・日本語・大文字は使わない。**

| 規則 | 理由 |
|---|---|
| 大文字を使わない | Windows と Mac は `Data` と `data` を**同じ名前**とみなす。Linux は別物とみなす。OS をまたぐと衝突・消失の原因になる |
| 空白を使わない | コマンドで `my data` は2つの語に割れる。毎回 `"my data"` と書かないと壊れる |
| 日本語を使わない | 文字コードの違いで文字化けし、ツール（rsync・git・スクリプト）が失敗することがある |
| `_` でなく `-` | 見た目と入力のしやすさを統一するため。1つに決めて揺れをなくす（揺れると自動化できない） |
| 接頭の数字 `NN-` | ファイル一覧が「読む順」に並ぶ |

注意: **Python のモジュール（`import` する名前）だけは `_` を使う**（`-` は `import` で使えない）。プロジェクトのディレクトリ名は `my-sim`、その中の Python パッケージ名は `my_sim`、で構いません。

### `run_id` の読み方
`20261014-1530_baseline_a1b2c3d-dirty`
| 部分 | 意味 |
|---|---|
| `20261014-1530` | 実行日時（2026-10-14 15:30）。文字列の順番＝時間の順番なので `ls` が自然に並ぶ |
| `baseline` | 何の実験か（タグ。小文字・数字・ハイフン） |
| `a1b2c3d` | その時点の git の**コミットID（hash）の先頭7文字** |
| `-dirty` | 未コミットの変更があった印 |

**hash から「どのコードで走ったか」が分かる**とは: git の各コミットは固有のIDを持ち、そのIDを指定すれば**その時点のコードをそのまま取り出せます**。
```bash
git show a1b2c3d              # そのコミットで何が変わったか
git switch --detach a1b2c3d   # コードをその時点の状態に戻して眺める（元へは git switch main）
```
`-dirty` のときは、コミットだけでは足りないので、`meta/uncommitted.diff`（未コミットの差分）も併せて見ます。

### notebook の名前
`NN-topic.ipynb` 例: `01-explore-input.ipynb`、`02-fit-baseline.ipynb`。
- `NN`＝2桁の通し番号（読む順に並ぶ）、`topic`＝何をするか。
- 禁止するのは `Untitled3.ipynb`（Jupyter が新規に付ける仮名。中身が分からない）と `analysis-final2.ipynb`（`final2` `new` `old` 等で版を表す名前。**版は git の履歴に任せる**）。

## 6. 手元でもサーバーでも、`init-project.sh` で同じ構造にする
```bash
bin/init-project.sh ~/projects/my-sim server-a
```
既存のファイルは上書きしません。手元とサーバーの**両方**で実行し、GitHub の同じリポジトリにつなぎます。
