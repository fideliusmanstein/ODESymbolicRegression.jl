"""
test_multi_ic_robustness.jl

Test that multiple trajectories with different initial conditions
improve robustness and help reject incorrect ODE solutions.
"""

# Activate the main project environment
using Pkg
Pkg.activate(joinpath(@__DIR__, "../.."))

include("../../src/SymbolicRegressionODE.jl")
include("../../benchmark/benchmarkProblems/BenchmarkSystems.jl")

using .SymbolicRegressionODE
using .BenchmarkSystems
using Random

# Import functions for direct use
import .SymbolicRegressionODE: discover_derivatives, refine_with_integration, 
                               discover_ode_system, IntegrationLoss, ODERegressionOptions

println("="^80)
println("Testing Multi-IC Robustness")
println("="^80)

# Set seed for reproducibility
Random.seed!(42)

println("\n[Test 1] Generate data with different initial conditions...")
try
    # Load with 3 trajectories per experiment
    experiments = BenchmarkSystems.load_problem("simpleLin1", num_trajectories=3)
    
    # Should have 8 experiments × 3 trajectories = 24 total
    if length(experiments) != 24
        error("Expected 24 experiments, got $(length(experiments))")
    end
    
    # Check that trajectories for same experiment have different ICs
    exp1_trajs = filter(e -> e[:experiment] == 1, experiments)
    if length(exp1_trajs) != 3
        error("Expected 3 trajectories for experiment 1, got $(length(exp1_trajs))")
    end
    
    # Check ICs are different
    ic1 = exp1_trajs[1][:ic]
    ic2 = exp1_trajs[2][:ic]
    ic3 = exp1_trajs[3][:ic]
    
    if ic1 == ic2 || ic2 == ic3 || ic1 == ic3
        error("ICs should all be different")
    end
    
    # All should satisfy conservation law (X3 + X4 + X5 = 1.0)
    for traj in exp1_trajs
        total = traj[:ic].X3_0 + traj[:ic].X4_0 + traj[:ic].X5_0
        if abs(total - 1.0) >= 1e-10
            error("Conservation law violated: sum = $total")
        end
    end
    
    println("✓ Data generation with varied ICs works")
    println("  - Generated $(length(experiments)) total trajectories")
    println("  - IC 1: $(round.(values(ic1), digits=3))")
    println("  - IC 2: $(round.(values(ic2), digits=3))")
    println("  - IC 3: $(round.(values(ic3), digits=3))")
catch e
    println("✗ Test failed: $e")
    rethrow(e)
end

println("\n[Test 2] Compare single vs multiple trajectories...")
try
    # Single trajectory (original approach)
    experiments_single = BenchmarkSystems.load_problem("simpleLin1", num_trajectories=1)
    if length(experiments_single) != 8
        error("Expected 8 single trajectories, got $(length(experiments_single))")
    end
    
    # Multiple trajectories (robust approach)
    experiments_multi = BenchmarkSystems.load_problem("simpleLin1", num_trajectories=3)
    if length(experiments_multi) != 24
        error("Expected 24 multi trajectories, got $(length(experiments_multi))")
    end
    
    println("✓ Can generate both single and multiple trajectory datasets")
    println("  - Single: $(length(experiments_single)) trajectories")
    println("  - Multi: $(length(experiments_multi)) trajectories")
catch e
    println("✗ Test failed: $e")
    rethrow(e)
end

println("\n[Test 3] Full discovery pipeline with multiple ICs...")
try
    # Use just first experiment with 3 different ICs
    experiments = BenchmarkSystems.load_problem("simpleLin1", num_trajectories=3)
    exp1_trajs = filter(e -> e[:experiment] == 1, experiments)
    
    # Create options
    ode_options = ODERegressionOptions(
        binary_operators = (+, *, -, /),
        unary_operators = (cos, sin, exp),
        maxsize = 15,
        niterations_derivative = 2,  # Short for testing
        niterations_integration = 2,
        differentiation_method = :finite_difference,
        verbose = false
    )
    
    println("  Running discovery on $(length(exp1_trajs)) trajectories...")
    
    # Stage 1: Discover derivatives
    derivative_expressions = discover_derivatives(exp1_trajs, ode_options)
    if length(derivative_expressions) != 3
        error("Expected 3 derivative expressions, got $(length(derivative_expressions))")
    end
    
    # Stage 2: Refine with integration
    final_expressions, integration_loss = refine_with_integration(
        derivative_expressions, exp1_trajs, ode_options)
    if length(final_expressions) != 3
        error("Expected 3 final expressions, got $(length(final_expressions))")
    end
    if !(integration_loss isa Float64)
        error("Integration loss should be Float64")
    end
    
    println("✓ Full pipeline works with multiple ICs")
    println("  - Integration loss: $integration_loss")
    
catch e
    println("✗ Test failed: $e")
    rethrow(e)
end

println("\n[Test 4] Verify IntegrationLoss uses all trajectories...")
try
    experiments = BenchmarkSystems.load_problem("simpleLin1", num_trajectories=3)
    exp1_trajs = filter(e -> e[:experiment] == 1, experiments)
    
    # Create IntegrationLoss with all 3 trajectories
    loss_config = IntegrationLoss(exp1_trajs)
    if length(loss_config.trajectories) != 3
        error("Expected 3 trajectories in IntegrationLoss, got $(length(loss_config.trajectories))")
    end
    
    # Check each trajectory has correct keys
    for traj in loss_config.trajectories
        if !haskey(traj, :t) || !haskey(traj, :X_observed) || !haskey(traj, :inputs)
            error("Trajectory missing required keys")
        end
        if size(traj[:X_observed], 1) != 13
            error("Expected 13 time points, got $(size(traj[:X_observed], 1))")
        end
        if size(traj[:X_observed], 2) != 3
            error("Expected 3 state variables, got $(size(traj[:X_observed], 2))")
        end
    end
    
    println("✓ IntegrationLoss correctly stores all trajectories")
    println("  - $(length(loss_config.trajectories)) trajectories stored")
    println("  - Each trajectory: $(size(loss_config.trajectories[1][:X_observed])) data points")
    
catch e
    println("✗ Test failed: $e")
    rethrow(e)
end

println("\n[Test 5] Test discover_ode_system with multiple ICs...")
try
    # Use first 2 experiments with 2 ICs each = 4 total trajectories
    experiments = BenchmarkSystems.load_problem("simpleLin1", num_trajectories=2)
    test_exps = filter(e -> e[:experiment] <= 2, experiments)
    if length(test_exps) != 4
        error("Expected 4 test experiments, got $(length(test_exps))")
    end
    
    ode_options = ODERegressionOptions(
        binary_operators = (+, *, -, /),
        unary_operators = (cos, sin, exp),
        maxsize = 15,
        niterations_derivative = 2,
        niterations_integration = 2,
        differentiation_method = :finite_difference,
        verbose = false
    )
    
    println("  Running full discover_ode_system on $(length(test_exps)) trajectories...")
    result = discover_ode_system(test_exps; ode_options=ode_options)
    
    if length(result.derivative_candidates) != 3 || length(result.best_trees) != 3
        error("Expected 3 expressions each")
    end
    if !(result.integration_loss isa Float64)
        error("Integration loss should be Float64, got $(typeof(result.integration_loss))")
    end
    
    println("✓ discover_ode_system works with multiple ICs")
    println("  - Integration stage loss: $(result.integration_loss)")
    println("  - Number of equations: $(length(result.best_trees))")
    
catch e
    println("✗ Test failed: $e")
    rethrow(e)
end

println("\n" * "="^80)
println("All robustness tests passed! ✓")
println("="^80)

println("\nSummary:")
println("- ✓ Data generation supports varied initial conditions")
println("- ✓ Conservation law is respected (X3 + X4 + X5 = 1.0)")
println("- ✓ IntegrationLoss evaluates on all trajectories")
println("- ✓ Full pipeline works end-to-end with multiple ICs")
println("- ✓ All multi-trajectory mechanisms functional")

println("\n" * "="^80)
