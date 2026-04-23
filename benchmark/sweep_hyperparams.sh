#!/bin/bash
# sweep_hyperparams.sh
#
# Submits a grid of benchmark jobs over noise levels and n_points.
# All jobs use:
#   niterations_derivative = 150  (fixed)
#   combination_method     = knee_point  (fixed)
#   niterations_integration = 0   (no stage-2 / knee only)
#
# Results are written to hyperparameter_search/
#
# Usage (from repo root):
#   bash benchmark/sweep_hyperparams.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Hyperparameter grid
# ---------------------------------------------------------------------------
NOISE_LEVELS=(0.0 0.01 0.05)
N_POINTS_LIST=(100 250 500)
# "knee"   -> niterations_integration=100, combination_method=:knee_point
# "search" -> niterations_integration=0,   combination_method=:combination_search
COMBO_MODES=("knee" "search")
NUM_TRAJ_LIST=(1 5)

# Fixed settings
RESULTS_DIR="hyperparameter_search"

# ---------------------------------------------------------------------------
# Derived counts
# ---------------------------------------------------------------------------
N_NOISE=${#NOISE_LEVELS[@]}
N_PTS=${#N_POINTS_LIST[@]}
N_COMBO=${#COMBO_MODES[@]}
N_TRAJ=${#NUM_TRAJ_LIST[@]}
TOTAL=$(( N_NOISE * N_PTS * N_COMBO * N_TRAJ ))

echo "Hyperparameter sweep"
echo "  Noise levels      : ${NOISE_LEVELS[*]}"
echo "  N points          : ${N_POINTS_LIST[*]}"
echo "  Combo modes       : ${COMBO_MODES[*]}  (knee=knee_point+integ100 / search=combination_search+integ0)"
echo "  Num trajectories  : ${NUM_TRAJ_LIST[*]}"
echo "  Results dir       : $RESULTS_DIR"
echo "  Total jobs        : $TOTAL"
echo ""

mkdir -p benchmark_output
mkdir -p "$RESULTS_DIR"

# ---------------------------------------------------------------------------
# Submit one sbatch job per combination
# ---------------------------------------------------------------------------
for noise in "${NOISE_LEVELS[@]}"; do
    for n_pts in "${N_POINTS_LIST[@]}"; do
        for combo in "${COMBO_MODES[@]}"; do
            for n_traj in "${NUM_TRAJ_LIST[@]}"; do

                # Build a human-readable job name, e.g. hp_knee_noise0_01_pts250_traj5
                noise_tag=$(echo "$noise" | tr '.' '_')
                job_name="hp_${combo}_noise${noise_tag}_pts${n_pts}_traj${n_traj}"

                # Skip if a result file for this combination already exists
                if compgen -G "${RESULTS_DIR}/${job_name}_results_*.txt" > /dev/null 2>&1; then
                    echo "  Skipping:   $job_name  (result already exists)"
                    continue
                fi

                echo "  Submitting: $job_name  (noise=$noise, n_points=$n_pts, combo=$combo, n_traj=$n_traj)"

                sbatch \
                    --job-name="$job_name" \
                    --output="benchmark_output/%x_results_%j.txt" \
                    --error="benchmark_output/%x_errors_%j.txt" \
                    --export=ALL,NOISE_STD="$noise",N_POINTS="$n_pts",COMBO_MODE="$combo",NUM_TRAJECTORIES="$n_traj",RESULTS_DIR="$RESULTS_DIR",BENCHMARK_RUN_NAME="$job_name" \
                    run.sh

            done
        done
    done
done

echo ""
echo "All $TOTAL jobs submitted. Results will appear in $RESULTS_DIR/"
