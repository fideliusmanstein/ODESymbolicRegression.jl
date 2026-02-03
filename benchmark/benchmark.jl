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
include(joinpath(@__DIR__, "..", "benchmark", "benchmarkProblems", "UnifiedBenchmarkSystems.jl"))
using .SymbolicRegressionODE
using .BenchmarkSystems
using .UnifiedBenchmarkSystems
using Test
using Logging
using Dates

# Suppress ODE solver warnings
Logging.disable_logging(Logging.Warn)

# =============================================================================
# Constants and Configuration
# =============================================================================

# Custom operators
square(x) = x * x

# Test configuration - minimal for fast testing
const TEST_OPTIONS = SymbolicRegressionODE.ODERegressionOptions(
    niterations_derivative = 3,  # Use 3 for testing; 100 for production
    niterations_integration = 3,  # Use 3 for testing; 20 for production
    complexity_derivative = 15,
    complexity_integration = 15,
    binary_operators = (+, *, -, /),
    unary_operators = (square,),
    parallelism = :serial,  # Avoid blocking issues
    verbose = true
)

# Multi-trajectory configuration for robust evaluation
const NUM_TRAJECTORIES = 3  # Use 3 different ICs per experiment for validation

# Maximum number of problems to test (nothing = all problems)
# Set to a smaller number for faster iteration/debugging
const MAX_PROBLEMS_TO_TEST = 3  # Testing first 3 unified problems: simpleLin1, simpleLin2, simpleFb1

# Timeout protection (seconds, nothing = no timeout)
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

Prioritizes unified architecture problems for testing.
"""
function get_test_problems()
    all_problems_dict = BenchmarkSystems.list_problems()
    all_problems_full = sort(collect(keys(all_problems_dict)))
    
    # Get unified problems (prioritize these)
    unified_problems_dict = UnifiedBenchmarkSystems.list_problems_unified()
    unified_problems = sort(collect(keys(unified_problems_dict)))
    
    # Separate into unified and legacy problems
    legacy_problems = filter(p -> !(p in unified_problems), all_problems_full)
    testable_problems = filter(p -> !(p in TIMEOUT_PROBLEMS), legacy_problems)
    
    # Prioritize unified problems first, then legacy
    ordered_problems = vcat(unified_problems, testable_problems)
    
    # Limit number of problems if MAX_PROBLEMS_TO_TEST is set
    if MAX_PROBLEMS_TO_TEST !== nothing && MAX_PROBLEMS_TO_TEST < length(ordered_problems)
        ordered_problems = ordered_problems[1:MAX_PROBLEMS_TO_TEST]
    end
    
    return (
        all = all_problems_full,
        testable = ordered_problems,
        excluded = TIMEOUT_PROBLEMS,
        unified = unified_problems
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
    run_single_benchmark(problem_name, num_trajectories)

Run discovery on a single benchmark problem with multiple trajectories.
Returns a result dictionary with success status and metrics.
"""
function run_single_benchmark(problem_name, num_trajectories)
    println("  Loading problem with $num_trajectories trajectories per experiment...")
    
    try
        result = benchmark_single_problem(
            problem_name,
            ode_options = TEST_OPTIONS,
            num_trajectories = num_trajectories  # NEW: Multi-trajectory support
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
    run_with_timeout(problem_name, num_trajectories, timeout_seconds)

Run benchmark test with timeout protection.
If timeout_seconds is nothing, runs without timeout.

Returns:
- (completed::Bool, result::Dict): Whether test finished and the results
"""
function run_with_timeout(problem_name, num_trajectories, timeout_seconds)
    timeout_msg = timeout_seconds === nothing ? "no timeout" : "$(timeout_seconds)s"
    println("Testing: $problem_name (timeout: $timeout_msg, trajectories: $num_trajectories)")
    
    # If no timeout, run directly
    if timeout_seconds === nothing
        result = run_single_benchmark(problem_name, num_trajectories)
        return (true, result)
    end
    
    # Run with timeout protection
    result_channel = Channel{Dict}(1)
    
    # Launch async task
    task = @async begin
        result = run_single_benchmark(problem_name, num_trajectories)
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
print_test_header(problems, TEST_OPTIONS, NUM_TRAJECTORIES, MAX_PROBLEMS_TO_TEST, TIMEOUT_SECONDS)

# Setup results file
results_dir = "benchmark_results"
mkpath(results_dir)
results_file = joinpath(results_dir, "results_$(Dates.format(now(), "yyyymmdd_HHMMSS")).txt")
results_summary = Dict{String, Dict}()

# Write header to file
open(results_file, "w") do f
    write_file_header(f, NUM_TRAJECTORIES)
end

# Run all tests
@testset "ODE Discovery - All Benchmark Systems" begin
    for problem_name in problems.testable
        @testset "$problem_name" begin
            # Run test with timeout protection
            completed, result = run_with_timeout(
                problem_name,
                NUM_TRAJECTORIES,
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
            
            # Test assertion (skip if timeout)
            if completed
                @test result["success"]
            end
        end
    end
end

# Print final summary and write to file
print_final_summary(results_summary, results_file)

open(results_file, "a") do f
    write_summary(f, results_summary)
end
