#!/bin/bash
# sweep_sr_niter_per_problem.sh
#
# Per-problem parallel variant of sweep_sr_niter.sh. Instead of one SLURM
# job running all 22 problems sequentially (or a fast/hard 2-way split),
# this submits one SLURM job PER PROBLEM. Each job only needs to hold one
# problem's compute, so many can run concurrently on the same node
# (node has far more cores than a single job's --cpus-per-task uses).
#
# Results are written to sr_niter_per_problem/, one csv/json/txt triple per
# (niter, problem) pair. Use merge_sr_niter_per_problem.py afterward to
# combine all 22 problems for a given niter value into one result file.
#
# Usage (from repo root on the cluster):
#   bash benchmark/sweep_sr_niter_per_problem.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Grid
# ---------------------------------------------------------------------------
NITER_LIST=(150 300 450 600)

# Fixed settings (must match sweep_sr_niter.sh for a valid comparison)
NOISE="0.01"
N_POINTS="250"
N_TRAJ="5"
COMBO_MODE="search"
RESULTS_DIR="sr_niter_per_problem"

# Full 22-problem set (fast + hard, matching sweep_sr_niter.sh's split)
PROBLEMS=(
    bifeedb1 bifeedb2 cytokine1 feedf1 gma_bifeedb1 gma_feedf1 gma_inhosc1
    inhosc1 inhosc2 metabol1 osc1 simpleFb1 simpleLin2 ss_bifeedb1
    ss_branch2 ss_cadBA1 ss_cascade1 ss_ethanolferm1 ss_feedf1 ss_inhosc1
    ss_5genes4 threeGenes1
)

# Cores per job. Each problem only needs its own thread budget, not the
# whole node -- lower this (e.g. to 8) to fit more concurrent jobs on one
# node if the scheduler queues them instead of running them side by side.
CPUS_PER_TASK=8

# Memory per job. run.sh's own #SBATCH default is 6G, but observed actual
# usage per problem is ~2G RSS (checked via `ps aux` while jobs were
# running) -- SLURM packs jobs by what they RESERVE, not what they actually
# use, so requesting the full 6G was capping concurrency at ~12-13 jobs on a
# 93G node even though real usage was only ~29G. 3G leaves ~50% headroom
# over observed peak for problems with more states.
MEM_PER_TASK="3G"

# ---------------------------------------------------------------------------
# Derived counts
# ---------------------------------------------------------------------------
TOTAL=$(( ${#NITER_LIST[@]} * ${#PROBLEMS[@]} ))
noise_tag=$(echo "$NOISE" | tr '.' '_')

echo "SR niterations_derivative sweep -- per-problem parallel variant"
echo "  Noise             : $NOISE"
echo "  N points          : $N_POINTS"
echo "  Num trajectories  : $N_TRAJ"
echo "  Combo mode        : $COMBO_MODE"
echo "  Niter list        : ${NITER_LIST[*]}"
echo "  Problems          : ${#PROBLEMS[@]} (one job each)"
echo "  Cpus per job      : $CPUS_PER_TASK"
echo "  Results dir       : $RESULTS_DIR"
echo "  Total jobs        : $TOTAL"
echo ""

mkdir -p benchmark_output
mkdir -p "$RESULTS_DIR"

SUBMITTED=0
SKIPPED=0

# ---------------------------------------------------------------------------
# Submit one sbatch job per (niterations_derivative, problem) combination
# ---------------------------------------------------------------------------
for niter in "${NITER_LIST[@]}"; do
    for problem in "${PROBLEMS[@]}"; do

        job_name="sr_niter_noise${noise_tag}_pts${N_POINTS}_traj${N_TRAJ}_niter${niter}_${problem}"

        # Skip if result already exists
        if compgen -G "${RESULTS_DIR}/${job_name}_results_*.txt"  > /dev/null 2>&1 || \
           compgen -G "${RESULTS_DIR}/${job_name}_results_*.json" > /dev/null 2>&1 || \
           compgen -G "${RESULTS_DIR}/${job_name}_results_*.csv"  > /dev/null 2>&1; then
            echo "  Skipping:   $job_name  (result already exists)"
            (( SKIPPED++ )) || true
            continue
        fi

        # Skip if already queued
        if command -v squeue >/dev/null 2>&1; then
            queue_match=$(squeue -h -u "${USER:-$(whoami)}" -n "$job_name" | head -n 1 || true)
            if [[ -n "$queue_match" ]]; then
                echo "  Skipping:   $job_name  (already in queue)"
                (( SKIPPED++ )) || true
                continue
            fi
        fi

        echo "  Submitting: $job_name  (niter=$niter, problem=$problem)"

        sbatch \
            --job-name="$job_name" \
            --cpus-per-task="$CPUS_PER_TASK" \
            --mem="$MEM_PER_TASK" \
            --output="benchmark_output/%x_results_%j.txt" \
            --error="benchmark_output/%x_errors_%j.txt" \
            --export=ALL,\
NOISE_STD="$NOISE",\
N_POINTS="$N_POINTS",\
NUM_TRAJECTORIES="$N_TRAJ",\
COMBO_MODE="$COMBO_MODE",\
NITER_DERIVATIVE="$niter",\
RESULTS_DIR="$RESULTS_DIR",\
PROBLEMS_OVERRIDE="$problem",\
BENCHMARK_RUN_NAME="$job_name" \
            run.sh

        (( SUBMITTED++ )) || true

    done
done

echo ""
echo "Submitted $SUBMITTED of $TOTAL jobs ($SKIPPED skipped). Results will appear in $RESULTS_DIR/"
echo "Once all jobs for a niter value finish, merge with:"
echo "  python3 benchmark/merge_sr_niter_per_problem.py --niter 450 --results-dir $RESULTS_DIR --out sr_niter_merged/sr_niter_niter450_merged.csv"
