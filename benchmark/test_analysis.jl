"""
Test the new benchmark analysis functions.
"""

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

# Load analysis tools
include("analyze_results.jl")

println("\n✓ Analysis tools loaded successfully!")
println("\nYou can now run:")
println("  • df = analyze_benchmark_summary(\"benchmark_results/summary_TIMESTAMP.csv\")")
println("  • analyze_problem_details(\"benchmark_results/detailed_TIMESTAMP.json\", \"problem_name\")")
println("  • compare_runs(\"file1.csv\", \"file2.csv\")")
