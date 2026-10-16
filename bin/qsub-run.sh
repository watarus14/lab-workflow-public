#!/usr/bin/env bash
# qsub-run.sh — ジョブスクリプトの雛形を作る（PBS/Torque 既定、PBS Pro、Slurm）。投入はしない。
#
# 使い方:
#   bin/qsub-run.sh [オプション] <tag> -- <実行コマンド...>   （雛形を標準出力へ。投入はしない）
# オプション:
#   --cores N       使うCPUコア数（既定 4）
#   --gpus N        使うGPU枚数（既定 0 = GPUなし）
#   --walltime HH:MM:SS   最大実行時間（指定したときだけ書く）
#   --env NAME      有効化する conda 環境名（既定 myenv。実環境の名前に直すこと）
#   --pbspro | --slurm    書式を変える（既定は PBS/Torque）
# 例:
#   bin/qsub-run.sh vqe-test -- python src/main.py --seed 1 > job-vqe-test.sh
#   bin/qsub-run.sh --gpus 1 --env gpudemo train -- python src/train.py > job-train.sh
#
# 出力されたスクリプトを確認してから、Torque/PBS なら qsub、Slurm なら sbatch で投入する。
# 資源量の書式は計算機ごとに違う（特に GPU の書式は環境依存）。研究室の既存ジョブスクリプトに合わせること。
#
# 対応表:  PBS/Torque               Slurm
#          #PBS -N name             #SBATCH -J name
#          #PBS -l nodes=1:ppn=4    #SBATCH -c 4
#          #PBS -l walltime=...     #SBATCH -t ...
#          $PBS_O_WORKDIR           $SLURM_SUBMIT_DIR
#          qsub / qstat / qdel      sbatch / squeue / scancel

set -euo pipefail
SCHED=torque; CORES=4; GPUS=0; WALL=""; ENVNAME=myenv
while [ $# -gt 0 ]; do
    case $1 in
        --cores)    shift; CORES=${1:?} ;;
        --gpus)     shift; GPUS=${1:?} ;;
        --walltime) shift; WALL=${1:?} ;;
        --env)      shift; ENVNAME=${1:?} ;;
        --pbspro)   SCHED=pbspro ;;
        --slurm)    SCHED=slurm ;;
        -h|--help)  sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        --)         break ;;
        -*)         echo "不明なオプション: $1" >&2; exit 2 ;;
        *)          break ;;
    esac
    shift
done
[ $# -ge 3 ] && [ "$2" = "--" ] || { sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
TAG=$1; shift 2
case $TAG in *[!a-z0-9-]*) echo "tag は小文字英数字とハイフンのみ（new-run.sh と同じ規則）" >&2; exit 2;; esac
case $CORES$GPUS in *[!0-9]*) echo "--cores / --gpus は整数" >&2; exit 2;; esac
CMD=$(printf '%q ' "$@")

CONDA_LINES='source "$HOME/miniconda3/etc/profile.d/conda.sh" && conda activate '"$ENVNAME"'   # 環境名を実環境に合わせる'
BODY='RUN_ID=$(scripts/new-run.sh "'"$TAG"'")      # runs/<run_id>/ を作り、run_id を返す
echo "run_id=$RUN_ID"
'"$CMD"' 2>&1 | tee "runs/$RUN_ID/logs/stdout.log"'

case $SCHED in
torque)
    RES="nodes=1:ppn=$CORES"; [ "$GPUS" -gt 0 ] && RES="nodes=1:ppn=$CORES:gpus=$GPUS"
    echo '#!/bin/bash'
    echo "#PBS -N $TAG"
    echo "#PBS -l $RES"
    [ -n "$WALL" ] && echo "#PBS -l walltime=$WALL"
    echo '#PBS -j oe'
    echo '# 注意: "#$" で始まる行は Grid Engine の書式で、PBS では無視される。必ず "#PBS" を使う。'
    echo '# 注意: GPU枚数の書式（gpus=）は計算機ごとに違う。研究室の既存ジョブスクリプトと見比べて確認すること。'
    echo
    echo 'cd "$PBS_O_WORKDIR"'
    echo "$CONDA_LINES"
    echo "$BODY" ;;
pbspro)
    echo '#!/bin/bash'
    echo "#PBS -N $TAG"
    echo "#PBS -l select=1:ncpus=$CORES$([ "$GPUS" -gt 0 ] && echo ":ngpus=$GPUS")"
    [ -n "$WALL" ] && echo "#PBS -l walltime=$WALL"
    echo '#PBS -j oe'
    echo
    echo 'cd "$PBS_O_WORKDIR"'
    echo "$CONDA_LINES"
    echo "$BODY" ;;
slurm)
    echo '#!/bin/bash'
    echo "#SBATCH -J $TAG"
    echo "#SBATCH -c $CORES"
    [ "$GPUS" -gt 0 ] && echo "#SBATCH --gres=gpu:$GPUS"
    [ -n "$WALL" ] && echo "#SBATCH -t $WALL"
    echo '#SBATCH -o slurm-%j.out'
    echo
    echo 'cd "$SLURM_SUBMIT_DIR"'
    echo "$CONDA_LINES"
    echo "$BODY" ;;
esac
