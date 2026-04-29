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

# Additional structured hyperparameter searches (3 independent groups, 21 jobs total)
# Medium fixed values: noise=0.01, n_points=250, n_traj=10, cx=15, niter=150, ops=standard
# All groups use combo_mode=knee
ADDITIONAL_RESULTS_DIR="additional_hs_searches"
ADDITIONAL_NOISE="0.01"
ADDITIONAL_COMBO="knee"

# Group 1: n_points x n_trajectories  (9 jobs)
G1_N_POINTS=(100 250 500)
G1_N_TRAJ=(5 10 20)

# Group 2: complexity x niterations_derivative  (9 jobs)
G2_COMPLEXITY=(10 15 20)
G2_NITER=(100 150 200)

# Group 3: operator sets  (3 jobs)
G3_OPS=("standard" "powc_only" "powc_full")

# ---------------------------------------------------------------------------
# Derived counts
# ---------------------------------------------------------------------------
N_NOISE=${#NOISE_LEVELS[@]}
N_PTS=${#N_POINTS_LIST[@]}
N_COMBO=${#COMBO_MODES[@]}
N_TRAJ=${#NUM_TRAJ_LIST[@]}
TOTAL=$(( N_NOISE * N_PTS * N_COMBO * N_TRAJ ))

N_ADDITIONAL_G1=$(( ${#G1_N_POINTS[@]} * ${#G1_N_TRAJ[@]} ))
N_ADDITIONAL_G2=$(( ${#G2_COMPLEXITY[@]} * ${#G2_NITER[@]} ))
N_ADDITIONAL_G3=${#G3_OPS[@]}
ADDITIONAL_TOTAL=$(( N_ADDITIONAL_G1 + N_ADDITIONAL_G2 + N_ADDITIONAL_G3 ))

echo "Hyperparameter sweep"
echo "  Noise levels      : ${NOISE_LEVELS[*]}"
echo "  N points          : ${N_POINTS_LIST[*]}"
echo "  Combo modes       : ${COMBO_MODES[*]}  (knee=knee_point+integ100 / search=combination_search+integ0)"
echo "  Num trajectories  : ${NUM_TRAJ_LIST[*]}"
echo "  Results dir       : $RESULTS_DIR"
echo "  Total jobs        : $TOTAL"
echo ""
echo "Additional hyperparameter searches (3 groups)"
echo "  Noise level       : $ADDITIONAL_NOISE"
echo "  Combo mode        : $ADDITIONAL_COMBO"
echo "  Results dir       : $ADDITIONAL_RESULTS_DIR"
echo "  Group 1 (pts x traj) : pts=${G1_N_POINTS[*]}, traj=${G1_N_TRAJ[*]}  ($N_ADDITIONAL_G1 jobs)"
echo "  Group 2 (cx x niter) : cx=${G2_COMPLEXITY[*]}, niter=${G2_NITER[*]}  ($N_ADDITIONAL_G2 jobs)"
echo "  Group 3 (ops)        : ${G3_OPS[*]}  ($N_ADDITIONAL_G3 jobs)"
echo "  Total additional jobs: $ADDITIONAL_TOTAL"
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
# Group 1: n_points x n_trajectories  (fix cx=15, niter=150, ops=standard)
# ---------------------------------------------------------------------------
echo ""
echo "Group 1: n_points x n_trajectories"
for n_pts in "${G1_N_POINTS[@]}"; do
    for n_traj in "${G1_N_TRAJ[@]}"; do

        noise_tag=$(echo "$ADDITIONAL_NOISE" | tr '.' '_')
        job_name="hp_g1_noise${noise_tag}_pts${n_pts}_traj${n_traj}"

        if compgen -G "${ADDITIONAL_RESULTS_DIR}/${job_name}_results_*.txt" > /dev/null 2>&1; then
            echo "  Skipping:   $job_name  (result already exists)"
            (( ADDITIONAL_SKIPPED++ )) || true
            continue
        fi

        echo "  Submitting: $job_name  (pts=$n_pts, traj=$n_traj)"

        sbatch \
            --job-name="$job_name" \
            --output="benchmark_output/%x_results_%j.txt" \
            --error="benchmark_output/%x_errors_%j.txt" \
            --export=ALL,NOISE_STD="$ADDITIONAL_NOISE",N_POINTS="$n_pts",COMBO_MODE="$ADDITIONAL_COMBO",NUM_TRAJECTORIES="$n_traj",COMPLEXITY=15,NITER_DERIVATIVE=150,OPERATOR_SET=standard,RESULTS_DIR="$ADDITIONAL_RESULTS_DIR",BENCHMARK_RUN_NAME="$job_name" \
            run.sh

    done
done

# ---------------------------------------------------------------------------
# Group 2: complexity x niterations_derivative  (fix pts=250, traj=10, ops=standard)
# ---------------------------------------------------------------------------
echo ""
echo "Group 2: complexity x niter_derivative"
for cx in "${G2_COMPLEXITY[@]}"; do
    for niter in "${G2_NITER[@]}"; do

        noise_tag=$(echo "$ADDITIONAL_NOISE" | tr '.' '_')
        job_name="hp_g2_noise${noise_tag}_cx${cx}_niter${niter}"

        if compgen -G "${ADDITIONAL_RESULTS_DIR}/${job_name}_results_*.txt" > /dev/null 2>&1; then
            echo "  Skipping:   $job_name  (result already exists)"
            (( ADDITIONAL_SKIPPED++ )) || true
            continue
        fi

        echo "  Submitting: $job_name  (cx=$cx, niter=$niter)"

        sbatch \
            --job-name="$job_name" \
            --output="benchmark_output/%x_results_%j.txt" \
            --error="benchmark_output/%x_errors_%j.txt" \
            --export=ALL,NOISE_STD="$ADDITIONAL_NOISE",N_POINTS=250,COMBO_MODE="$ADDITIONAL_COMBO",NUM_TRAJECTORIES=10,COMPLEXITY="$cx",NITER_DERIVATIVE="$niter",OPERATOR_SET=standard,RESULTS_DIR="$ADDITIONAL_RESULTS_DIR",BENCHMARK_RUN_NAME="$job_name" \
            run.sh

    done
done

# ---------------------------------------------------------------------------
# Group 3: operator sets  (fix pts=250, traj=10, cx=15, niter=150)
# ---------------------------------------------------------------------------
echo ""
echo "Group 3: operator sets"
for ops in "${G3_OPS[@]}"; do

    noise_tag=$(echo "$ADDITIONAL_NOISE" | tr '.' '_')
    job_name="hp_g3_noise${noise_tag}_ops_${ops}"

    if compgen -G "${ADDITIONAL_RESULTS_DIR}/${job_name}_results_*.txt" > /dev/null 2>&1; then
        echo "  Skipping:   $job_name  (result already exists)"
        (( ADDITIONAL_SKIPPED++ )) || true
        continue
    fi

    echo "  Submitting: $job_name  (ops=$ops)"

    sbatch \
        --job-name="$job_name" \
        --output="benchmark_output/%x_results_%j.txt" \
        --error="benchmark_output/%x_errors_%j.txt" \
        --export=ALL,NOISE_STD="$ADDITIONAL_NOISE",N_POINTS=250,COMBO_MODE="$ADDITIONAL_COMBO",NUM_TRAJECTORIES=10,COMPLEXITY=15,NITER_DERIVATIVE=150,OPERATOR_SET="$ops",RESULTS_DIR="$ADDITIONAL_RESULTS_DIR",BENCHMARK_RUN_NAME="$job_name" \
        run.sh

done

echo ""
echo "Submitted $(( TOTAL - SKIPPED )) of $TOTAL base jobs ($SKIPPED skipped). Results will appear in $RESULTS_DIR/"
echo "Submitted $(( ADDITIONAL_TOTAL - ADDITIONAL_SKIPPED )) of $ADDITIONAL_TOTAL additional jobs ($ADDITIONAL_SKIPPED skipped). Results will appear in $ADDITIONAL_RESULTS_DIR/"
