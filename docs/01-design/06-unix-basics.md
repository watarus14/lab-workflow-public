# 06 UNIX 基本コマンド早見表（例つき）

ターミナルで使う基本の道具を、**実際に打って確かめられる例**つきでまとめます。出力は実際に動かして確認したものです（日時やユーザー名は環境によって違います）。

> ⚠ 先に知っておくこと: **`rm`（削除）、`mv`（上書きになりうる移動）、`>`（上書き）は元に戻せません。** ゴミ箱はありません。迷ったら練習用の場所（下の「0. 練習場」）で試してください。

## 0. 練習場を作る（ここなら何を壊しても平気）
```bash
mkdir -p ~/practice && cd ~/practice
pwd
```
```text
/home/user/practice
```
以降の例は、すべてこの `~/practice` の中で試せます。終わったら `rm -r ~/practice` で一括削除できます（練習場の中だけなので安全）。

## 1. 「今どこ」「何がある」を見る
| コマンド | 意味 |
|---|---|
| `pwd` | **p**rint **w**orking **d**irectory。今いる場所（住所）を表示 |
| `ls` | 中身の一覧 |
| `ls -l` | 詳細つき（権限・持ち主・サイズ・日時） |
| `ls -a` | `.` で始まる隠しファイルも表示 |
| `ls -la` | 両方 |
| `ls -lh` | サイズを `4.0K` `3.2G` のように読みやすく |
| `tree -L 2` | 2階層まで木のように表示（入っていなければ `sudo apt install tree`） |

```bash
mkdir -p proj/{src,data}
touch proj/src/a.py proj/src/b.py proj/data/x.csv
ls proj
```
```text
data  src
```
`mkdir -p proj/{src,data}` の `{src,data}` は「src と data の2つ」を一度に指定する書き方です。`touch` は空のファイルを作ります。

```bash
ls -l proj/src
```
```text
total 0
-rw-r--r-- 1 you you 0 Oct 16 00:57 a.py
-rw-r--r-- 1 you you 0 Oct 16 00:57 b.py
```
左から: 種別と権限 / リンク数 / 持ち主 / グループ / サイズ(バイト) / 日時 / 名前。先頭の `-` はふつうのファイル、`d` はディレクトリ、`l` はシンボリックリンクです。

## 2. 移動する
| コマンド | 意味 | 例 |
|---|---|---|
| `cd DIR` | DIR へ移動 | `cd proj/src` |
| `cd ..` | 1つ上へ | |
| `cd ~` または `cd` | ホームへ | |
| `cd -` | 直前にいた場所へ | |

特別な記号: `~`=ホーム、`.`=今の場所、`..`=1つ上。

```bash
cd proj/src ; pwd ; cd .. ; pwd ; cd - ; pwd
```
```text
/home/user/practice/proj/src
/home/user/practice/proj
/home/user/practice/proj/src
/home/user/practice/proj/src
```
（1行目=最初の `pwd`、2行目=`cd ..` 後の `pwd`、3行目=`cd -` が戻り先を自動表示、4行目=最後の `pwd`。`;` はコマンドを続けて実行する区切りです。）

**Tab キー**: 名前の途中まで打って Tab を押すと補完されます。打ち間違いと入力量が激減するので、必ず使う習慣を。

## 3. 作る・コピー・移動・名前変更
| コマンド | 意味 | 注意 |
|---|---|---|
| `mkdir DIR` | ディレクトリを作る | |
| `mkdir -p A/B/C` | 途中も含めて作る | 既にあっても怒らない |
| `touch FILE` | 空ファイルを作る（既にあれば日時だけ更新） | |
| `cp A B` | ファイル A を B にコピー | B が既にあれば**上書き** |
| `cp -i A B` | 上書きするとき確認する | |
| `cp -r DIR1 DIR2` | ディレクトリを中身ごとコピー | |
| `cp -a DIR1 DIR2` | **アーカイブ**コピー（権限・日時・リンクも保つ） | バックアップ向け |
| `cp -al DIR1 DIR2` | **ハードリンクのコピー**（容量を増やさない） | 後述 §5 |
| `mv A B` | A を B へ移動 / 名前変更 | B が既にあれば**上書き**。`mv -i` で確認 |

```bash
cp proj/src/a.py proj/src/a-copy.py     # コピー
mv proj/src/a-copy.py proj/src/c.py     # 名前変更（同じ場所での mv）
mv proj/src/c.py proj/data/             # 別のディレクトリへ移動（末尾 / は「その中へ」の意味）
ls proj/src proj/data
```
```text
proj/data:
c.py  x.csv

proj/src:
a.py  b.py
```
名前を変えることと移動は、どちらも `mv` です。

```bash
cp -a proj proj-backup        # proj ごとコピー（-a: 属性も保つ）
ls
```
```text
proj  proj-backup
```

## 4. 消す（最も危険）
| コマンド | 意味 |
|---|---|
| `rm FILE` | ファイルを削除。**戻せない** |
| `rm -i FILE` | 消す前に確認 |
| `rm -r DIR` | ディレクトリを中身ごと削除 |
| `rmdir DIR` | **空の**ディレクトリだけ削除（安全） |

絶対に避ける: `rm -rf` に、変数やワイルドカードを組み合わせること（`rm -rf $DIR/*` で `$DIR` が空だと、ルート直下を消しに行く事故が実際にあります）。**迷ったら消さず、`~/archive/` へ `mv`** します。

## 5. リンク（別名とショートカット）— 初めての人向けの説明
ファイルは、本当は**2つの部分**でできています。
```text
 名前（ファイル名）  ──→  実体（ディスク上のデータ本体）
```
普通は「名前1つ ＝ 実体1つ」ですが、リンクを使うと関係を変えられます。

### 5-1. ハードリンク — 同じ実体に、名前をもう1つ付ける
```text
 名前 a.txt ──┐
              ├─→ 実体（"hello"）     名前が2つ、実体は1つ
 名前 b.txt ──┘
```
```bash
echo "hello" > a.txt
ln a.txt b.txt                  # a.txt の別名 b.txt を作る（ハードリンク）
ls -li a.txt b.txt
```
```text
967569 -rw-r--r-- 2 you you 6 Oct 16 00:57 a.txt
967569 -rw-r--r-- 2 you you 6 Oct 16 00:57 b.txt
```
先頭の数字（`967569`）は**実体の番号（inode）**で、**2つとも同じ**です。これが「同じ実体」の証拠。3列目の `2` は「この実体に名前がいくつあるか」です。

- どちらかを書き換えると、**もう一方も変わる**（同じ実体だから）:
  ```bash
  echo "world" >> a.txt ; cat b.txt
  ```
  ```text
  hello
  world
  ```
- どちらかを `rm` しても、**もう一方が残る限り実体は消えない**:
  ```bash
  rm a.txt ; cat b.txt
  ```
  ```text
  hello
  world
  ```
  （名前が全部なくなって初めて実体が消える）
- 使えるのは**同じディスク内のファイルだけ**。ディレクトリには使えない。

### 5-2. シンボリックリンク（ショートカット）— 別の場所を指す小さなファイル
```text
 link.txt ──(「b.txt を見て」と書いてある)──→ b.txt ──→ 実体
```
```bash
ln -s b.txt link.txt            # ln -s 本体 リンク名
ls -l link.txt
cat link.txt
```
```text
lrwxrwxrwx 1 you you 5 Oct 16 00:57 link.txt -> b.txt
hello
world
```
`ls -l` の先頭 `l` と `->` が目印です。**本体を消すとリンクは切れます**（壊れたショートカット）:
```bash
rm b.txt ; cat link.txt
```
```text
cat: link.txt: No such file or directory
```
ディレクトリにも、別のディスクにも使えます。Windows のショートカットに近いものです。

### 5-3. 比べると
| | ハードリンク `ln A B` | シンボリックリンク `ln -s A B` |
|---|---|---|
| 正体 | 同じ実体への**別名** | 別の場所を**指す**メモ |
| 本体を消すと | 実体は残る | リンクが切れる |
| ディレクトリ | 不可 | 可 |
| ディスクをまたぐ | 不可 | 可 |
| 容量 | 増えない | ほぼ増えない |
| 見分け方 | `ls -li` で inode が同じ | `ls -l` で `l` と `->` |

### 5-4. この運用での使いどころ
- **`ln -s`**: コードが決め打ちの相対パス（`../data-x/`）でデータを読むとき、実際の置き場所を変えずに元の見た目を再現する。`ln -s ../data/data-x src/data-x`。大容量の `data/` を scratch へ逃がすときも同じ。
- **`cp -al`**: データを複製したように見せて容量を増やさない。整理の途中で新旧の構成を並べたいとき。
  ```bash
  mkdir -p d1 && echo x > d1/f
  cp -al d1 d2                    # d2 は d1 の「ハードリンクのコピー」
  ls -li d1/f d2/f                # inode が同じ ＝ 実体は1つ
  ```
  ```text
  967690 -rw-r--r-- 2 you you 2 Oct 16 00:57 d1/f
  967690 -rw-r--r-- 2 you you 2 Oct 16 00:57 d2/f
  ```
  ⚠ 片方の**中身を書き換える**と両方変わる。編集しないデータ向け。

## 6. 容量を調べる
| コマンド | 意味 |
|---|---|
| `du -sh DIR` | DIR の合計サイズ（`-s`=合計だけ、`-h`=読みやすく） |
| `du -sh DIR/*` | 中の各項目ごとのサイズ |
| `du -sh * \| sort -h` | 小さい順に並べる（`sort -hr` で大きい順） |
| `df -h .` | 今いるディスクの全体容量と空き |

```bash
du -sh proj ; du -sh proj/*
df -h . | head -2
```
```text
12K	proj
4.0K	proj/data
4.0K	proj/src
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda        252G   14G   30G  31% /
```
`du` は「ディレクトリが使っている量」、`df` は「ディスク全体の空き」。**ホームがいっぱいになりそうなら、まず `du -sh ~/* | sort -hr | head` で大きい順に見る。**

## 7. 探す・比べる
| コマンド | 意味 | 例 |
|---|---|---|
| `find DIR -name '*.py'` | 名前で探す | `find proj -name '*.py'` |
| `find DIR -size +100M` | 100MB超を探す | |
| `grep -rn "語" DIR` | 中身を検索（`-r` 再帰、`-n` 行番号） | `grep -rn "import" proj` |
| `diff -rq A B` | 2つのディレクトリの差を一覧 | 何も出なければ同一 |
| `wc -l FILE` | 行数を数える | |

```bash
find proj -name '*.py'
```
```text
proj/src/a.py
proj/src/b.py
```
```bash
diff -rq proj proj-backup && echo "同じ"
echo "z" > proj-backup/src/a.py
diff -rq proj proj-backup
```
```text
同じ
Files proj/src/a.py and proj-backup/src/a.py differ
```
**コピーや移動が正しくできたかの確認**に `diff -rq` が使えます（重複を消す前に必ず）。

## 8. 読む
| コマンド | 意味 |
|---|---|
| `cat FILE` | 全部表示（短いもの向け） |
| `less FILE` | ページ送りで読む（`q` 終了、`/語` 検索、`Space` 次ページ） |
| `head -n 20 FILE` / `tail -n 20 FILE` | 先頭 / 末尾の20行 |
| `tail -f FILE` | 末尾を監視（ログが増えるのを見る。`Ctrl+C` で止める） |

## 9. 権限と実行
`ls -l` の `-rw-r--r--` は、持ち主 / グループ / その他の「読む r・書く w・実行する x」の許可です。
| コマンド | 意味 |
|---|---|
| `chmod +x FILE` | 実行を許可（これで `./FILE` と呼べる） |
| `bash FILE` | 権限なしでも bash に読ませて実行 |
| `echo $?` | 直前のコマンドの**終了コード**（0=成功、他=失敗） |

```bash
touch tool.sh ; ls -l tool.sh ; chmod +x tool.sh ; ls -l tool.sh
```
```text
-rw-r--r-- 1 you you 0 Oct 16 00:57 tool.sh
-rwxr-xr-x 1 you you 0 Oct 16 00:57 tool.sh
```

## 10. 組み合わせる記号
| 記号 | 意味 | 例 |
|---|---|---|
| `\|`（パイプ） | 左の出力を右の入力に渡す | `ls proj/src \| wc -l` → `2`（個数） |
| `>` | 出力をファイルへ（**上書き**） | `ls > list.txt` |
| `>>` | 出力をファイルの末尾へ**追記** | `echo memo >> notes.txt` |
| `*` | 任意の文字列にマッチ（ワイルドカード） | `ls proj/src/*.py` |
| `;` | コマンドを順に実行 | `cd proj ; ls` |
| `&&` | 左が**成功したら**右を実行 | `mkdir x && cd x` |
| `$(...)` | コマンドの結果をその場に埋め込む | 下の日付の例 |
| `"..."` | 空白を含む語を1つにまとめる | `mkdir "my dir"` |

```bash
printf 'b\na\nc\n' | sort
```
```text
a
b
c
```

## 11. 日付つきの名前を作る
`backup-20261016` のような名前は、手で打たず**日付コマンド**で作れます（打ち間違いも日付の書式揺れも防げる）。
```bash
date                      # 現在の日時
date +%Y%m%d              # 年月日だけ
date +%Y%m%d-%H%M         # 年月日-時分
```
```text
Fri Oct 16 00:57:11 UTC 2026
20261016
20261016-0057
```
書式の記号: `%Y`=年(4桁)、`%m`=月(2桁)、`%d`=日(2桁)、`%H`=時、`%M`=分、`%S`=秒。**年月日の順に並べると、名前の辞書順＝時間順**になり、`ls` で自然に並びます。

`$(...)` で名前に埋め込む:
```bash
mkdir backup-$(date +%Y%m%d)
ls -d backup-*
```
```text
backup-20261016
```
変数に入れて何度も使う:
```bash
D=$(date +%Y%m%d)
mkdir ~/archive/old-exp-$D
cp -a proj ~/archive/old-exp-$D/
echo "$D"
```
```text
20261016
```
**同じ日に2回作ると衝突する**（`mkdir` が「既にある」と言う）ときは、時分も付ける: `backup-$(date +%Y%m%d-%H%M)`。

移動表（`moves.txt`）では `@DATE@` と書き、実行前に置換します（[整理の手順書](../05-cleanup/README.md)）:
```bash
echo 'Old_Exp -> archive/old-exp-@DATE@' > moves.txt
sed "s/@DATE@/$(date +%Y%m%d)/g" moves.txt
```
```text
Old_Exp -> archive/old-exp-20261016
```

## 12. 困ったとき
- 打ち間違い: `↑` キーで直前のコマンドを呼び出して直せる。`Ctrl+R` で過去のコマンドを検索。
- 動いているものを止める: `Ctrl+C`。
- コマンドの説明: `man ls`（`q` で終了）、または `ls --help`。
- 画面が崩れた: `reset`。
- 分からない語は [用語集](07-glossary.md) へ。
