#!/bin/bash
# sweep_sr_niter.sh
#
# Sweeps niterations_derivative over the full benchmark problem set.
#
# Fixed settings:
#   noise_std          = 0.01
#   n_points           = 250
#   num_trajectories   = 5
#   combo_mode         = search  (combination_search, niterations_integration=0)
#
# Variable:
#   niterations_derivative = (150, 300, 450, 600)
#
# Results are written to sr_niter/
#
# Usage (from repo root on the cluster):
#   bash benchmark/sweep_sr_niter.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Grid
# ---------------------------------------------------------------------------
NITER_LIST=(150 300 450 600)

# Fixed settings
NOISE="0.01"
N_POINTS="250"
N_TRAJ="5"
COMBO_MODE="search"
RESULTS_DIR="sr_niter"

# ---------------------------------------------------------------------------
# Derived counts
# ---------------------------------------------------------------------------
TOTAL=${#NITER_LIST[@]}
noise_tag=$(echo "$NOISE" | tr '.' '_')

echo "SR niterations_derivative sweep"
echo "  Noise             : $NOISE"
echo "  N points          : $N_POINTS"
echo "  Num trajectories  : $N_TRAJ"
echo "  Combo mode        : $COMBO_MODE"
echo "  Niter list        : ${NITER_LIST[*]}"
echo "  Results dir       : $RESULTS_DIR"
echo "  Total jobs        : $TOTAL"
echo ""

mkdir -p benchmark_output
mkdir -p "$RESULTS_DIR"

SUBMITTED=0
SKIPPED=0

# ---------------------------------------------------------------------------
# Submit one sbatch job per niterations_derivative value
# ---------------------------------------------------------------------------
for niter in "${NITER_LIST[@]}"; do

    job_name="sr_niter_noise${noise_tag}_pts${N_POINTS}_traj${N_TRAJ}_niter${niter}"

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

    echo "  Submitting: $job_name  (niter=$niter)"

    sbatch \
        --job-name="$job_name" \
        --output="benchmark_output/%x_results_%j.txt" \
        --error="benchmark_output/%x_errors_%j.txt" \
        --export=ALL,\
NOISE_STD="$NOISE",\
N_POINTS="$N_POINTS",\
NUM_TRAJECTORIES="$N_TRAJ",\
COMBO_MODE="$COMBO_MODE",\
NITER_DERIVATIVE="$niter",\
RESULTS_DIR="$RESULTS_DIR",\
BENCHMARK_RUN_NAME="$job_name" \
        run.sh

    (( SUBMITTED++ )) || true

done

echo ""
echo "Submitted $SUBMITTED of $TOTAL jobs ($SKIPPED skipped). Results will appear in $RESULTS_DIR/"
