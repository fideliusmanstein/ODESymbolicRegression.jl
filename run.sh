#!/bin/bash
#SBATCH --job-name=ode-benchmark
#SBATCH --output=benchmark_results/results_%x_%j.txt
#SBATCH --error=benchmark_results/errors_%x_%j.txt
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=2-00:00:00
#SBATCH --mem=32G

set -euo pipefail

# Optional: load a Julia module if your cluster requires it
# module load julia/1.9.2

# Move to repository root (assumes run.sh is in repo root)
cd "$(dirname "$0")"

mkdir -p benchmark_results

# Determine thread counts: prefer SLURM allocation if provided
: ${SLURM_CPUS_PER_TASK:=16}
export JULIA_NUM_THREADS=${SLURM_CPUS_PER_TASK}
export OMP_NUM_THREADS=1
export BLAS_NUM_THREADS=1

echo "Job: ${SLURM_JOB_NAME:-local} (${SLURM_JOB_ID:-n/a})"
echo "Started: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "JULIA_NUM_THREADS=$JULIA_NUM_THREADS"
echo "BLAS_NUM_THREADS=$BLAS_NUM_THREADS"
echo "OMP_NUM_THREADS=$OMP_NUM_THREADS"

# Run benchmark using project environment and requested threads
julia --project=. -t $JULIA_NUM_THREADS benchmark/benchmark.jl

echo "Finished: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"