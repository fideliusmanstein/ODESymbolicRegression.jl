"""
test_multi_trajectory.jl

Test the multi-trajectory evaluation implementation.
"""

# Activate the main project environment
using Pkg
Pkg.activate(joinpath(@__DIR__, "../.."))

include("../../src/SymbolicRegressionODE.jl")
include("../../benchmark/benchmarkProblems/BenchmarkSystems.jl")

using .SymbolicRegressionODE
using .BenchmarkSystems
using Test

println("="^80)
println("Testing Multi-Trajectory Implementation")
println("="^80)

# Test 1: Load single trajectory (backward compatibility)
println("\n[Test 1] Loading single trajectory (backward compatibility)...")
try
    experiments_single = BenchmarkSystems.load_problem("simpleLin1")
    @test length(experiments_single) >= 1
    @test haskey(experiments_single[1], :t)
    @test haskey(experiments_single[1], :X)
    println("✓ Single trajectory loading works")
catch e
    println("✗ Single trajectory loading failed: $e")
    rethrow(e)
end

# Test 2: IntegrationLoss struct with single trajectory
println("\n[Test 2] Testing IntegrationLoss with single trajectory...")
try
    experiments = BenchmarkSystems.load_problem("simpleLin1")
    exp = experiments[1]
    
    # Old-style constructor (backward compatible)
    loss_old = IntegrationLoss(exp[:t], exp[:X], get(exp, :inputs, Dict()))
    @test length(loss_old.trajectories) == 1
    
    # New-style constructor
    loss_new = IntegrationLoss(experiments)
    @test length(loss_new.trajectories) == length(experiments)
    
    println("✓ IntegrationLoss struct works with both constructors")
catch e
    println("✗ IntegrationLoss test failed: $e")
    rethrow(e)
end

# Test 3: Test discover_derivatives with experiments vector
println("\n[Test 3] Testing discover_derivatives with experiments...")
try
    experiments = BenchmarkSystems.load_problem("simpleLin1")
    
    options = ODERegressionOptions(
        niterations_derivative=2,  # Very short for testing
        complexity_derivative=5,
        verbose=false
    )
    
    candidates = SymbolicRegressionODE.discover_derivatives(experiments, options)
    
    n_states = size(experiments[1][:X], 2)
    @test length(candidates) == n_states
    @test all(length(c) > 0 for c in candidates)
    
    println("✓ discover_derivatives works with experiments vector")
catch e
    println("✗ discover_derivatives test failed: $e")
    rethrow(e)
end

# Test 4: Test evaluate_ode_system with multiple trajectories
println("\n[Test 4] Testing evaluate_ode_system with multiple trajectories...")
try
    # Create some dummy trajectories
    experiments = BenchmarkSystems.load_problem("simpleLin1")
    
    # Get some candidate trees from Stage 1
    options = ODERegressionOptions(
        niterations_derivative=2,
        complexity_derivative=5,
        verbose=false
    )
    
    candidates = SymbolicRegressionODE.discover_derivatives(experiments, options)
    
    # Take first candidate from each state
    trees = [c[1].tree for c in candidates]
    
    # Create loss config with all experiments
    loss_config = IntegrationLoss(experiments)
    
    # Evaluate (should return a finite number or Inf)
    loss = SymbolicRegressionODE.evaluate_ode_system(trees, loss_config)
    
    @test isa(loss, Real)
    @test loss >= 0
    
    println("✓ evaluate_ode_system works with multiple trajectories")
    println("  Loss value: $loss")
catch e
    println("✗ evaluate_ode_system test failed: $e")
    rethrow(e)
end

# Test 5: Full discover_ode_system pipeline
println("\n[Test 5] Testing full discover_ode_system pipeline...")
try
    experiments = BenchmarkSystems.load_problem("simpleLin1")
    
    options = ODERegressionOptions(
        niterations_derivative=2,
        niterations_integration=2,
        complexity_derivative=5,
        complexity_integration=5,
        parallelism=:serial,
        verbose=false
    )
    
    result = discover_ode_system(experiments; ode_options=options)
    
    @test !isnothing(result.best_trees)
    @test !isnothing(result.integration_loss)
    @test isa(result.integration_loss, Real)
    
    println("✓ Full pipeline works")
    println("  Integration loss: ", result.integration_loss)
catch e
    println("✗ Full pipeline test failed: $e")
    rethrow(e)
end

# Test 6: Validation - verify multiple trajectories gives same/better result
println("\n[Test 6] Comparing single vs hypothetical multiple trajectories...")
try
    # For now, just use the same experiments multiple times to test the mechanism
    experiments_single = BenchmarkSystems.load_problem("simpleLin1")
    
    # Simulate multiple trajectories by reusing (in reality would have different ICs)
    experiments_multi = vcat(experiments_single, experiments_single[1:min(2, length(experiments_single))])
    
    options = ODERegressionOptions(
        niterations_derivative=2,
        niterations_integration=2,
        complexity_derivative=5,
        complexity_integration=5,
        parallelism=:serial,
        verbose=false
    )
    
    result_single = discover_ode_system(experiments_single; ode_options=options)
    result_multi = discover_ode_system(experiments_multi; ode_options=options)
    
    @test isa(result_single.integration_loss, Real)
    @test isa(result_multi.integration_loss, Real)
    
    println("✓ Mechanism works for multiple trajectories")
    println("  Single trajectory loss: ", result_single.integration_loss)
    println("  Multiple trajectories loss: ", result_multi.integration_loss)
    println("  (Note: Using same data, so losses similar - need different ICs for real test)")
catch e
    println("✗ Comparison test failed: $e")
    rethrow(e)
end

println("\n" * "="^80)
println("All tests passed! ✓")
println("="^80)
println("\nNext steps:")
println("1. Add num_trajectories parameter to benchmark problem generators")
println("2. Generate actual different trajectories with varied initial conditions")
println("3. Test that wrong equations are rejected with multiple ICs")
println("="^80)
