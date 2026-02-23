JULIA ?= julia
THREADS ?= 32
BLAS_THREADS ?= 1
OMP_NUM_THREADS ?= 1
PROJECT ?= .
SCRIPT ?= benchmark/benchmark.jl
RESULTS_DIR ?= benchmark_results
JOBFILE := $(RESULTS_DIR)/benchmark.jobid

.PHONY: help benchmark stop status logs queue

help:
	@echo "Makefile targets:"
	@echo "  make benchmark            # submit benchmark via SLURM (uses run.sh)"
	@echo "  make stop                 # cancel submitted SLURM job (uses $(JOBFILE))"
	@echo "  make status               # show SLURM job status for submitted job"
	@echo "  make queue                # show your active SLURM jobs (squeue -u)"
	@echo "  make logs                 # tail SLURM/benchmark output for job"


# Submit benchmark job to SLURM using `sbatch`. The job id is written to $(JOBFILE).
benchmark:
	@mkdir -p $(RESULTS_DIR)
	@echo "Submitting benchmark job to SLURM..."
	@# Use --parsable to return only the jobid; override cpus-per-task with THREADS
	@JOBID=$$(sbatch --parsable --cpus-per-task=$(THREADS) --output=$(RESULTS_DIR)/results_%x_%j.txt run.sh); \
	if [ -n "$$JOBID" ]; then echo $$JOBID > $(JOBFILE); echo "Submitted job $$JOBID (saved to $(JOBFILE))"; else echo "Failed to submit job"; exit 1; fi


stop:
	@if [ -f $(JOBFILE) ]; then JOBID=$$(cat $(JOBFILE)); echo "Cancelling job $$JOBID"; scancel $$JOBID || true; rm -f $(JOBFILE); else echo "No job file found at $(JOBFILE)"; fi

status:
	@if [ -f $(JOBFILE) ]; then JOBID=$$(cat $(JOBFILE)); echo "Job: $$JOBID"; squeue -j $$JOBID -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %R"; else echo "No job file found at $(JOBFILE)"; fi

logs:
	@JOBID=$$(cat $(JOBFILE) 2>/dev/null || true); \
	if [ -n "$$JOBID" ]; then LATEST=$$(ls -1t $(RESULTS_DIR)/results_*_$$JOBID.txt 2>/dev/null | head -n1 || true); fi; \
	if [ -n "$$LATEST" ]; then echo "Tailing $$LATEST"; tail -n 200 "$$LATEST"; else echo "No log file found for job $$JOBID in $(RESULTS_DIR)"; fi

queue:
	@echo "Active SLURM jobs for user $$USER:"; \
	squeue -u $$USER -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %R"
