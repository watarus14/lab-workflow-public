# Level 1 — 手元で記録する（Git と SSH鍵の最初の一歩）

## ゴールの状態
- Git に自分の名前と**noreply メール**が登録されている。
- SSH鍵があり、**ssh-agent** が動いて、パスフレーズ入力は1回だけで済む。
- GitHub に private リポジトリを作り、`git push` できる。
- `bin/doctor.sh` の「2. Git」「3. SSH」が `[OK]`。

## なぜ（原則）
- **秘密は持ち歩かない。** 秘密鍵は手元(WSL/Mac)だけに置く。サーバーには鍵を置かず、手元の鍵を一時的に借りる（`ssh -A`）。
- **再現できる記録を残す。** 変更を Git で履歴にしておけば、いつでも戻せ、どこでも同じ状態を作れる。

## 用語（ここで出てくる言葉）
| 語 | 意味 |
|---|---|
| コミット(commit) | ある時点の変更を「記録」として確定すること。セーブポイント |
| ブランチ(branch) | 履歴の枝の名前。最初の本流を **`main`** と呼ぶ（昔は master）。`init.defaultBranch=main` は「新しく作る時の最初の枝を main にする」設定で、GitHub 側と名前をそろえて混乱を防ぐ |
| remote / origin | GitHub 上の保管庫と、その呼び名 |
| noreply メール | GitHub が用意する公開用の匿名アドレス。本物のメールがコミットに載るのを防ぐ。これ以外だと push が `GH007` で拒否されることがある |
| 公開鍵 / 秘密鍵 | 鍵のペア。**公開鍵(.pub)** は配ってよく、**秘密鍵**は絶対に渡さない |
| ssh-agent | 秘密鍵のパスフレーズを一度解錠して覚えておく係。連絡先は環境変数 `SSH_AUTH_SOCK` |
| keychain | WSL/Linux で ssh-agent を起動・再利用してくれる道具 |

## 手を動かす
### 1. 自己紹介（1回だけ）
GitHub の Settings → Emails で noreply アドレス（`数字+ID@users.noreply.github.com`）を確認。
```bash
git config --global user.name  "Your Name"
git config --global user.email "12345+yourid@users.noreply.github.com"
git config --global init.defaultBranch main
```

### 2. SSH鍵
```bash
ls ~/.ssh                          # id_ed25519 / id_ed25519.pub があれば作らない
ssh-keygen -t ed25519 -C "your-github-id"   # パスフレーズは必ず設定
cat ~/.ssh/id_ed25519.pub          # 表示された1行を GitHub の Settings → SSH keys に貼る
```
**貼るのは .pub の方だけ。** 秘密鍵(`id_ed25519`)は決して貼らない・送らない。

### 3. ssh-agent（keychain）
```bash
sudo apt install keychain
echo 'eval $(keychain --eval --quiet id_ed25519)' >> ~/.bashrc
source ~/.bashrc                   # 初回だけパスフレーズを聞かれる
ssh-add -l                         # 鍵が1本表示されればOK
ssh -T git@github.com              # "Hi <id>! You've successfully authenticated" と出ればOK
```

### 4. 最初のコミットと push
GitHub で空の private リポジトリを作る（README・.gitignore は追加しない）。
```bash
cd ~/projects/my-project
git init -b main
git add .                          # ★ git add -A は使わない。何が入るか git status で確認
git status
git commit -m "Initial commit"
git remote add origin git@github.com:<GITHUB_USER>/my-project.git   # SSH形式(git@...)を使う
git push -u origin main
```

## よくある失敗
| 症状 | 原因 | 対処 |
|---|---|---|
| push で `GH007` | メールが非公開設定なのに本物のメールで commit | noreply に変更 → 未pushの commit は `git reset --soft origin/main` 後に commit し直す |
| `Password for 'https://...'` | remote が HTTPS | `git remote set-url origin git@github.com:...` |
| `Permission denied (publickey)` | 公開鍵未登録／agentに鍵が無い | 手順2・3 |
| `branch -M main` が失敗 | まだ1回もコミットしていない | `git init -b main`（空でも安全） |
| 巨大ファイルを commit しそう | `.gitignore` 漏れ | pre-commit フックが止める（`git config core.hooksPath tools/git-hooks`） |
| サーバーで push できない | 鍵がサーバーに無い（正しい） | 手元から `ssh -A` で入る |

## チェックリスト
- [ ] `git config --global -l` に name / email(noreply) / defaultBranch=main
- [ ] `ssh -T git@github.com` が成功
- [ ] `bin/doctor.sh` の 2・3 が `[OK]`
- [ ] `git add -A` を使わない理由（意図しないファイルが入る）を説明できる

次: [Level 2 — つなぐ](level2-connect.md)
