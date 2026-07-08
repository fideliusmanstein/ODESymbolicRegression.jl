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
# Problem split
# ---------------------------------------------------------------------------
# ss_5genes4 and threeGenes1 dominate total runtime (~85% combined, based on
# the niter150 baseline run). Splitting them into a separate "hard" batch lets
# the "fast" batch (the other 20 problems) finish quickly for early results,
# while the hard batch runs longer in the background. Merge both batches'
# results afterward for the full 22-problem picture.
#
# NOTE: problem names below are semicolon-separated, NOT comma-separated.
# `sbatch --export=ALL,VAR=val,...` itself splits its whole argument on
# commas, so a comma-joined list here would get silently truncated to just
# its first entry once passed through --export. benchmark.jl's
# PROBLEMS_OVERRIDE parser splits on ";" to match.
HARD_PROBLEMS="ss_5genes4;threeGenes1"
FAST_PROBLEMS="bifeedb1;bifeedb2;cytokine1;feedf1;gma_bifeedb1;gma_feedf1;gma_inhosc1;inhosc1;inhosc2;metabol1;osc1;simpleFb1;simpleLin2;ss_bifeedb1;ss_branch2;ss_cadBA1;ss_cascade1;ss_ethanolferm1;ss_feedf1;ss_inhosc1"

# ---------------------------------------------------------------------------
# Derived counts
# ---------------------------------------------------------------------------
TOTAL=$(( ${#NITER_LIST[@]} * 2 ))
noise_tag=$(echo "$NOISE" | tr '.' '_')

echo "SR niterations_derivative sweep (split into fast/hard batches)"
echo "  Noise             : $NOISE"
echo "  N points          : $N_POINTS"
echo "  Num trajectories  : $N_TRAJ"
echo "  Combo mode        : $COMBO_MODE"
echo "  Niter list        : ${NITER_LIST[*]}"
echo "  Fast problems     : $FAST_PROBLEMS"
echo "  Hard problems     : $HARD_PROBLEMS"
echo "  Results dir       : $RESULTS_DIR"
echo "  Total jobs        : $TOTAL"
echo ""

mkdir -p benchmark_output
mkdir -p "$RESULTS_DIR"

SUBMITTED=0
SKIPPED=0

# ---------------------------------------------------------------------------
# Submit one sbatch job per (niterations_derivative, batch) combination
# ---------------------------------------------------------------------------
for niter in "${NITER_LIST[@]}"; do
    for batch in fast hard; do

        if [[ "$batch" == "fast" ]]; then
            problems="$FAST_PROBLEMS"
        else
            problems="$HARD_PROBLEMS"
        fi

        job_name="sr_niter_noise${noise_tag}_pts${N_POINTS}_traj${N_TRAJ}_niter${niter}_${batch}"

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

        echo "  Submitting: $job_name  (niter=$niter, batch=$batch)"

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
PROBLEMS_OVERRIDE="$problems",\
BENCHMARK_RUN_NAME="$job_name" \
            run.sh

        (( SUBMITTED++ )) || true

    done
done

echo ""
echo "Submitted $SUBMITTED of $TOTAL jobs ($SKIPPED skipped). Results will appear in $RESULTS_DIR/"
