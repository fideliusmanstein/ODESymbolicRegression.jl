"""
example_ode_discovery.jl

Example script demonstrating symbolic regression for ODE discovery
using the benchmark problems.
"""

include("../src/SymbolicRegressionODE.jl")
include("../benchmark/benchmarkProblems/BenchmarkSystems.jl")

using .SymbolicRegressionODE
using .BenchmarkSystems

# Example 1: Simple Linear System (simpleLin1)
println("\n" * "="^80)
println("Example 1: Simple Linear System (simpleLin1)")
println("="^80)

# Load benchmark problem
experiments_simple = BenchmarkSystems.load_problem("simpleLin1")

# Configure options for fast testing
options_simple = ODERegressionOptions(
    niterations_derivative=5,  # Increase for better results (e.g., 20-50)
    niterations_integration=3,  # Increase for better results (e.g., 10-20)
    complexity_derivative=10,
    complexity_integration=8,
    parallelism=:multithreading,
    verbose=true
)

# Discover ODE system
result_simple = discover_ode_system(experiments_simple; ode_options=options_simple)

println("\n" * "="^80)
println("FINAL RESULT - Simple Linear System")
println("="^80)
println("Integration loss: ", result_simple.integration_loss)
for (i, tree) in enumerate(result_simple.best_trees)
    sr_opts = SymbolicRegression.Options(
        binary_operators=options_simple.binary_operators,
        unary_operators=options_simple.unary_operators
    )
    println("dx$i/dt = ", string_tree(tree, sr_opts))
end


# Example 2: S-System Cascade (ss_cascade1)
println("\n\n" * "="^80)
println("Example 2: S-System Cascade (ss_cascade1)")
println("="^80)

experiments_cascade = BenchmarkSystems.load_problem("ss_cascade1")

# Configure for more complex system
options_cascade = ODERegressionOptions(
    niterations_derivative=10,
    niterations_integration=5,
    complexity_derivative=12,
    complexity_integration=10,
    parallelism=:multithreading,
    verbose=true
)

result_cascade = discover_ode_system(experiments_cascade; ode_options=options_cascade)

println("\n" * "="^80)
println("FINAL RESULT - S-System Cascade")
println("="^80)
println("Integration loss: ", result_cascade.integration_loss)
for (i, tree) in enumerate(result_cascade.best_trees)
    sr_opts = SymbolicRegression.Options(
        binary_operators=options_cascade.binary_operators,
        unary_operators=options_cascade.unary_operators
    )
    println("dx$i/dt = ", string_tree(tree, sr_opts))
end


# Example 3: Using different operators
println("\n\n" * "="^80)
println("Example 3: Custom Operators - Oscillator System")
println("="^80)

experiments_osc = BenchmarkSystems.load_problem("osc1")

# Include square and logarithm operators
options_custom = ODERegressionOptions(
    binary_operators=(+, *, -, /, ^),
    unary_operators=(cos, sin, exp, log),
    niterations_derivative=8,
    niterations_integration=4,
    complexity_derivative=15,
    complexity_integration=12,
    parallelism=:multithreading,
    verbose=true
)

result_osc = discover_ode_system(experiments_osc; ode_options=options_custom)

println("\n" * "="^80)
println("FINAL RESULT - Oscillator System")
println("="^80)
println("Integration loss: ", result_osc.integration_loss)
for (i, tree) in enumerate(result_osc.best_trees)
    sr_opts = SymbolicRegression.Options(
        binary_operators=options_custom.binary_operators,
        unary_operators=options_custom.unary_operators
    )
    println("dx$i/dt = ", string_tree(tree, sr_opts))
end


println("\n\n" * "="^80)
println("Available Benchmark Problems")
println("="^80)
println("You can test with any of these problems:")
problems = BenchmarkSystems.list_problems()
for (name, desc) in sort(collect(problems))[1:10]  # Show first 10
    println("  - $name: $desc")
end
println("  ... and $(length(problems) - 10) more!")
println("\nUsage: experiments = BenchmarkSystems.load_problem(\"problem_name\")")
println("="^80)
