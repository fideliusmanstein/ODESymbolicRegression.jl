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
# Additional trajectory-focused runs are written to additional_hs_searches/
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

# Additional trajectory-focused experiments
ADDITIONAL_RESULTS_DIR="additional_hs_searches"
ADDITIONAL_NOISE="0.01"
ADDITIONAL_N_POINTS_LIST=(100 250 500)
ADDITIONAL_NUM_TRAJ_LIST=(5 10 20)
ADDITIONAL_COMBO="knee"
ADDITIONAL_COMPLEXITY_LIST=(10 15 20)

# ---------------------------------------------------------------------------
# Derived counts
# ---------------------------------------------------------------------------
N_NOISE=${#NOISE_LEVELS[@]}
N_PTS=${#N_POINTS_LIST[@]}
N_COMBO=${#COMBO_MODES[@]}
N_TRAJ=${#NUM_TRAJ_LIST[@]}
TOTAL=$(( N_NOISE * N_PTS * N_COMBO * N_TRAJ ))

N_ADDITIONAL_PTS=${#ADDITIONAL_N_POINTS_LIST[@]}
N_ADDITIONAL_TRAJ=${#ADDITIONAL_NUM_TRAJ_LIST[@]}
N_ADDITIONAL_CX=${#ADDITIONAL_COMPLEXITY_LIST[@]}
ADDITIONAL_TOTAL=$(( N_ADDITIONAL_PTS * N_ADDITIONAL_TRAJ * N_ADDITIONAL_CX ))

echo "Hyperparameter sweep"
echo "  Noise levels      : ${NOISE_LEVELS[*]}"
echo "  N points          : ${N_POINTS_LIST[*]}"
echo "  Combo modes       : ${COMBO_MODES[*]}  (knee=knee_point+integ100 / search=combination_search+integ0)"
echo "  Num trajectories  : ${NUM_TRAJ_LIST[*]}"
echo "  Results dir       : $RESULTS_DIR"
echo "  Total jobs        : $TOTAL"
echo ""
echo "Additional trajectory sweep"
echo "  Noise level       : $ADDITIONAL_NOISE"
echo "  N points          : ${ADDITIONAL_N_POINTS_LIST[*]}"
echo "  Combo mode        : $ADDITIONAL_COMBO"
echo "  Num trajectories  : ${ADDITIONAL_NUM_TRAJ_LIST[*]}"
echo "  Complexity values : ${ADDITIONAL_COMPLEXITY_LIST[*]}"
echo "  Results dir       : $ADDITIONAL_RESULTS_DIR"
echo "  Total jobs        : $ADDITIONAL_TOTAL"
echo ""

mkdir -p benchmark_output
mkdir -p "$RESULTS_DIR"
mkdir -p "$ADDITIONAL_RESULTS_DIR"

SKIPPED=0
ADDITIONAL_SKIPPED=0

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
                    (( SKIPPED++ )) || true
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

# ---------------------------------------------------------------------------
# Submit additional trajectory-focused jobs
# ---------------------------------------------------------------------------
for n_pts in "${ADDITIONAL_N_POINTS_LIST[@]}"; do
    for n_traj in "${ADDITIONAL_NUM_TRAJ_LIST[@]}"; do
        for cx in "${ADDITIONAL_COMPLEXITY_LIST[@]}"; do

            noise_tag=$(echo "$ADDITIONAL_NOISE" | tr '.' '_')
            job_name="hp_traj_${ADDITIONAL_COMBO}_noise${noise_tag}_pts${n_pts}_traj${n_traj}_cx${cx}"

            if compgen -G "${ADDITIONAL_RESULTS_DIR}/${job_name}_results_*.txt" > /dev/null 2>&1; then
                echo "  Skipping:   $job_name  (result already exists)"
                (( ADDITIONAL_SKIPPED++ )) || true
                continue
            fi

            echo "  Submitting: $job_name  (noise=$ADDITIONAL_NOISE, n_points=$n_pts, combo=$ADDITIONAL_COMBO, n_traj=$n_traj, complexity=$cx)"

            sbatch \
                --job-name="$job_name" \
                --output="benchmark_output/%x_results_%j.txt" \
                --error="benchmark_output/%x_errors_%j.txt" \
                --export=ALL,NOISE_STD="$ADDITIONAL_NOISE",N_POINTS="$n_pts",COMBO_MODE="$ADDITIONAL_COMBO",NUM_TRAJECTORIES="$n_traj",COMPLEXITY="$cx",RESULTS_DIR="$ADDITIONAL_RESULTS_DIR",BENCHMARK_RUN_NAME="$job_name" \
                run.sh

        done
    done
done

echo ""
echo "Submitted $(( TOTAL - SKIPPED )) of $TOTAL base jobs ($SKIPPED skipped). Results will appear in $RESULTS_DIR/"
echo "Submitted $(( ADDITIONAL_TOTAL - ADDITIONAL_SKIPPED )) of $ADDITIONAL_TOTAL additional jobs ($ADDITIONAL_SKIPPED skipped). Results will appear in $ADDITIONAL_RESULTS_DIR/"
