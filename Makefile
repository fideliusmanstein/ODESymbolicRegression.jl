JULIA ?= julia
THREADS ?= 16
BLAS_THREADS ?= 1
OMP_NUM_THREADS ?= 1
PROJECT ?= .
SCRIPT ?= benchmark/benchmark.jl
PARALLEL_SCRIPT ?= benchmark/parallel_benchmark.jl
RESULTS_DIR ?= benchmark_results
PIDFILE := $(RESULTS_DIR)/benchmark.pid

.PHONY: help benchmark benchmark_parallel benchmark_foreground stop status logs

help:
	@echo "Makefile targets:"
	@echo "  make benchmark               # start background benchmark run (nohup)"
	@echo "  make benchmark_parallel     # start parallel_benchmark.jl similarly"
	@echo "  make benchmark_foreground   # run interactively in foreground"
	@echo "  make stop                    # stop background run (kill pidfile)"
	@echo "  make status                  # show PID and process info"
	@echo "  make logs                    # tail latest log file"


benchmark:
	@mkdir -p $(RESULTS_DIR)
	@TIMESTAMP=$$(date +"%Y%m%d_%H%M%S"); \
	LOG="$(RESULTS_DIR)/results_$$TIMESTAMP.txt"; \
	echo "Starting benchmark (background) -> $$LOG"; \
	export JULIA_NUM_THREADS=$(THREADS) && export OMP_NUM_THREADS=$(OMP_NUM_THREADS) && export BLAS_NUM_THREADS=$(BLAS_THREADS) && \
	nohup $(JULIA) --project=$(PROJECT) -t $(THREADS) $(SCRIPT) > "$$LOG" 2>&1 & echo $$! > $(PIDFILE); \
	echo "PID saved to $(PIDFILE)"


benchmark_parallel:
	@mkdir -p $(RESULTS_DIR)
	@TIMESTAMP=$$(date +"%Y%m%d_%H%M%S"); \
	LOG="$(RESULTS_DIR)/results_parallel_$$TIMESTAMP.txt"; \
	echo "Starting parallel benchmark (background) -> $$LOG"; \
	export JULIA_NUM_THREADS=$(THREADS) && export OMP_NUM_THREADS=$(OMP_NUM_THREADS) && export BLAS_NUM_THREADS=$(BLAS_THREADS) && \
	nohup $(JULIA) --project=$(PROJECT) -t $(THREADS) $(PARALLEL_SCRIPT) > "$$LOG" 2>&1 & echo $$! > $(PIDFILE); \
	echo "PID saved to $(PIDFILE)"


benchmark_foreground:
	@export JULIA_NUM_THREADS=$(THREADS); export OMP_NUM_THREADS=$(OMP_NUM_THREADS); export BLAS_NUM_THREADS=$(BLAS_THREADS); \
	echo "Running in foreground (Ctrl-C to stop)"; \
	$(JULIA) --project=$(PROJECT) -t $(THREADS) $(SCRIPT)

stop:
	@if [ -f $(PIDFILE) ]; then PID=$$(cat $(PIDFILE)); echo "Stopping PID $$PID"; kill $$PID || true; rm -f $(PIDFILE); else echo "No PID file found at $(PIDFILE)"; fi

status:
	@if [ -f $(PIDFILE) ]; then PID=$$(cat $(PIDFILE)); echo "PID: $$PID"; ps -p $$PID -o pid,etime,cmd; else echo "No PID running (no $(PIDFILE))"; fi

logs:
	@LATEST=$$(ls -1t $(RESULTS_DIR)/results_*.txt 2>/dev/null | head -n1 || true); \
	if [ -n "$$LATEST" ]; then echo "Tailing $$LATEST"; tail -n 200 "$$LATEST"; else echo "No log files found in $(RESULTS_DIR)"; fi
