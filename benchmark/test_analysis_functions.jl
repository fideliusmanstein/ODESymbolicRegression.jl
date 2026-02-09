#!/usr/bin/env julia

# Test analysis functions on actual benchmark results

# Note: Run with julia --project=.. to use parent project

include("analyze_results.jl")

println("Testing analysis functions...")
println("=" ^ 80)

# Use latest generated files
csv_file = "benchmark_results/summary_20260209_151253.csv"
json_file = "benchmark_results/detailed_20260209_151253.json"

println("\n1. Testing analyze_benchmark_summary()...")
println("-" ^ 80)
df = analyze_benchmark_summary(csv_file)

println("\n\n2. Testing analyze_problem_details()...")
println("-" ^ 80)
analyze_problem_details(json_file, "bifeedb1")

println("\n\n3. Testing compare_runs() with two copies...")
println("-" ^ 80)
# For demo, compare the same file with itself
compare_runs(csv_file, "benchmark_results/summary_20260209_151027.csv")

println("\n" ^ 80)
println("✓ All analysis functions tested successfully!")
