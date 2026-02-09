#!/usr/bin/env julia

# Test script to verify new CSV/JSON save functionality

using Pkg
Pkg.activate(".")

include("benchmark_ode_discovery.jl")

println("Testing new benchmark save formats...")
println("=" ^ 60)

# Run benchmark on a single small problem
target_problem = "bifeedb1"  # Small 2-state system

println("Running benchmark on problem: $target_problem")
all_results = benchmark_all_problems(
    problem_filter = name -> name == target_problem,
    save_results = true
)

println("\n✓ Benchmark complete!")
println("\nGenerated files should be in benchmark_results/:")
println("  - summary_*.csv")
println("  - detailed_*.json")
println("  - results_*.txt")

# Check if files were created
using Dates
files = readdir("../benchmark_results", join=false)
timestamp = Dates.format(now(), "yyyymmdd")

csv_files = filter(f -> startswith(f, "summary_") && contains(f, timestamp), files)
json_files = filter(f -> startswith(f, "detailed_") && contains(f, timestamp), files)
txt_files = filter(f -> startswith(f, "results_") && contains(f, timestamp), files)

println("\nFound files from today:")
println("  CSV: ", length(csv_files))
println("  JSON: ", length(json_files))
println("  TXT: ", length(txt_files))

if length(csv_files) > 0
    latest_csv = sort(csv_files)[end]
    println("\nLatest CSV: ", latest_csv)
    
    # Try to load and display first few lines
    using CSV, DataFrames
    df = CSV.read("../benchmark_results/$latest_csv", DataFrame)
    println("\nCSV Preview:")
    println(df)
end

if length(json_files) > 0
    latest_json = sort(json_files)[end]
    println("\nLatest JSON: ", latest_json)
    
    # Try to load and display structure
    using JSON
    data = JSON.parsefile("../benchmark_results/$latest_json")
    println("\nJSON contains $(length(data)) result(s)")
    if length(data) > 0
        first_result = data[1]
        println("First result keys: ", keys(first_result))
    end
end

println("\n✓ Save format test complete!")
