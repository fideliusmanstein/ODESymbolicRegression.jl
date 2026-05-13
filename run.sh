#!/bin/bash
#SBATCH --job-name=search_noise0_03_pts250_traj20_niter500
#SBATCH --output=benchmark_output/%x_results_%j.txt
#SBATCH --error=benchmark_output/%x_errors_%j.txt
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=30
#SBATCH --time=5-00:00:00
#SBATCH --mem=6G

set -euo pipefail

# Optional: load a Julia module if your cluster requires it
# module load julia/1.9.2

# Move to the submission directory (where you ran `sbatch`),
# not the script's temporary location on the compute node.
# SLURM sets `SLURM_SUBMIT_DIR` to the directory where sbatch was invoked.
cd "${SLURM_SUBMIT_DIR:-$(pwd)}"

# Diagnostic: print cwd and a short listing to help debug failures
echo "CWD: $(pwd)";
echo "Contents:"; ls -lah . | sed -n '1,120p'

mkdir -p benchmark_results
mkdir -p benchmark_output

# Determine thread counts: prefer SLURM allocation if provided
: ${SLURM_CPUS_PER_TASK:=16}
export JULIA_NUM_THREADS=${SLURM_CPUS_PER_TASK}
export BENCHMARK_RUN_NAME="${SLURM_JOB_NAME:-local}"
export OMP_NUM_THREADS=1
export BLAS_NUM_THREADS=1

# Hyperparameters for this run
export COMBO_MODE="search"
export NOISE_STD="0.03"
export N_POINTS="250"
export NUM_TRAJECTORIES="20"
export NITER_DERIVATIVE="500"
export RESULTS_DIR="benchmark_results"

echo "Job: ${SLURM_JOB_NAME:-local} (${SLURM_JOB_ID:-n/a})"
echo "Started: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "JULIA_NUM_THREADS=$JULIA_NUM_THREADS"
echo "BLAS_NUM_THREADS=$BLAS_NUM_THREADS"
echo "OMP_NUM_THREADS=$OMP_NUM_THREADS"

# Run benchmark using project environment and requested threads
# /usr/bin/time -v reports peak RSS at the end (works regardless of SLURM memory tracking)
/usr/bin/time -v julia --project=. -t $JULIA_NUM_THREADS benchmark/benchmark.jl

echo "Finished: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"