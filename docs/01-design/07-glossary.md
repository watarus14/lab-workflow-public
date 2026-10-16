# 07 用語集

| 用語 | 一言 |
|---|---|
| ターミナル / シェル / bash | コマンドを打つ画面 / それを解釈するプログラム / 代表的なシェル |
| `.sh` ファイル（スクリプト） | コマンドを並べた台本。[詳細](../scripts/00-what-is-sh.md) |
| ドライラン / 予行 | 実際には変更せず「こうなる」と表示だけする実行 |
| 冪等（べきとう） | 何度やっても結果が同じ |
| パス | ファイルの住所。`~` はホーム、`.` は今の場所 |
| 環境変数 | シェルが覚えている名前付きの値（`$HOME` など） |
| git / commit / branch / tag | 履歴管理 / セーブポイント / 履歴の枝の名札 / 動かない名札 |
| main | 本流の枝の名前。GitHub の標準 |
| remote / origin | GitHub 上の保管庫 / その呼び名 |
| clone / pull / push | 保管庫を複製 / 取り込む / 送る |
| merge / rebase | 枝を合流させる / 自分の commit を最新の後ろへ付け替える |
| stash / autostash | 未コミットの変更の一時退避 / それを自動で行う指定 |
| hash | commit の固有ID。run_id にはその先頭7文字 |
| `.gitignore` | git に入れないものの指定 |
| Pull Request (PR) | 「この枝を main に取り込んでください」の依頼と議論の場 |
| rsync | 大きなファイルの同期道具 |
| 公開鍵 / 秘密鍵 | 配ってよい錠 / 絶対渡さない鍵 |
| ssh-agent / `SSH_AUTH_SOCK` | 解錠した鍵を預かる係 / その連絡先の環境変数 |
| agent forwarding（`ssh -A`） | 手元の agent をサーバーが一時的に借りる |
| deploy key | 1リポジトリ専用の鍵 |
| tmux | 切断しても生き残るターミナル |
| noreply メール | GitHub の匿名アドレス（`数字+ID@users.noreply.github.com`） |
| `GH007` | 非公開メールでの push が拒否されたエラー |
| quota | ユーザーごとのディスク使用量の上限（該当する環境のみ）。[詳細](04-transport.md) |
| scratch | 大容量だが自動削除されうる作業領域（該当する環境のみ） |
| `ssh-add` | agent に鍵を預ける・状況を見るコマンド。[詳細](05-keys-and-sessions.md) |
| symlink / ハードリンク / inode | 別の場所を指すショートカット / 同じ実体への別名 / 実体の番号。[詳細](06-unix-basics.md) |
| nbstripout / jupytext | notebook の出力を commit 時に除く / ipynb と .py をペアにする |
| run / `run_id` | 1回の実行 / その識別名 `YYYYMMDD-HHMM_タグ_hash` |
| `-dirty` | 未コミットの変更があった印 |
| 仮想環境 / conda 環境 | プロジェクトごとの Python 環境。**絶対パスが埋め込まれ、移動すると壊れる** |
| editable install（`pip install -e .`） | コピーせず、**今あるソースの場所を指す**形で入れる方式。コードを直すと即反映される。**その場所を移動すると壊れる**ので、移動後は入れ直す |
| PBS / Slurm | ジョブスケジューラ（qsub / sbatch で投入） |
