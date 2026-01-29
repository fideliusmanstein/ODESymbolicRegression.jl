"""
example_savitzky_golay.jl

Example demonstrating the use of Savitzky-Golay differentiation
for ODE discovery with noisy data.
"""

include("SymbolicRegressionODE.jl")
include("benchmarkProblems/BenchmarkSystems.jl")

using .SymbolicRegressionODE
using .BenchmarkSystems

println("\n" * "="^80)
println("Comparison: Finite Differences vs Savitzky-Golay")
println("="^80)

# Load benchmark problem
experiments = BenchmarkSystems.load_problem("simpleLin1")

println("\n--- Method 1: Finite Differences (default) ---")
options_fd = ODERegressionOptions(
    differentiation_method=:finite_difference,
    niterations_derivative=5,
    niterations_integration=3,
    complexity_derivative=10,
    verbose=true
)

result_fd = discover_ode_system(experiments; ode_options=options_fd)

println("\nFinite Difference Results:")
println("Integration loss: ", result_fd.integration_loss)
for (i, tree) in enumerate(result_fd.best_trees)
    sr_opts = SymbolicRegression.Options(
        binary_operators=options_fd.binary_operators,
        unary_operators=options_fd.unary_operators
    )
    println("dx$i/dt = ", string_tree(tree, sr_opts))
end

println("\n" * "="^80)
println("\n--- Method 2: Savitzky-Golay Filter ---")
options_sg = ODERegressionOptions(
    differentiation_method=:savitzky_golay,
    savitzky_golay_window=11,      # Window size (must be odd)
    savitzky_golay_order=2,         # Polynomial order
    niterations_derivative=5,
    niterations_integration=3,
    complexity_derivative=10,
    verbose=true
)

result_sg = discover_ode_system(experiments; ode_options=options_sg)

println("\nSavitzky-Golay Results:")
println("Integration loss: ", result_sg.integration_loss)
for (i, tree) in enumerate(result_sg.best_trees)
    sr_opts = SymbolicRegression.Options(
        binary_operators=options_sg.binary_operators,
        unary_operators=options_sg.unary_operators
    )
    println("dx$i/dt = ", string_tree(tree, sr_opts))
end

println("\n" * "="^80)
println("Comparison Summary:")
println("="^80)
println("Finite Differences Loss:  ", result_fd.integration_loss)
println("Savitzky-Golay Loss:       ", result_sg.integration_loss)
println("\nNote: Savitzky-Golay is particularly useful for noisy data")
println("as it provides smoother derivative estimates.")
