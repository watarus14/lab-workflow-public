# Level 0 — 地図をもつ（まず全体像と骨格）

## ゴールの状態
- `~` 直下が `projects writing notes src archive` の5つ（と設定用のドットファイル）だけになっている。
- 何をどこに置くかを、自分の言葉で説明できる。
- `bin/doctor.sh` が「要修正 0」を返す。

## なぜ（原則）
**置き場所は1つ。** 同じものが2箇所にあると、どれが最新か分からなくなる。
家の片付けと同じで、「住所が決まっていれば探さなくてよい」。ホーム直下に物を直接置かず、種類ごとの引き出しに入れる。

## 手を動かす
```bash
# 1. このリポジトリを clone する（projects の中へ）
mkdir -p ~/projects && cd ~/projects
git clone git@github.com:your-github-id/lab-workflow.git
cd lab-workflow

# 2. 何が作られるか確認（ドライラン。何も変更しない）
bin/bootstrap.sh
#    期待: "ドライラン" と表示され、[作成] の行が並ぶ

# 3. 実際に作る
bin/bootstrap.sh --run
ls ~            # projects writing notes src archive が見える

# 4. 健康診断
bin/doctor.sh
#    [注意]/[要修正] の下の「→」を読んで、1つずつ直す
```

## よくある失敗
| 症状 | 原因 | 対処 |
|---|---|---|
| `Permission denied` | 実行権限がない | `bash bin/bootstrap.sh` と bash 経由で実行 |
| `Repository not found` | SSH鍵の登録前／リポジトリ名の誤り | 先に Level 1 の鍵設定、URL確認 |
| `[既にある]` と出る | すでに存在 | 正常。何も壊していない |
| doctor が `user.email` で要修正 | Git未設定 | 画面の `→` のコマンドを実行 |

## チェックリスト
- [ ] `ls ~` が5つの骨格＋ドットファイルだけ
- [ ] `bin/doctor.sh` の「要修正」が0
- [ ] `.sh` が台本だと説明できる（[00-what-is-sh](../scripts/00-what-is-sh.md)）

次: [Level 1 — 手元で記録する（Git と SSH）](level1-git-ssh.md)
