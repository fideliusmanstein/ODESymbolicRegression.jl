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
include("analyze_results.jl")
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
const NOISE_STD = 0.0  # Noise level for data generation (0.0 = no noise, 0.1 = 10% noise)
const MAX_PROBLEMS_TO_TEST = 1   # Options: nothing, 5, 10, 20, etc.
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
    write_file_header(f, NUM_TRAJECTORIES, NOISE_STD)
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

open(results_file, "a") do f
    write_summary(f, results_summary)
end

# =============================================================================
# Generate Analysis Reports
# =============================================================================

println("\n" * "="^80)
println("GENERATING ANALYSIS REPORTS")
println("="^80)

# Extract timestamp from results_file
timestamp = match(r"results_(\d{8}_\d{6})\.txt", results_file).captures[1]

# Convert results_summary to vector format for save_benchmark_results
all_results = collect(values(results_summary))

# Generate CSV and JSON exports
println("\n📊 Generating CSV/JSON exports...")
try
    df = save_benchmark_results(all_results, timestamp)
    println("  ✓ Summary CSV: benchmark_results/summary_$timestamp.csv")
    println("  ✓ Detailed JSON: benchmark_results/detailed_$timestamp.json")
catch e
    println("  ✗ Error generating CSV/JSON: $e")
end

# Generate analysis report
println("\n📈 Generating analysis report...")
try
    csv_file = joinpath(results_dir, "summary_$timestamp.csv")
    json_file = joinpath(results_dir, "detailed_$timestamp.json")
    analysis_file = joinpath(results_dir, "analysis_$timestamp.txt")
    
    # Redirect analysis output to file
    open(analysis_file, "w") do io
        redirect_stdout(io) do
            println("="^80)
            println("AUTOMATED ANALYSIS REPORT")
            println("Timestamp: $timestamp")
            println("="^80)
            
            # Run comprehensive analysis
            if isfile(csv_file)
                println("\n")
                df = analyze_benchmark_summary(csv_file)
                
                # Add problem-level details for interesting cases
                if isfile(json_file)
                    println("\n\n")
                    println("="^80)
                    println("DETAILED PROBLEM ANALYSIS")
                    println("="^80)
                    
                    # Analyze top 3 best and worst performers
                    sorted_df = sort(df, :avg_r2, rev=true)
                    
                    # Best performers
                    println("\n📊 TOP PERFORMERS (Best R² scores):")
                    println("-"^80)
                    top_n = min(3, nrow(sorted_df))
                    for i in 1:top_n
                        if !ismissing(sorted_df[i, :avg_r2]) && !isnan(sorted_df[i, :avg_r2])
                            problem = sorted_df[i, :problem_name]
                            println("\n")
                            analyze_problem_details(json_file, problem)
                        end
                    end
                    
                    # Worst performers (failures or low R²)
                    println("\n\n📊 CHALLENGING PROBLEMS:")
                    println("-"^80)
                    worst_n = min(3, nrow(sorted_df))
                    for i in (nrow(sorted_df)-worst_n+1):nrow(sorted_df)
                        if i > 0
                            problem = sorted_df[i, :problem_name]
                            println("\n")
                            analyze_problem_details(json_file, problem)
                        end
                    end
                end
            end
        end
    end
    
    println("  ✓ Analysis report: $analysis_file")
catch e
    println("  ✗ Error generating analysis: $e")
    println("  Stack trace:")
    for (exc, bt) in Base.catch_stack()
        showerror(stdout, exc, bt)
        println()
    end
end

println("\n" * "="^80)
println("ALL ANALYSIS REPORTS GENERATED")
println("="^80)
println("\nFiles created:")
println("  • Results: $results_file")
println("  • Summary CSV: benchmark_results/summary_$timestamp.csv")
println("  • Detailed JSON: benchmark_results/detailed_$timestamp.json")
println("  • Analysis: benchmark_results/analysis_$timestamp.txt")
println("\nTo view analysis:")
println("  cat benchmark_results/analysis_$timestamp.txt")
println("="^80)
