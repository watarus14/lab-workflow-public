# Mac で手元の環境を作る場合の追記（付録）

> ⚠ **この付録は Mac の実機で検証されていません。** 一般的な知識と公式情報に基づく説明です。Mac で試した方は、動いた点・詰まった点を issue か PR で報告してください。

> 本書は [設計の章](../01-design/README.md)（OS共通のコア）への**追記**。ディレクトリ構造・git運用・スクリプトの使い方はコアのとおり。ここには **Macに固有の準備と落とし穴**だけを書く。

## 0. 先に結論

Macは**Unix系でネイティブ**なので、WSLのような「二重の環境」の問題はない。

- プロジェクトは普通に **`~/projects/`**
- **VS Code Remote-SSH も `~/.ssh/` をそのまま使える**ので、鍵は1か所で済む
- 追加で気を付けるのは **rsyncの更新**と**キーチェーン連携**、あと**BSDコマンドの差**

## 1. rsync を 3.x に更新する（必須）

`sync.sh` は **rsync 3.1以上**を必要とする（`--info=progress2` / `--files-from` / `--from0` を使うため）。

- macOSの標準rsyncは古い（macOS 14以前は 2.6.9）。**macOS 15.4 以降は、Appleがrsyncを `openrsync` に置き換えた**
  → どちらも、そのままでは `sync.sh` は使えない（`require_rsync` が止めてメッセージを出す）

```bash
brew install rsync
which rsync          # Apple Silicon: /opt/homebrew/bin/rsync、Intel: /usr/local/bin/rsync になっていること
rsync --version      # 3.x と表示されること
```
- `/usr/bin/rsync`（標準）が先に見つかる場合は、Homebrewの `PATH` が前に来ていない。`~/.zprofile` に `eval "$(/opt/homebrew/bin/brew shellenv)"`（Intelは `/usr/local/bin/brew`）を書き、**新しいターミナル**で確認する
- 出典: macOS 15.4でのopenrsync置換 <https://heise.de/-10350663>、標準が2.6.9でHomebrewで更新する手順 <https://dev.to/al5ina5/updating-rsync-on-macos-so-you-re-not-stuck-with-14-year-old-software-1b5i>

## 2. 鍵とssh-agent（キーチェーン連携）

macOSは `ssh-agent` が自動で動いており、**キーチェーンにパスフレーズを覚えさせられる**ので、WSLの `keychain` のような追加ツールは要らない。

```text
# ~/.ssh/config
Host *
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile ~/.ssh/id_ed25519
```
```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519     # macOS 12以降。初回だけパスフレーズを入力
ssh-add -l                                         # 登録されていることを確認
```
- `UseKeychain` はApple独自のオプション。**Linuxとssh設定を共有する**場合は、先頭に `IgnoreUnknown UseKeychain` を書く（書かないとLinuxで「Bad configuration option」になる）
- 古いmacOSでは `--apple-use-keychain` の代わりに `-K`
- `ForwardAgent yes` は、[鍵と接続](../01-design/05-keys-and-sessions.md) のとおり**信頼できるサーバーの `Host` にだけ**書く（`Host *` には書かない）

## 3. シェルとコマンドの差

- 標準の `bash` は **3.2**（既定のシェルは zsh）。本書のスクリプトは `#!/usr/bin/env bash` で、**bash 3.2 でも動くように書いてある**。ただし**Macの実機では未検証**。もし動かなければ `brew install bash` で新しいbashが使われる
- macOSのコマンドは **BSD系**で、GNU拡張が使えない場合がある（例: `date -I`、`sed -i`）。本書のスクリプトはこれらを避けている。**自分でスクリプトを足すときは注意**
- 便利コマンドは `brew install tree` など
- Python 環境は、サーバーと同じく **miniconda**（Apple Silicon 用のインストーラ）を使う。pip と conda を混ぜない（[Python環境](../03-operate/02-python-env.md)）

## 4. VS Code Remote-SSH

`~/.ssh/config` と鍵をそのまま使うので、**サーバーのファイルをVS Codeで直接開いてもよい**。ただし「ファイルごとに編集する場所を決める」原則（[原則](../01-design/01-principles.md)）は変わらない。サーバーで `.py` を直したら、すぐ commit/push して手元で pull する。

## 5. LaTeX

- **MacTeX**（または軽量な **BasicTeX**）を入れる（Homebrewの cask でも入る）。`latexmk` が使えること
- ビルド: `cd paper && latexmk -outdir=build main.tex`
- PDFを開く: `open paper/build/main.pdf`

## 6. その他の落とし穴

- **`.DS_Store`**: Finderが作るごみ。`init-project.sh` の `.gitignore` に入っている
- **大文字小文字を区別しないファイルシステム（既定のAPFS）**: Linuxのサーバーでは別ファイル扱いの `Fig.pdf` と `fig.pdf` が、Macでは同一になる。**コアの命名規則（小文字+ハイフン）を守れば避けられる**。大文字小文字だけの名前変更は `git mv a tmp && git mv tmp A` の2段階で行う
- **スリープ**: Macがスリープすると `ssh` やポート転送が切れる。長い計算は**ジョブとして `qsub` で投入**しておけば、手元が切れても走り続ける（バッチジョブ）。対話ジョブ（`qsub -I`）や JupyterLab は切れると終わるので、サーバーの tmux の中で取る（[鍵と接続](../01-design/05-keys-and-sessions.md)）。接続中だけスリープを止めたいなら `caffeinate -i`
