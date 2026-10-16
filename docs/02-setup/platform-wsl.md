# PLATFORM_WSL — Windows（WSL2）で手元の環境を作る場合の追記

> 本書は [設計の章](../01-design/README.md)（OS共通のコア）への**追記**。ディレクトリ構造・git運用・スクリプトの使い方はコアのとおり。ここには **Windows + WSL に固有の準備と落とし穴**だけを書く。

## 1. 基本方針: 「ローカル」はWSLのLinux側に置く

- プロジェクトは **WSL内の `~/projects/`** に置く。Windows側（`/mnt/c/...`）に置かない
  - 理由: I/Oが遅い、権限や改行でgitが荒れやすい
- 作業の入り口は **WSLのターミナル**（Windows Terminalのubuntu等）。サーバーへの `ssh`、`git`、`rsync`、`latexmk` はすべてここ
- **VS Codeは WSL内で `code .`**（Remote-WSL）で開く。拡張のgitもWSLのgit/sshを使うので、WSLの鍵がそのまま使える
- 鍵は **WSLの `~/.ssh/` の1か所だけ**。Windows側（`C:\Users\<名前>\.ssh\`）には作らない・置かない

## 2. 鍵とssh-agent（WSL側）

[鍵と接続](../01-design/05-keys-and-sessions.md) の agent forwarding を使うための、手元のagentの準備。

```bash
# 1回だけ: keychain を入れる
sudo apt install keychain

# ~/.bashrc に追記: ssh-agentを使い回す（初回ログイン時だけパスフレーズを聞かれる）
eval "$(keychain --eval --quiet id_ed25519)"
```
`~/.ssh/config` の `ForwardAgent yes` は、信頼できるサーバーの `Host` にだけ書く（[鍵と接続](../01-design/05-keys-and-sessions.md)）。

## 3. VS Code（Windows GUI）でサーバーに入ると鍵が使えない件

**原因:** WindowsアプリのVS Code（Remote-SSH）は、**Windows側の `ssh.exe` と `C:\Users\<名前>\.ssh\`** を使う。WSLの `~/.ssh/` は別の場所なので、鍵も設定も見えない。

対処の選択肢:

1. **VS Codeでサーバーに入らない（推奨・本設計はこれで足りる）**
   - サーバーへは **WSLのターミナルから `ssh`**（対話ジョブや JupyterLab は tmux の中で。[鍵と接続](../01-design/05-keys-and-sessions.md)）
   - `.py` はWSLで編集 → commit/push、または試し送り `sync.sh <server> code-push`
   - notebookはポート転送してブラウザのJupyterで編集（[鍵と接続](../01-design/05-keys-and-sessions.md) の6）
2. **VS Codeに、WSLの `ssh` を使わせる**
   - Windows側にバッチファイル `wsl-ssh.bat` を1つ作る（中身: `C:\Windows\System32\wsl.exe ssh %*`）
   - VS Codeの設定 `remote.SSH.path` にそのパスを指定して再起動
   - NVIDIA Brevのドキュメントで紹介されている回避策（<https://docs.nvidia.com/brev/troubleshooting/ide-connectivity/vscode-windows-wsl>）。ただしそこは特定の構成向けの記述で、**一般のSSH構成で動く保証はない**（設定ファイルの扱い等）。駄目なら `remote.SSH.path` を空に戻す
3. Windows側にも鍵を置く／Windowsのssh-agentを使う → **鍵が2か所になる**。避ける

## 4. 改行コード（CRLF / LF）

WindowsのエディタでWSLのファイルを編集すると、CRLFが混ざって差分が荒れたり、シェルスクリプトが動かなくなったりする。

- `init-project.sh` が作る **`.gitattributes`**（`* text=auto eol=lf`）で、リポジトリ内はLFに固定される
- 念のため、WSL側で1回: `git config --global core.autocrlf input`
- 編集はなるべく **WSL内のエディタ（Remote-WSLのVS Code等）** で行う

## 5. Jupyter（ポート転送）

```bash
# WSLのターミナルで
ssh -N -L 8888:localhost:8888 server-a
```
→ **Windowsのブラウザで `http://localhost:8888`**（WSL2の localhost 転送が有効な構成なら、通常そのまま開ける。開けない場合は `.wslconfig` や WSL のバージョンを確認）

## 6. LaTeX（WSL内で）

- TeX Live と `latexmk` を **WSL内**に入れる（日本語を使うなら日本語用の言語パッケージも）
- ビルド: `cd paper && latexmk -outdir=build main.tex`
- PDFを開く: `explorer.exe paper/build/main.pdf`（WindowsのビューアがPDFを開く）

## 7. その他

- `rsync` はWSLのLinux側の標準（3.x）でよく、追加作業は不要
- WSLの仮想ディスクは使った分だけ大きくなる。`results/` が肥大化しやすいので、`du -sh results/*/*` で定期的に確認し、古いrunは `_archive/` や外部ストレージへ退避する
