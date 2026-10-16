# 03 Git の考え方

## 1. 最低限の絵（commit と branch）
**commit** = ある時点の変更を確定した「セーブポイント」。前の commit につながって**鎖**になります。
**branch** = 鎖の先端につけた名札。`main` は本流の名札です。
```text
 A ── B ── C        ← main（名札は最新の C を指す）
```
新しい commit を作ると、名札が1つ進みます。
```text
 A ── B ── C ── D    ← main
```

## 2. 手元とサーバーの両方が commit したら（pull --rebase の意味）
手元で E、サーバーで D を、それぞれ同じ C から作ったとします。GitHub には先にサーバーの D が届いています。
```text
GitHub:   A ── B ── C ── D
手元:     A ── B ── C ── E          ← このまま push すると「枝分かれしている」と拒否される
```
統合の方法は2つあります。

**(a) merge**: 2つの枝を合流させる commit M を作る。
```text
 A ── B ── C ── D ──┐
            └─ E ───┴─ M       履歴が分岐と合流の形（グラフ）で残る
```
**(b) rebase**: E を「D の後ろ」に付け替える（E を作り直して E' にする）。
```text
 A ── B ── C ── D ── E'         履歴が一直線になる
```
本運用では**(b) rebase を使う**ので、`git pull --rebase` と書きます。理由: 一直線のほうが履歴を読みやすく、`git log` で「いつ何をしたか」を追えるからです。

> 安全のための約束: rebase は**まだ push していない自分の commit** にだけ使う。push 済みの履歴を付け替えると他の場所と食い違う。

### `--autostash` とは
rebase は、手元に**未コミットの変更**があると始められません。`--autostash` は、その変更を一時的に棚（stash）へ退避し、rebase の後で元に戻す指定です。
```text
未コミットの変更 ─(退避)→ 棚 ─ rebase ─(戻す)→ 未コミットの変更
```
サーバーで notebook を編集中に `git pull --rebase --autostash` を使うのは、このためです。

### 2つの場所で触るディレクトリが別だと
手元は `src/`、サーバーは `notebooks/` を触る運用なら、E と D は**別のファイル**を変えているので、rebase は自動で成功します（衝突しない）。これが「編集する場所を分ける」利点です。

## 3. ブランチ（枝）は何のためにあるか
rebase が「**同じ main に、2つの場所から来た変更をつなぐ**」ためなのに対し、branch は「**main を安定させたまま、別の作業を並行して進める**」ためです。別の問題です。
```text
main:     A ── B ── C ───────────── M ── (安定)
                     \             /
feature/new-solver:   F ── G ── H          ← 作業中は main に影響しない。終わったら main に取り込む(M)
```

## 4. 研究向けのブランチとタグのルール
### ブランチ
| 名前 | 用途 | 寿命 |
|---|---|---|
| `main` | 常に**動いて再現できる**状態。直接実験的な変更を入れない | 永続 |
| `feature/<topic>` | 新機能・大きめの変更 | `main` から切り、`main` へ戻して**削除** |
| `exp/<topic>` | 捨てるかもしれない試行 | 駄目なら削除するだけ |
| `fix/<topic>` | バグ修正 | `main` から切り、戻して削除 |

- 名前は小文字＋ハイフン、`種類/内容`の形。
- 注意: `feature` という名前の枝があると `feature/x` は作れない（名前が衝突する）。接頭辞だけの枝は作らない。
- **実験条件の違いは、ブランチではなく `config/` と `run_id` で表す。** 実験ごとにブランチを作ると管理不能になる。ブランチは「コードの変更」だけに使う。

### タグ（節目の名札）
ブランチは先へ進む名札、**タグは動かない名札**。論文を投稿した時点のコード・図・原稿を固定するのに使います。
| タグ | 意味 |
|---|---|
| `paper-<venue>-<yyyymm>` 例 `paper-demo-202610` | 投稿時点のスナップショット |
| `v0.1.0` | 公開版（セマンティックバージョニング） |

run の `meta/git-hash.txt` とタグを照らせば、論文の図の出所を後から辿れます。

### 2拠点（手元・サーバー）での注意
- 同じ作業の間は、**両方で同じブランチ**に切り替える（`git fetch && git switch <branch>`）。
- **サーバーでジョブ実行中にブランチを切り替えない**（動いているコードのファイルが入れ替わる）。
- 取り込み後は両側で `git fetch --prune` して、消えた枝を片付ける。
- `main` への取り込みは GitHub の **Pull Request** を基本にする（変更の記録と議論が残る）。

### コマンドの流れ（1コマンドずつ、何が起きるか）
題材: `main` から作業用の枝 `feature/new-solver` を切り、仕事を終えて取り込み、論文投稿の節目にタグを付ける。
**手元**の動きは `[手元]`、**サーバー**の動きは `[サーバー]` と書きます。

**① 作業用の枝を作る** `[手元]`
```bash
git switch -c feature/new-solver        # -c = create。今いる位置から新しい枝を作って移る
```
```text
 A ── B ── C        ← main
           └─ （feature/new-solver はまだ C と同じ位置。名札が1枚増えただけ）
```
**② GitHub にも枝を作る** `[手元]`
```bash
git push -u origin feature/new-solver   # -u = 以後 push/pull の相手をこの枝に結びつける
```
```text
手元:    feature/new-solver ──────→ GitHub: origin/feature/new-solver（コピーができる）
```
**③ 作業して commit する** `[手元]`（何回でも）
```bash
git add src/solver.py
git commit -m "Add new solver"
git push
```
```text
main:                A ── B ── C                       ← main は動かない（安定のまま）
feature/new-solver:            \── F ── G ── H        ← 枝だけが進む
```
**④ サーバーも同じ枝に切り替える** `[サーバー]`（**ジョブ実行中は避ける**）
```bash
git fetch                               # GitHub の最新情報を取ってくる（作業ファイルはまだ変えない）
git switch feature/new-solver           # 枝を切り替える＝作業ファイルがその枝の状態に入れ替わる
```
**⑤ 終わったので main に取り込む** `[手元]`
```bash
git switch main
git pull --rebase                       # main を GitHub の最新にそろえる
git merge --no-ff feature/new-solver    # 枝を main に合流。--no-ff = 合流の記録(M)を必ず残す
git push                                # 合流した main を GitHub へ
```
```text
main:                A ── B ── C ─────────────── M ── （安定）
                                \               /
feature/new-solver:              F ── G ── H ──┘     ← 作業中は main に影響しない。終わって取り込んだのが M
```
（GitHub 上の Pull Request の画面で「Merge」を押しても同じ結果になります。個人でもこちらを推奨 — 変更の記録が残ります）

**⑥ 役目を終えた枝を片付ける** `[手元]`
```bash
git branch -d feature/new-solver                # 手元の枝を消す（-d: 取り込み済みなら消せる安全な削除）
git push origin --delete feature/new-solver     # GitHub 上の枝も消す
```
消しても、**履歴（F・G・H の commit）は main に残ります**。消えるのは名札だけです。

**⑦ 節目にタグを付ける** `[手元]`
```bash
git tag -a paper-demo-202610 -m "submission snapshot"   # -a = 注釈つきタグ。その時点に印を付ける
git push origin paper-demo-202610                       # タグを GitHub へ（タグは明示して push が必要）
```
```text
… ── M ── N ── O         ← main は先へ進んでも
          ▲
          paper-demo-202610   ← タグは M の位置に固定されたまま（あとで戻れる）
```
**⑧ もう一方の場所でも整理する** `[サーバー]`
```bash
git fetch --prune --tags                # --prune: GitHub で消えた枝を手元の記録からも消す / --tags: 新しいタグを取る
git switch main && git pull --rebase    # main を最新に
```

### 補足: git-flow との関係
有名なブランチ運用 **git-flow** は `master / develop / feature / release / hotfix / support` を使い分けます。複数人でリリースを切る製品向けで、個人の研究には重いため、本運用は**その一部だけ**を取り入れています。
| git-flow | 本運用 |
|---|---|
| master | `main`（採用） |
| develop | 不採用（共同開発者が増えたら導入） |
| feature / hotfix | `feature/` / `fix/`（採用）＋ 試行用の `exp/` を追加 |
| release | ブランチでなく**タグ**で表す |
| support | 不採用（旧版の保守が必要になったら） |

## 5. 大きなファイルを commit してはいけない理由
1. **Git は全ての版を永遠に覚える。** 1回入れた80MBのファイルは、後で消しても履歴に残り、リポジトリは小さくならない。
2. **clone するたびに全履歴が降りてくる。** 新人の clone が遅くなり、サーバーの容量も食う。
3. **GitHub に上限がある。** 1ファイル100MB超は push が拒否される。
4. **差分が取れない・圧縮できない。** 重みやデータ配列（バイナリ）は、少し変えると丸ごと別物として保存される。
5. **消すには履歴の書き換えが要る**（他の人の clone と食い違う、大変な作業）。

守り方（3段）:
1. `.gitignore` に `*.h5 *.npy *.pt *.zip` 等を最初から入れる
2. `git add` は名前を指定する（`git add -A` を使わない）。commit 前に `git diff --cached --stat`
3. 最後の砦の **pre-commit フック**: 5MB超・データ形式のファイルを commit しようとすると止める（`git config core.hooksPath tools/git-hooks`）。どうしても入れるときだけ `git commit --no-verify`

大きいものを共有したいときは rsync（[04 運ぶ道具](04-transport.md)）か Git LFS。

## 6. notebook（ipynb）と Git
### diff が読めなくなるとは、具体的にどうなるか
ipynb の実体は JSON テキストで、**図や表の出力も文字列として埋め込まれます**。コードを1行直しただけでも、実行し直せば出力が変わり、差分はこうなります。
```diff
   "cells": [
    {
     "cell_type": "code",
-    "execution_count": 3,
+    "execution_count": 7,
     "outputs": [
      {
       "data": {
-       "image/png": "iVBORw0KGgoAAAANSUhEUgAAA...（数千行の文字列）",
+       "image/png": "iVBORw0KGgoAAAANSUhEUgAAA...（まったく別の数千行）",
```
「何を変えたか」（コード1行）が、図の文字列（意味のない数千行）に埋もれて読めません。さらに、この出力は履歴に積み重なり、リポジトリが太ります（実例: 8.7MB → 出力除去後 160KB）。

### 対策: nbstripout
commit のときに**出力だけを自動で取り除く**フィルタです。
```bash
conda install -c conda-forge nbstripout   # 環境を有効化して。pip と conda は混ぜない
nbstripout --install --attributes .gitattributes     # ★ clone ごとに1回必要（設定は .git の中に入る）
```
- 出力は Git に残らない → **図・結果は notebook に閉じ込めず、`runs/<run_id>/output/` に保存する**。
- 手元の notebook ファイルにはそのまま出力が残る（commit 時にだけ除かれる）。

### 任意: jupytext
`.ipynb` と、同じ内容を普通の `.py`（`# %%` でセルを区切る形式）で**ペア**にして保存する道具です。
```bash
conda install -c conda-forge jupytext
jupytext --set-formats ipynb,py:percent notebooks/01-explore-input.ipynb
```
```python
# %% [markdown]
# # 入力の確認
# %%
import pandas as pd
df = pd.read_csv("data/raw/sample.csv")
```
`.py` は普通のテキストなので、**行単位でコードの変更だけが diff に出ます**。レビューも履歴の検索も楽になります。ペアの `.py` を commit し、`.ipynb` は無視（または nbstripout 経由）にします。

### notebook の書き方
1. 探索は `notebooks/`、**安定したロジックは `src/` に移して import** する
2. 実行ごとに最初のセルで `new-run.sh` を呼び、**出力は必ず `OUT` へ**
3. 1 notebook = 1 テーマ。上から順に実行して再現できる（Restart & Run All が通る）

最初のセル:
```python
import subprocess, pathlib
ROOT = pathlib.Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
RUN_ID = subprocess.check_output([str(ROOT / "scripts/new-run.sh"), "baseline"], text=True, cwd=ROOT).strip()
OUT = ROOT / "runs" / RUN_ID / "output"
print(RUN_ID)   # 例: 20261014-1530_baseline_a1b2c3d-dirty
```
notebook 編集中は未コミットが普通なので `-dirty` は正常。差分が `meta/uncommitted.diff` に保存されるので再現できます。

## 7. メールアドレスと「他人のリポジトリ」
- **メール**: GitHub で「メールを非公開」にしていると、本物のメールの commit は `GH007` で拒否される。`数字+ユーザー名@users.noreply.github.com` を全拠点で同じ値に設定する。
- **他人のリポジトリ（参考資料）は commit しない**。`~/src/` に clone して読むだけ。変更を残したいなら `git diff > x.patch` で自分のプロジェクトに保存するか、fork する（fork は公開になる）。
