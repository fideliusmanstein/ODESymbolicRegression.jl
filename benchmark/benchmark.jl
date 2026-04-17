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
inv(x) = 1 / x
sqrtp(x::T) where {T} = x > 0 ? sqrt(x) : T(NaN)

# Single protected power operator: powc(x, c)
# Accepts any finite exponent c.
@inline function powc(x::Real, c::Real)
    xf = Float64(x)
    cf = Float64(c)
    if !isfinite(xf) || !isfinite(cf)
        return NaN
    end

    if xf < 0.0 || (xf == 0.0 && cf < 0.0)
        return NaN
    end

    y = exp(cf * log(xf))
    return isfinite(y) ? y : NaN
end

# Test configuration - minimal for fast testing
const TEST_OPTIONS = SymbolicRegressionODE.ODERegressionOptions(
    niterations_derivative = 150,
    niterations_integration = 0,
    complexity_derivative = 15,
    complexity_integration = 15,
    binary_operators = (+, *, -, /), # powc
    unary_operators = (square, inv, sqrtp),
    parallelism = :multithreading,  # Keep SymbolicRegression serial; use stage2 multithreading instead
    combination_method = :combination_search,  # :combination_search or :knee_point
    verbose = true
)

# Multi-trajectory configuration for robust evaluation
# NUM_TRAJECTORIES is the exact number of experiment trajectories passed to the solver.
# Predefined experiments from the problem definition are used first (up to NUM_TRAJECTORIES);
# if the problem has fewer, the remainder are filled with perturbed copies of existing ICs.
const NUM_TRAJECTORIES = 5
const NOISE_STD = 0.01  # Noise level for data generation (0.0 = no noise, 0.1 = 10% noise)
const N_POINTS = 251  # Time points per trajectory (nothing = use each problem's default)
const MAX_PROBLEMS_TO_TEST = nothing  # Options: nothing, 5, 10, 20, etc.
const TIMEOUT_SECONDS = nothing  # Options: nothing, 60, 180, 300, etc.
const PROBLEMS_OVERRIDE = nothing # Set to e.g. ["ss_5genes8"] or nothing

# Problems that timeout with minimal config (too many variables/experiments)
const TIMEOUT_PROBLEMS = [
    "ss_15genes1",   # 15 states, 10-20 experiments
    "ss_15genes2",
    "ss_30genes1",   # 30 states, 8-20 experiments, up to 41 time points
    "ss_30genes2",
    "ss_30genes3",
    "ss_clock1",
    "ss_clock2",
    "ss_sosrepair1",  # 6 states, slow
    "ss_sosrepair2",  # 6 states, slow
    # "ss_cascade3",  # TODO: this problem gets stuck on the server. Figure out why
    # "ss_5genes8",
    # "ss_5genes6", # these two take really long
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

    # If PROBLEMS_OVERRIDE is set, run only those problems
    if PROBLEMS_OVERRIDE !== nothing
        testable_problems = filter(p -> p in PROBLEMS_OVERRIDE, all_problems_full)
        return (
            all = all_problems_full,
            testable = testable_problems,
            excluded = TIMEOUT_PROBLEMS
        )
    end

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
    get_nonredundant_problems()

Automatically selects one representative problem per structural group,
choosing the variant with the most pre-defined experiments within each group.

Grouping key: (family_prefix, n_states [, points_per_exp])
- family_prefix and n_states are always part of the key: variants with different
  state-space sizes (e.g. inhosc1=2 states vs inhosc2=4 states) are structurally
  distinct and always kept separately.
- points_per_exp is included in the key only when N_POINTS === nothing, i.e. when
  each problem uses its own native time resolution. In that case variants with
  different point counts differ in the information they carry and are kept separately
  (e.g. ss_branch1=21 pts vs ss_branch2=51 pts).
  When N_POINTS is set to a concrete value all variants receive the same resolution,
  so point-count differences become irrelevant and are not used for grouping.

Within each group the variant with the most pre-defined experiments is selected,
giving the best real-data coverage before perturbed copies are needed.
TIMEOUT_PROBLEMS are excluded before selection.
"""
function get_nonredundant_problems()
    all_problems_dict = BenchmarkSystems.list_problems()
    all_problems_full = sort(collect(keys(all_problems_dict)))

    # If PROBLEMS_OVERRIDE is set, run only those problems
    if PROBLEMS_OVERRIDE !== nothing
        testable_problems = filter(p -> p in PROBLEMS_OVERRIDE, all_problems_full)
        return (
            all = all_problems_full,
            testable = testable_problems,
            excluded = TIMEOUT_PROBLEMS
        )
    end

    # Exclude timeout problems before selection
    candidates = filter(p -> !(p in TIMEOUT_PROBLEMS), all_problems_full)

    # Extract the family prefix by stripping the trailing digit(s)
    family_prefix(name) = match(r"^(.*?)\d+$", name)[1]

    # Build grouping key.
    # When N_POINTS is nothing each variant keeps its native time resolution, so
    # variants with different points_per_exp are structurally distinct and get
    # separate groups (and are therefore both selected).
    # When N_POINTS is overridden all variants use the same resolution, so
    # points_per_exp is not part of the key and only the best-experiment variant
    # survives per (family, n_states) pair.
    function group_key(p)
        info    = all_problems_dict[p]
        prefix  = family_prefix(p)
        n_state = info[:states]
        if N_POINTS === nothing
            return (prefix, n_state, info[:points_per_exp])
        else
            return (prefix, n_state, 0)   # 0 collapses all point counts into one group
        end
    end

    groups = Dict{Tuple{String,Int,Int}, Vector{String}}()
    for p in candidates
        key = group_key(p)
        push!(get!(groups, key, String[]), p)
    end

    # Within each group pick the variant with the most pre-defined experiments
    selected = String[]
    for (_, probs) in groups
        best = argmax(p -> all_problems_dict[p][:experiments], probs)
        push!(selected, best)
    end

    testable_problems = sort(selected)

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
function run_single_benchmark(problem_name, num_trajectories, noise_std, n_points=nothing)
    println("  Loading problem with $num_trajectories trajectories per experiment, noise_std=$noise_std...")
    
    try
        result = benchmark_single_problem(
            problem_name,
            ode_options = TEST_OPTIONS,
            num_trajectories = num_trajectories,
            noise_std = noise_std,
            n_points = n_points
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
function run_with_timeout(problem_name, num_trajectories, noise_std, timeout_seconds, n_points=nothing)
    timeout_msg = timeout_seconds === nothing ? "no timeout" : "$(timeout_seconds)s"
    println("Testing: $problem_name (timeout: $timeout_msg, trajectories: $num_trajectories, noise: $noise_std)")
    
    # If no timeout, run directly
    if timeout_seconds === nothing
        result = run_single_benchmark(problem_name, num_trajectories, noise_std, n_points)
        return (true, result)
    end
    
    # Run with timeout protection
    result_channel = Channel{Dict}(1)
    
    # Launch async task
    task = @async begin
        result = run_single_benchmark(problem_name, num_trajectories, noise_std, n_points)
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
problems = get_nonredundant_problems()

# Print header
print_test_header(problems, TEST_OPTIONS, NUM_TRAJECTORIES, NOISE_STD, MAX_PROBLEMS_TO_TEST, TIMEOUT_SECONDS, N_POINTS, PROBLEMS_OVERRIDE)

# Setup results file
results_dir = "benchmark_results"
mkpath(results_dir)
run_name = get(ENV, "BENCHMARK_RUN_NAME", "benchmark")
results_file = joinpath(results_dir, "$(run_name)_results_$(Dates.format(now(), "yyyymmdd_HHMMSS")).txt")
results_summary = Dict{String, Dict}()

# Write header to file
    open(results_file, "w") do f
    write_file_header(f, TEST_OPTIONS, NUM_TRAJECTORIES, NOISE_STD, MAX_PROBLEMS_TO_TEST, TIMEOUT_SECONDS, TIMEOUT_PROBLEMS, N_POINTS, PROBLEMS_OVERRIDE)
end

# Run all tests
@testset "ODE Discovery - All Benchmark Systems" begin
    for problem_name in problems.testable
        @testset "$problem_name" begin
            # Write start marker immediately so the file shows which problem is running
            open(results_file, "a") do f
                println(f, "")
                println(f, "="^80)
                println(f, "STARTED: $problem_name  [$(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))]")
                println(f, "="^80)
                flush(f)
            end

            # Run test with timeout protection
            completed, result = run_with_timeout(
                problem_name,
                NUM_TRAJECTORIES,
                NOISE_STD,
                TIMEOUT_SECONDS,
                N_POINTS
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
