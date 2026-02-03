#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

include("benchmark/benchmarkProblems/UnifiedBenchmarkSystems.jl")
using .UnifiedBenchmarkSystems

println("Testing bifeedb1 loading...")
try
    experiments = load_problem_unified("bifeedb1")
    println("✓ SUCCESS: bifeedb1 loaded")
    println("  Experiments: $(length(experiments))")
    println("  States: $(size(experiments[1][:X], 2))")
    println("  Time points: $(length(experiments[1][:t]))")
catch e
    println("✗ FAILED: $e")
    rethrow(e)
end

println("\nTesting bifeedb2 loading...")
try
    experiments = load_problem_unified("bifeedb2")
    println("✓ SUCCESS: bifeedb2 loaded")
    println("  Experiments: $(length(experiments))")
    println("  States: $(size(experiments[1][:X], 2))")
    println("  Time points: $(length(experiments[1][:t]))")
catch e
    println("✗ FAILED: $e")
    rethrow(e)
end
