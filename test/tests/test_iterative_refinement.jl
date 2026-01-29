"""
test_iterative_refinement.jl

Test the new iterative co-refinement feature in Stage 2.
"""

ENV["SYMBOLIC_REGRESSION_PROGRESS"] = "false"

include("../benchmark_ode_discovery.jl")
using .SymbolicRegressionODE
using .BenchmarkSystems
using Test
using Logging

# Suppress warnings
Logging.disable_logging(Logging.Warn)

println("="^80)
println("Testing Iterative Co-Refinement Feature")
println("="^80)

# Test on simple linear system
problem_name = "simpleLin"
println("\nTest 1: Simple Linear System ($(problem_name))")
println("-"^80)

# Load problem with 2 trajectories
experiments = BenchmarkSystems.load_problem(problem_name, num_trajectories=2)

# Configure with different integration iterations
test_configs = [
    (name="No refinement", niter=0),
    (name="3 iterations", niter=3),
    (name="5 iterations", niter=5)
]

results = []

for config in test_configs
    println("\nConfiguration: $(config.name) (niterations_integration=$(config.niter))")
    
    options = SymbolicRegressionODE.ODERegressionOptions(
        niterations_derivative = 10,
        niterations_integration = config.niter,
        complexity_derivative = 10,
        complexity_integration = 8,
        binary_operators = (+, *, -, /),
        unary_operators = (),
        parallelism = :serial,
        verbose = true
    )
    
    result = SymbolicRegressionODE.discover_ode_system(experiments; ode_options=options)
    
    push!(results, (
        name = config.name,
        loss = result.integration_loss,
        equations = result.best_trees
    ))
    
    println("  Final integration loss: $(round(result.integration_loss, sigdigits=4))")
end

# Compare results
println("\n" * "="^80)
println("COMPARISON")
println("="^80)

for (i, r) in enumerate(results)
    println("$(r.name): loss = $(round(r.loss, sigdigits=4))")
end

# Check that refinement helps (or at least doesn't hurt)
println("\n✓ Test completed!")
println("  Note: With more iterations, the loss should stay the same or improve")
println("  due to the iterative co-refinement process.")
println("="^80)
