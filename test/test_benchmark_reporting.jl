"""
test_benchmark_reporting.jl

Verifies that JSON and CSV output files are produced even when some benchmark
problems fail with a crash/exception (i.e. when @testset throws TestSetException).

Success = execution completed without error. Poor equation quality does NOT count
as failure — only actual crashes or timeouts do.

Run with: julia --project=. test/test_benchmark_reporting.jl
"""

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

include(joinpath(@__DIR__, "../benchmark/benchmark_ode_discovery.jl"))
include(joinpath(@__DIR__, "../benchmark/benchmark_reporting.jl"))

using .BenchmarkSystems
using .SymbolicRegressionODE
using Dates
using Test
using Random
using JSON
using Logging

Random.seed!(42)
Logging.disable_logging(Logging.Warn)

# =============================================================================
# Minimal options — fast enough for a smoke test
# =============================================================================

square(x) = x * x
inv_op(x) = 1 / x

const SMOKE_OPTIONS = SymbolicRegressionODE.ODERegressionOptions(
    niterations_derivative  = 3,
    niterations_integration = 0,
    complexity_derivative   = 8,
    complexity_integration  = 8,
    binary_operators        = (+, *, -),
    unary_operators         = (square, inv_op),
    parallelism             = :multithreading,
    combination_method      = :knee_point,
    verbose                 = false
)

# =============================================================================
# Pick one real problem that will always complete (even with bad equations),
# plus one synthetic "problem" that will crash to simulate a failure.
# =============================================================================
PROBLEMS_TO_RUN = ["simpleLin2", "__nonexistent_problem__"]

# =============================================================================
# Replicate the benchmark.jl reporting flow
# =============================================================================

tmpdir = mktempdir(; cleanup=false)
results_file = joinpath(tmpdir, "test_results_$(Dates.format(now(), "yyyymmdd_HHMMSS")).txt")
json_file    = replace(results_file, ".txt" => ".json")
csv_file     = replace(results_file, ".txt" => ".csv")

results_summary = Dict{String, Dict}()

problems_stub = (
    all      = PROBLEMS_TO_RUN,
    testable = PROBLEMS_TO_RUN,
    excluded = String[]
)

open(results_file, "w") do f
    write_file_header(f, SMOKE_OPTIONS, 1, 0.0, nothing, nothing, String[])
end

try
    @testset "Smoke: reporting survives failures" begin
        for problem_name in PROBLEMS_TO_RUN
            @testset "$problem_name" begin
                open(results_file, "a") do f
                    println(f, "\nSTARTED: $problem_name")
                    flush(f)
                end

                result = try
                    benchmark_single_problem(
                        problem_name;
                        ode_options      = SMOKE_OPTIONS,
                        num_trajectories = 1,
                        noise_std        = 0.0,
                        n_points         = 20
                    )
                catch e
                    # Execution error (crash) → success = false
                    Dict(
                        "problem_name"    => problem_name,
                        "success"         => false,
                        "integration_loss"=> Inf,
                        "discovery_time"  => 0.0,
                        "n_states"        => 0,
                        "timeout"         => false,
                        "error"           => string(e)
                    )
                end

                results_summary[problem_name] = result

                open(results_file, "a") do f
                    write_result_to_file(f, result)
                end

                # Crashes set success=false and trigger TestSetException —
                # exactly the scenario we want to survive.
                @test result["success"]
            end
        end
    end
catch e
    if e isa Test.TestSetException
        @warn "Some tests failed (expected) — continuing with export" n_failed=e.fail
    else
        rethrow(e)
    end
end

# =============================================================================
# Export — this is what we're actually testing
# =============================================================================

print_final_summary(results_summary, results_file)
save_results_json(json_file, results_summary)
save_results_csv(csv_file,  results_summary)

open(results_file, "a") do f
    println(f, "\nEnd: $(Dates.now())")
    flush(f)
end

# =============================================================================
# Assertions
# =============================================================================

@testset "Reporting files are produced after failures" begin
    @test isfile(json_file)
    @test isfile(csv_file)
    @test filesize(json_file) > 0
    @test filesize(csv_file)  > 0

    # Both problems should appear in the JSON (read as text to tolerate NaN/Inf)
    json_text = read(json_file, String)
    for p in PROBLEMS_TO_RUN
        @test occursin(p, json_text)
    end

    println("\n=== Reporting test PASSED ===")
    println("  JSON : $json_file  ($(filesize(json_file)) bytes)")
    println("  CSV  : $csv_file   ($(filesize(csv_file)) bytes)")
end
