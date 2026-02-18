"""
parallel_benchmark.jl

Parallel version of the benchmark suite using Distributed.jl.
Runs each benchmark problem on a separate worker process for maximum throughput.

Features:
- Distributes problems across all available CPU cores
- Clean progress output without clutter
- Reuses all logic from benchmark.jl
- Ideal for running full benchmark suites

Run with: julia --project=.. parallel_benchmark.jl
Or from REPL: include("benchmark/parallel_benchmark.jl")

For quick iteration, use benchmark.jl instead (no parallel overhead).
"""

# =============================================================================
# Setup Parallel Processing
# =============================================================================

# Activate project environment
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using Distributed

# Add worker processes (use all available cores minus 1 for main process)
if nprocs() == 1
    n_workers = max(1, Sys.CPU_THREADS - 1)
    println("Setting up parallel execution...")
    println("Adding $n_workers worker processes...")
    addprocs(n_workers)
end

# Load benchmark infrastructure on main process first
include("benchmark_ode_discovery.jl")
include("benchmark_reporting.jl")

# Load required packages on all workers
println("Loading packages on $(nworkers()) workers (this may take 30-60 seconds)...")
@everywhere begin
    import Pkg
    Pkg.activate(joinpath(@__DIR__, ".."))
    
    # Suppress progress bars and verbose output
    ENV["SYMBOLIC_REGRESSION_PROGRESS"] = "false"
    
    include(joinpath(@__DIR__, "benchmark_ode_discovery.jl"))
    include(joinpath(@__DIR__, "benchmark_reporting.jl"))
    using .BenchmarkSystems
    using .SymbolicRegressionODE
    using Dates
    using Logging
    using Random
    using Printf
    
    # Suppress ODE solver warnings on all workers
    Logging.disable_logging(Logging.Warn)
    
    # Define square operator on all workers
    square(x) = x * x
end

# On main process
using .BenchmarkSystems
using .SymbolicRegressionODE
using Dates
using Logging
using Test
using Random
using Printf

# Suppress ODE solver warnings
Logging.disable_logging(Logging.Warn)

println("Workers ready!\n")

# =============================================================================
# Constants and Configuration (same as benchmark.jl)
# =============================================================================

# Custom operators
square(x) = x * x

# Test configuration - defined on all workers for consistency
@everywhere const TEST_OPTIONS = SymbolicRegressionODE.ODERegressionOptions(
    niterations_derivative = 3,  # Use 3 for testing; 100 for production
    niterations_integration = 3,  # Use 3 for testing; 20 for production
    complexity_derivative = 15,
    complexity_integration = 15,
    binary_operators = (+, *, -, /),
    unary_operators = (square,),
    parallelism = :serial,  # Keep serial within each problem to avoid nested parallelism
    verbose = false  # Disable verbose output for clean parallel execution
)

# Multi-trajectory configuration for robust evaluation
const NUM_TRAJECTORIES = 10  # Use 3 different ICs per experiment for validation
const NOISE_STD = 0.0  # Noise level for data generation (0.0 = no noise, 0.1 = 10% noise)
const MAX_PROBLEMS_TO_TEST = 5  # Options: nothing, 5, 10, 20, etc.
const TIMEOUT_SECONDS = nothing  # Options: nothing, 60, 180, 300, etc.

# Problems that timeout with minimal config (too many variables/experiments)
const TIMEOUT_PROBLEMS = [
    "ss_15genes1",   # 15 states, 10-20 experiments
    "ss_15genes2",
    "ss_30genes1",   # 30 states, 8-20 experiments, up to 41 time points
    "ss_30genes2",
    "ss_30genes3"
]

# =============================================================================
# Parallel Worker Functions
# =============================================================================

@everywhere function create_result_dict(problem_name, success, loss, time, n_states; 
                           error=nothing, timeout=false, kwargs...)
    result = Dict(
        "problem_name" => problem_name,
        "success" => success,
        "integration_loss" => loss,
        "discovery_time" => time,
        "n_states" => n_states,
        "timeout" => timeout,
        "error" => error
    )
    
    # Add any additional fields
    for (key, value) in kwargs
        result[string(key)] = value
    end
    
    return result
end

@everywhere function run_single_benchmark_parallel(problem_name, num_trajectories, noise_std, worker_seed=42)
    # Set worker-specific random seed for reproducibility
    Random.seed!(worker_seed + hash(problem_name))
    
    println("[→] Starting $problem_name on worker $(myid())...")
    
    try
        result = benchmark_single_problem(
            problem_name,
            ode_options = TEST_OPTIONS,
            num_trajectories = num_trajectories,
            noise_std = noise_std
        )
        return result
        
    catch e
        # Handle errors gracefully
        return create_result_dict(
            problem_name,
            false,  # success
            Inf,    # loss
            0.0,    # time
            0,      # n_states
            error = string(e)
        )
    end
end

@everywhere function run_with_timeout_parallel(problem_name, num_trajectories, noise_std, timeout_seconds, worker_seed=42)
    # If no timeout, run directly
    if timeout_seconds === nothing
        result = run_single_benchmark_parallel(problem_name, num_trajectories, noise_std, worker_seed)
        return (true, result)
    end
    
    # Run with timeout protection
    result_channel = Channel{Dict}(1)
    
    # Launch async task
    task = @async begin
        result = run_single_benchmark_parallel(problem_name, num_trajectories, noise_std, worker_seed)
        put!(result_channel, result)
    end
    
    # Wait with timeout
    status = timedwait(() -> isready(result_channel), timeout_seconds; pollint=1.0)
    
    if status == :ok
        # Completed successfully
        result = take!(result_channel)
        return (true, result)
    else
        # Timeout - interrupt task
        println("  ⏱ TIMEOUT after $(timeout_seconds)s")
        try
            schedule(task, InterruptException(), error=true)
        catch
        end
        
        timeout_result = create_result_dict(
            problem_name,
            false,  # success
            Inf,    # loss
            Float64(timeout_seconds),  # time
            0,      # n_states
            timeout = true
        )
        
        return (false, timeout_result)
    end
end

# =============================================================================
# Helper Functions (main process)
# =============================================================================

function get_test_problems()
    all_problems_dict = BenchmarkSystems.list_problems()
    all_problems_full = sort(collect(keys(all_problems_dict)))
    testable_problems = filter(p -> !(p in TIMEOUT_PROBLEMS), all_problems_full)
    
    # Limit number of problems if MAX_PROBLEMS_TO_TEST is set
    if MAX_PROBLEMS_TO_TEST !== nothing && MAX_PROBLEMS_TO_TEST < length(testable_problems)
        testable_problems = testable_problems[1:MAX_PROBLEMS_TO_TEST]
    end
    
    return (
        all = all_problems_full,
        testable = testable_problems,
        excluded = TIMEOUT_PROBLEMS
    )
end

# =============================================================================
# Main Parallel Execution
# =============================================================================

# Get test problems
problems = get_test_problems()

# Print header
print_test_header(problems, TEST_OPTIONS, NUM_TRAJECTORIES, NOISE_STD, MAX_PROBLEMS_TO_TEST, TIMEOUT_SECONDS)

# Setup results file
results_dir = "benchmark_results"
mkpath(results_dir)
results_file = joinpath(results_dir, "results_parallel_$(Dates.format(now(), "yyyymmdd_HHMMSS")).txt")
results_summary = Dict{String, Dict}()

# Write header to file
open(results_file, "w") do f
    write_file_header(f, NUM_TRAJECTORIES, NOISE_STD)
    println(f, "Parallel execution on $(nworkers()) workers")
    println(f, "="^80)
    println(f)
end

# Run all tests in parallel
println("\n" * "="^80)
println("Starting parallel benchmark execution on $(nworkers()) workers...")
println("="^80)

start_time = time()

# Use pmap for parallel execution with progress tracking
results_list = pmap(problems.testable) do problem_name
    # Each worker runs one problem at a time
    completed, result = run_with_timeout_parallel(
        problem_name,
        NUM_TRAJECTORIES,
        NOISE_STD,
        TIMEOUT_SECONDS,
        42  # base seed for reproducibility
    )
    
    # Print concise progress (one line per problem)
    status_symbol = result["success"] ? "✓" : "✗"
    loss_str = result["integration_loss"] == Inf ? "FAIL" : @sprintf("%.2e", result["integration_loss"])
    time_str = @sprintf("%.1fs", result["discovery_time"])
    println("[$status_symbol] $problem_name: loss=$loss_str, time=$time_str (worker=$(myid()))")
    
    return (problem_name, completed, result)
end

total_time = time() - start_time

println("\n" * "="^80)
println("Parallel execution completed in $(round(total_time, digits=1))s")
println("="^80)

# Collect results into summary dictionary
for (problem_name, completed, result) in results_list
    results_summary[problem_name] = result
    
    # Write to file
    open(results_file, "a") do f
        write_result_to_file(f, result)
    end
end

# Run test assertions after all results are collected
@testset "ODE Discovery - All Benchmark Systems (Parallel)" begin
    for (problem_name, completed, result) in results_list
        @testset "$problem_name" begin
            if completed
                @test result["success"]
            end
        end
    end
end

# Print final summary and write to file
print_final_summary(results_summary, results_file)

# Save machine-readable formats
json_file = replace(results_file, ".txt" => ".json")
csv_file = replace(results_file, ".txt" => ".csv")

println("Saving results to:")
println("  - JSON: $json_file")
println("  - CSV:  $csv_file")

save_results_json(json_file, results_summary)
save_results_csv(csv_file, results_summary)

open(results_file, "a") do f
    write_summary(f, results_summary)
end
