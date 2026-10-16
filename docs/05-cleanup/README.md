# 既にごちゃごちゃなホームを整える（手順書）

## ゴールの状態
`~` 直下が骨格（`projects writing notes src archive`）＋設定のドットファイル＋道具置き場(`miniconda3`等)だけ。消したものは検証済みで、移動したものは undo できる。

## 原則
**確認してから実行・消さずに動かす。** まず「見る」→「動かす（移動）」→ 十分に確認してから最後に「消す」。消す作業は自動化しない。

## 手順
### 1. 現状を見る（何も変更しない）
```bash
bin/doctor.sh                 # 診断
bin/home-inventory.sh         # ホーム直下の一覧と容量
bin/cleanup-report.sh         # 容量の内訳・肥大化の候補
```
### 2. 移動計画 moves.txt を書く
**名前の直し（大文字→小文字、`_`→`-`）は自動で案が作れます**（案を出すだけで、何も変更しません）:
```bash
bin/normalize-names.sh > moves.txt     # 例: projects/QML_Project -> projects/qml-project
```
`# 衝突:` `# 要手動:` の行は自動で決められないもの（同名が既にある／日本語など）。自分で決めて書き足します。
その後、置き場の移動（下の表）も同じ `moves.txt` に足します。
1行1件、`移動元 -> 移動先`。種類で行き先を決める:
| 中身 | 行き先 |
|---|---|
| 自分の研究コード・実験 | `projects/<名前>` |
| 他人のコード・参考 | `src/<名前>` |
| 論文・申請書・スライド | `writing/` |
| メモ | `notes/` |
| 終わった・不要かも | `archive/<名前>-YYYYMMDD` |
迷うものは **`archive/` に入れる**（消さずに置く）。

**日付つきの名前**（`old-exp-20261015`）は、手で打たず日付コマンドで作れます。`moves.txt` の中では `@DATE@` と書いておき、実行前に置換します:
```bash
sed "s/@DATE@/$(date +%Y%m%d)/g" moves.txt > moves-today.txt
bin/home-organize.sh moves-today.txt          # ドライラン
```
例: `Old_Experiment -> archive/old-experiment-@DATE@`
### 3. ドライラン → 実行
```bash
bin/home-organize.sh moves.txt         # 予定表示のみ
bin/home-organize.sh moves.txt --run   # 実行。undo-<日時>.tsv が残る
```
### 4. プロジェクトを Git 管理にする
Level 1 の手順4。他人のコードを含む場合は、`src/` へ分ける・`.gitignore` に入れる・symlink にする、のいずれか。巨大データは Git に入れず `data/` に置く。
### 5. 容量を減らす（最後に、慎重に）
- 再取得できるキャッシュ（pip, conda pkgs）→ 消してよい
- conda 環境 → `conda env export > env/名前.yml` で控えてから `conda env remove`
- `archive/` の中身 → 数週間使わなかったことを確認してから、**人が判断して**消す
- 重複コピーを消す前は、残す側が完全なことを確認する（件数・サイズ・必要なら checksum）

## 動かす前の確認（壊れやすいもの）
- **git**: 移動自体は安全（相対パスで動く）。先に commit/push しておくと安心。
- **仮想環境（`.venv`・conda 環境）**: 絶対パスが埋め込まれているので、**移動すると壊れる**。ロックファイル（`env/*.yml` 等）から作り直す。
- **editable install（`pip install -e .`）**: 「コピーせず、今ある場所のソースを指す」入れ方。移動すると指す先を失うので、移動後に入れ直す。
- Jupyter のカーネル定義、VS Code の最近のワークスペース、スクリプト内の絶対パス、cron: 移動後にパスを直す。
- キャッシュ類は、移動ではなく別作業で、中身を確認してから消す。
- **名前を変えると、他のものが壊れることがある**（上記のパス）。`normalize-names.sh` の案は必ずドライランで確認する。

## サーバー側
[server.md](server.md) を参照。

## よくある失敗
| 症状 | 対処 |
|---|---|
| 移動後にコードが動かない（相対パス） | symlink で元の見た目を再現（`ln -s ../data/x src/x`）。分からない語は [UNIX早見表](../01-design/06-unix-basics.md) |
| 移動先が既にある | `home-organize.sh` は拒否する。名前を変えて再計画 |
| 間違えて移動した | `undo-<日時>.tsv` を見て逆に移動 |
| 消してから後悔 | 消す前に必ず archive を経由する |

## チェックリスト
- [ ] `bin/doctor.sh` の「6. 散らかり」が `[OK]`
- [ ] 移動はすべてドライランで確認した
- [ ] 消したものは、残るもので代替できると確認した
