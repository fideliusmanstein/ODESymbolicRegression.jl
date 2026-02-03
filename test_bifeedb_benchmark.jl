#!/usr/bin/env julia

# Simple direct test of bifeedb1

import Pkg
Pkg.activate(".")

include("benchmark/benchmark_ode_discovery.jl")
include("benchmark/benchmarkProblems/UnifiedBenchmarkSystems.jl")

using .SymbolicRegressionODE

println("=" ^ 80)
println("Testing bifeedb1 Problem")
println("=" ^ 80)

test_options = ODERegressionOptions(
    binary_operators = (+, -, *, /),
    unary_operators = (SymbolicRegression.square,),
    maxsize = 20,
    niterations_derivative = 3,
    niterations_integration = 3,
    verbose = true
)

try
    println("\nAttempting to benchmark bifeedb1...")
    result = benchmark_single_problem(
        "bifeedb1",
        ode_options=test_options,
        num_trajectories=1
    )
    
    println("\n" * "=" ^ 80)
    println("RESULT:")
    println("  Success: $(result["success"])")
    println("  Integration Loss: $(result["integration_loss"])")
    println("  Time: $(result["discovery_time"]) seconds")
    println("  States: $(result["n_states"])")
    println("=" ^ 80)
    
catch e
    println("\nERROR: $e")
    showerror(stdout, e, catch_backtrace())
    println()
end
