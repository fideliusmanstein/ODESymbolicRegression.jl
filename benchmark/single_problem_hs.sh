#!/bin/bash
# single_problem_hs.sh
#
# Submits a hyperparameter grid for a single benchmark problem: ss_5genes4
#
# Grid:
#   n_points              = (100, 250, 500)
#   n_trajectories        = (5, 10, 15, 20)
#   noise_std             = (0.0, 0.01, 0.03, 0.05)
#   niterations_derivative = (150, 250, 500)
#
# Fixed settings:
#   problem               = ss_5genes4
#   combination_method    = knee_point or combination_search
#   niterations_integration = 0         (no stage-2 refinement)
#   operator_set          = square_inv  → binary=(+,-,*,/), unary=(square,inv)
#   complexity            = 15
#
# Total jobs: 2 x 3 x 4 x 4 x 3 = 288
#
# Runtime estimate (based on ss_5genes4 @ n_pts=100, n_traj=1, niter=150 → ~63s):
#   Time scales as ~63s * (n_pts/100) * n_traj * (niter/150)
#   Fastest job  (n_pts=100, n_traj=5,  niter=150): ~5 min
#   Median job   (n_pts=250, n_traj=10, niter=250): ~42 min
#   Slowest job  (n_pts=500, n_traj=20, niter=500): ~6 hours
#   Total compute: ~340 CPU-hours
#   Wall time if all 144 jobs run in parallel: ~6 hours
#
# Usage (from repo root):
#   bash benchmark/single_problem_hs.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Hyperparameter grid
# ---------------------------------------------------------------------------
PROBLEM="ss_5genes4"
N_POINTS_LIST=(100 250 500)
NUM_TRAJ_LIST=(5 10 15 20)
NOISE_LEVELS=(0.0 0.01 0.03 0.05)
NITER_DERIV_LIST=(150 250 500)

# Fixed settings
COMBO_MODES=(knee0 search)   # knee_point and combination_search, both with niterations_integration=0
OPERATOR_SET="square_inv"   # binary=(+,-,*,/), unary=(square,inv)  — no sqrtp, no powc
COMPLEXITY=15
RESULTS_DIR="single_problem_hs"

# ---------------------------------------------------------------------------
# Derived counts
# ---------------------------------------------------------------------------
N_MODES=${#COMBO_MODES[@]}
N_PTS=${#N_POINTS_LIST[@]}
N_TRAJ=${#NUM_TRAJ_LIST[@]}
N_NOISE=${#NOISE_LEVELS[@]}
N_NITER=${#NITER_DERIV_LIST[@]}
TOTAL=$(( N_MODES * N_PTS * N_TRAJ * N_NOISE * N_NITER ))

echo "Single-problem hyperparameter search"
echo "  Problem           : $PROBLEM"
echo "  Combo modes       : ${COMBO_MODES[*]}"
echo "  N points          : ${N_POINTS_LIST[*]}"
echo "  Num trajectories  : ${NUM_TRAJ_LIST[*]}"
echo "  Noise levels      : ${NOISE_LEVELS[*]}"
echo "  Niter derivative  : ${NITER_DERIV_LIST[*]}"
echo "  Operator set      : $OPERATOR_SET  (+,-,*,/, square, inv)"
echo "  Complexity        : $COMPLEXITY"
echo "  Results dir       : $RESULTS_DIR"
echo "  Total jobs        : $TOTAL"
echo ""

mkdir -p benchmark_output
mkdir -p "$RESULTS_DIR"

SUBMITTED=0
SKIPPED=0

# ---------------------------------------------------------------------------
# Submit one sbatch job per combination
# ---------------------------------------------------------------------------
for combo_mode in "${COMBO_MODES[@]}"; do
    for n_pts in "${N_POINTS_LIST[@]}"; do
        for n_traj in "${NUM_TRAJ_LIST[@]}"; do
            for noise in "${NOISE_LEVELS[@]}"; do
                for niter in "${NITER_DERIV_LIST[@]}"; do

                    noise_tag=$(echo "$noise" | tr '.' '_')
                    job_name="sp_${PROBLEM}_${combo_mode}_noise${noise_tag}_pts${n_pts}_traj${n_traj}_niter${niter}"
                    legacy_job_name="sp_${PROBLEM}_noise${noise_tag}_pts${n_pts}_traj${n_traj}_niter${niter}"

                    # Skip if a result file for this combination already exists.
                    has_results=0
                    if compgen -G "${RESULTS_DIR}/${job_name}_results_*.txt" > /dev/null 2>&1 || \
                       compgen -G "${RESULTS_DIR}/${job_name}_results_*.json" > /dev/null 2>&1 || \
                       compgen -G "${RESULTS_DIR}/${job_name}_results_*.csv" > /dev/null 2>&1; then
                        has_results=1
                    fi

                    # Backward-compatibility: earlier knee0 runs used names without combo mode.
                    if [[ "$combo_mode" == "knee0" ]]; then
                        if compgen -G "${RESULTS_DIR}/${legacy_job_name}_results_*.txt" > /dev/null 2>&1 || \
                           compgen -G "${RESULTS_DIR}/${legacy_job_name}_results_*.json" > /dev/null 2>&1 || \
                           compgen -G "${RESULTS_DIR}/${legacy_job_name}_results_*.csv" > /dev/null 2>&1; then
                            has_results=1
                        fi
                    fi

                    if [[ $has_results -eq 1 ]]; then
                        echo "  Skipping:   $job_name  (result already exists)"
                        (( SKIPPED++ )) || true
                        continue
                    fi

                    # Skip if the job is already submitted or running under the same name.
                    # NOTE: squeue exits 0 even when there are no matches, so we must test output.
                    if command -v squeue >/dev/null 2>&1; then
                        queue_match=$(squeue -h -u "${USER:-$(whoami)}" -n "$job_name" | head -n 1 || true)
                        if [[ -z "$queue_match" && "$combo_mode" == "knee0" ]]; then
                            queue_match=$(squeue -h -u "${USER:-$(whoami)}" -n "$legacy_job_name" | head -n 1 || true)
                        fi
                        if [[ -n "$queue_match" ]]; then
                            echo "  Skipping:   $job_name  (already in queue)"
                            (( SKIPPED++ )) || true
                            continue
                        fi
                    fi

                    echo "  Submitting: $job_name"

                    sbatch \
                        --job-name="$job_name" \
                        --output="benchmark_output/%x_results_%j.txt" \
                        --error="benchmark_output/%x_errors_%j.txt" \
                        --export=ALL,\
NOISE_STD="$noise",\
N_POINTS="$n_pts",\
NUM_TRAJECTORIES="$n_traj",\
NITER_DERIVATIVE="$niter",\
COMBO_MODE="$combo_mode",\
OPERATOR_SET="$OPERATOR_SET",\
COMPLEXITY="$COMPLEXITY",\
PROBLEMS_OVERRIDE="$PROBLEM",\
RESULTS_DIR="$RESULTS_DIR",\
BENCHMARK_RUN_NAME="$job_name" \
                        run.sh

                    (( SUBMITTED++ )) || true

                done
            done
        done
    done
done

echo ""
echo "Submitted $SUBMITTED of $TOTAL jobs ($SKIPPED skipped). Results will appear in $RESULTS_DIR/"
