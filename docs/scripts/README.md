# スクリプト解説書

まず [00-what-is-sh.md](00-what-is-sh.md)（.shとは何か）を読んでください。以降は1本ずつ「何を・なぜ・安全性・読み方」を説明します。

---
## doctor.sh — 健康診断
**何を**: 道具(git/ssh/rsync)、Gitの名前とメール、SSH鍵とagent、ホームの骨格、各プロジェクトのremote・フック・未コミット、ホーム直下の散らかりを調べる。
**なぜ**: 「3分チェックリスト」を人が手で確認すると忘れる。機械に任せる。新人の最初の1歩にも、半年後の見直しにも使う。
**安全性**: 読み取り専用。何も変更しない（テストで保証）。
**出力の読み方**: `[OK]` 良い／`[注意]` 直した方がよい／`[要修正]` 直すべき。各項目の `→` の行が直し方。
**使い方**: `bin/doctor.sh`。終了コードは「要修正」があれば1。
**読むコツ**: `ok_` `warn_` `ng_` という3つの小さな関数が表示を担当し、各チェックがそれを呼ぶ。チェックを足すなら同じ形で1ブロック足すだけ。

## bootstrap.sh — ホームの骨格づくり
**何を**: `~/projects ~/writing ~/notes ~/src ~/archive` を作り、各所に役割を書いた README を置く。
**なぜ**: 「cloneするだけでは `~` 直下に何も作れない」ので、clone後に1回だけ走らせる。
**安全性**: 既定はドライラン。`--run` で作る。既存は触らない（冪等）。`--target DIR` で練習先を指定できる。
**使い方**: `bin/bootstrap.sh` → 内容を確認 → `bin/bootstrap.sh --run`。

## cleanup-report.sh — 容量の報告
**何を**: 大きい順の一覧、キャッシュ・conda環境・VS Code serverなど肥大化しやすい場所、100MB超ファイル、Git管理下の巨大ファイル。
**なぜ**: 消す前に「何が重いか」を知るため。**消す作業は自動化しない**（人が判断）。
**安全性**: 読み取り専用。

## home-inventory.sh / home-organize.sh — 棚卸しと整理
**何を**: inventory はホームの中身を一覧にする。organize は `moves.txt`（`移動元 -> 移動先` の一覧）どおりに移動する。
**安全性**: organize は既定ドライラン、`--run` で実行。削除しない・既存の行き先は上書きしない・`undo-<日時>.tsv` を残す。ドットファイルは対象外。
**流れ**: inventory → moves.txt を自分で書く → ドライラン → `--run` → 問題があれば undo。詳細は docs/05-cleanup。

## normalize-names.sh — 名前の正規化案
**何を**: ディレクトリ名を「小文字＋ハイフン」に直す移動案を、`home-organize.sh` の移動表の形式で出す（`QML_Project -> qml-project`）。
**なぜ**: 名前の揺れは自動化の敵。手で1つずつ直すより、案を機械に出させて人が確認する。
**安全性**: 案を出すだけで何も変更しない。衝突・日本語は `# 衝突:` `# 要手動:` で知らせる。
**使い方**: `bin/normalize-names.sh > moves.txt` → 編集 → `bin/home-organize.sh moves.txt`（ドライラン）。

## init-project.sh — プロジェクト雛形
**何を**: `src notebooks config scripts docs paper data runs results` と .gitignore、README、補助スクリプト、pre-commitフックを備えたプロジェクトを作り、git init する。
**使い方**: `bin/init-project.sh ~/projects/my-sim server-a`。既存ファイルは上書きしない。

## qsub-run.sh — ジョブ雛形
**何を**: ジョブスクリプトを**画面に出す**。投入はしない。PBS/Torque（既定）、`--pbspro`、`--slurm`。`--cores N` `--gpus N` `--walltime HH:MM:SS` `--env <conda環境>` を指定できる。
**使い方**: `bin/qsub-run.sh --cores 4 --env my-sim vqe-test -- python src/main.py > job.sh` → 資源量・環境名を確認・編集 → `qsub job.sh`。
**注意**: `#$` は Grid Engine の書式で PBS では無視される。必ず `#PBS`。GPU の書式は計算機ごとに違うので、研究室の既存ジョブスクリプトと見比べる。

## render.sh — 研究室版の生成と、混入の検査
**何を**: 文書中の仮の名前（`your-cpu-server` など）を、`lab.conf` の値に置き換えた**研究室版のコピー**を作る（`--lab`）。`--check` は、リポジトリ本体に個人情報や研究室の実値が混入していないかを検査する。
**使い方**: `cp lab.conf.example lab.conf` → 右辺を編集 → `bin/render.sh --lab ~/lab-workflow-lab`。公開・PR の前に必ず `bin/render.sh --check`。元ファイルは変更されない。

## make-public-snapshot.sh — 公開用の「履歴なし」コピー
**何を**: 現在の内容だけを新しい Git リポジトリ（コミット1つ）にしたコピーを作る。過去のコミット履歴を持ち込まない。
**なぜ**: private のリポジトリをそのまま public にすると、**過去の全コミット**が公開される。昔の版に個人名や研究室の情報が入っていたら漏れる。
**使い方**: `bin/make-public-snapshot.sh ~/lab-workflow-public` → 中身を確認 → 新しい空の GitHub リポジトリへ push。
