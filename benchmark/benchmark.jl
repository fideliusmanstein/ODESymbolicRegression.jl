"""
benchmark.jl

Benchmark suite for all 63 ODE benchmark systems with multi-trajectory evaluation.

Features:
- Tests all benchmark problems with minimal configuration
- Uses multiple trajectories per experiment for robust evaluation
- Includes timeout protection for large systems
- Generates detailed test reports

Run with: julia --project=.. benchmark.jl
Or from REPL: include("benchmark/benchmark.jl")

For parallel execution, use parallel_benchmark.jl instead.
"""

# =============================================================================
# Setup and Configuration
# =============================================================================

# Activate project environment (works both from command line and REPL)
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

# Suppress progress bars and verbose output
ENV["SYMBOLIC_REGRESSION_PROGRESS"] = "false"

include("benchmark_ode_discovery.jl")
include("benchmark_reporting.jl")
using .BenchmarkSystems
using .SymbolicRegressionODE
using Dates
using Logging
using Test
using Random

# Set random seed for reproducibility
Random.seed!(42)

# Suppress ODE solver warnings
Logging.disable_logging(Logging.Warn)

# =============================================================================
# Constants and Configuration
# =============================================================================

# Custom operators
square(x) = x * x

# Test configuration - minimal for fast testing
const TEST_OPTIONS = SymbolicRegressionODE.ODERegressionOptions(
    niterations_derivative = 120,  # Use 3 for testing; 100 for production
    niterations_integration = 50,  # Use 3 for testing; 20 for production
    complexity_derivative = 15,
    complexity_integration = 15,
    binary_operators = (+, *, -, /),
    unary_operators = (square,),
    parallelism = :multithreading,  # Keep SymbolicRegression serial; use stage2 multithreading instead
    verbose = true
)

# Multi-trajectory configuration for robust evaluation
const NUM_TRAJECTORIES = 10  # Use 3 different ICs per experiment for validation
const NOISE_STD = 0.0  # Noise level for data generation (0.0 = no noise, 0.1 = 10% noise)
const MAX_PROBLEMS_TO_TEST = nothing  # Options: nothing, 5, 10, 20, etc.
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
# Helper Functions
# =============================================================================


"""
    get_test_problems()

Get list of problems to test, excluding timeout-prone ones.
Respects MAX_PROBLEMS_TO_TEST if set.
"""
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

"""
    create_result_dict(problem_name, success, loss, time, n_states; kwargs...)

Create a standardized result dictionary for a benchmark test.
"""
function create_result_dict(problem_name, success, loss, time, n_states; 
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

"""
    run_single_benchmark(problem_name, num_trajectories, noise_std)

Run discovery on a single benchmark problem with multiple trajectories.
Returns a result dictionary with success status and metrics.
"""
function run_single_benchmark(problem_name, num_trajectories, noise_std)
    println("  Loading problem with $num_trajectories trajectories per experiment, noise_std=$noise_std...")
    
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

"""
    run_with_timeout(problem_name, num_trajectories, noise_std, timeout_seconds)

Run benchmark test with timeout protection.
If timeout_seconds is nothing, runs without timeout.

Returns:
- (completed::Bool, result::Dict): Whether test finished and the results
"""
function run_with_timeout(problem_name, num_trajectories, noise_std, timeout_seconds)
    timeout_msg = timeout_seconds === nothing ? "no timeout" : "$(timeout_seconds)s"
    println("Testing: $problem_name (timeout: $timeout_msg, trajectories: $num_trajectories, noise: $noise_std)")
    
    # If no timeout, run directly
    if timeout_seconds === nothing
        result = run_single_benchmark(problem_name, num_trajectories, noise_std)
        return (true, result)
    end
    
    # Run with timeout protection
    result_channel = Channel{Dict}(1)
    
    # Launch async task
    task = @async begin
        result = run_single_benchmark(problem_name, num_trajectories, noise_std)
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
# Main Test Execution
# =============================================================================

# Get test problems
problems = get_test_problems()

# Print header
print_test_header(problems, TEST_OPTIONS, NUM_TRAJECTORIES, NOISE_STD, MAX_PROBLEMS_TO_TEST, TIMEOUT_SECONDS)

# Setup results file
results_dir = "benchmark_results"
mkpath(results_dir)
results_file = joinpath(results_dir, "results_$(Dates.format(now(), "yyyymmdd_HHMMSS")).txt")
results_summary = Dict{String, Dict}()

# Write header to file
    open(results_file, "w") do f
    write_file_header(f, TEST_OPTIONS, NUM_TRAJECTORIES, NOISE_STD, MAX_PROBLEMS_TO_TEST, TIMEOUT_SECONDS, TIMEOUT_PROBLEMS)
end

# Run all tests
@testset "ODE Discovery - All Benchmark Systems" begin
    for problem_name in problems.testable
        @testset "$problem_name" begin
            # Run test with timeout protection
            completed, result = run_with_timeout(
                problem_name,
                NUM_TRAJECTORIES,
                NOISE_STD,
                TIMEOUT_SECONDS
            )
            
            # Store result
            results_summary[problem_name] = result
            
            # Write to file immediately
            open(results_file, "a") do f
                write_result_to_file(f, result)
            end
            
            # Print diagnostics for failures
            if !result["success"]
                print_failure_diagnostics(problem_name, result)
            end
            
            # Print equation similarity analysis (for both success and failure)
            print_equation_similarity(result)
            
            # Test assertion (skip if timeout)
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

# Append a global end timestamp so the results file clearly marks when benchmarking finished
open(results_file, "a") do f
    println(f)
    println(f, "End: $(Dates.now())")
    flush(f)
end
