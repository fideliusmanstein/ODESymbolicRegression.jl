"""
Test the unified benchmark problem architecture
"""

using Pkg
Pkg.activate(".")

# Load modules
include("benchmark/benchmarkProblems/BaseProblem.jl")
include("benchmark/benchmarkProblems/TreeBuilder.jl")
include("benchmark/benchmarkProblems/SimpleLinProblem.jl")

using .BaseProblemModule
using .TreeBuilderModule
using .SimpleLinProblemModule
using DynamicExpressions

println("="^80)
println("Testing Unified Benchmark Problem Architecture")
println("="^80)

# Test 1: Problem Creation
println("\n[Test 1] Creating problem instances...")
try
    problem1 = SimpleLin1()
    problem2 = SimpleLin2()
    
    println("✓ Created SimpleLin1: $(problem1.name)")
    println("✓ Created SimpleLin2: $(problem2.name)")
    println("  States: $(problem1.n_states), Inputs: $(problem1.n_inputs)")
    println("  Parameters: $(problem1.parameter_values)")
catch e
    println("✗ Failed: $e")
    rethrow(e)
end

# Test 2: Problem Info
println("\n[Test 2] Getting problem information...")
try
    problem = SimpleLin1()
    info = BaseProblemModule.problem_info(problem)
    
    println("✓ Problem info:")
    for (key, val) in info
        println("  $key: $val")
    end
catch e
    println("✗ Failed: $e")
    rethrow(e)
end

# Test 3: Tree Equations
println("\n[Test 3] Accessing expression trees...")
try
    problem = SimpleLin1()
    trees = BaseProblemModule.get_tree_equations(problem)
    
    println("✓ Retrieved $(length(trees)) equation trees")
    
    # Try to convert to string (requires SymbolicRegression)
    using SymbolicRegression
    opts = Options(binary_operators=(+, -, *, /), unary_operators=())
    
    for (i, tree) in enumerate(trees)
        eq_str = string_tree(tree, opts)
        println("  Equation $i: $eq_str")
    end
catch e
    println("✗ Failed: $e")
    rethrow(e)
end

# Test 4: Equation Strings
println("\n[Test 4] Getting equation strings...")
try
    problem = SimpleLin1()
    
    eqs_text = BaseProblemModule.get_equation_strings(problem, format=:text)
    println("✓ Text format:")
    for (i, eq) in enumerate(eqs_text)
        println("  $i: $eq")
    end
    
    eqs_latex = BaseProblemModule.get_equation_strings(problem, format=:latex)
    println("\n✓ LaTeX format:")
    for (i, eq) in enumerate(eqs_latex)
        println("  $i: $eq")
    end
catch e
    println("✗ Failed: $e")
    rethrow(e)
end

# Test 5: Generate Single Trajectory
println("\n[Test 5] Generating single trajectory...")
try
    problem = SimpleLin1()
    
    t, X, inputs = BaseProblemModule.generate_data(problem)
    
    println("✓ Generated data:")
    println("  Time points: $(length(t))")
    println("  State matrix: $(size(X))")
    println("  Input keys: $(keys(inputs))")
    println("  t range: [$(t[1]), $(t[end])]")
    println("  X range: [$(minimum(X)), $(maximum(X))]")
catch e
    println("✗ Failed: $e")
    rethrow(e)
end

# Test 6: Generate with Custom Parameters
println("\n[Test 6] Generating with custom parameters...")
try
    problem = SimpleLin1()
    
    t, X, inputs = BaseProblemModule.generate_data(
        problem;
        X0=[0.5, 0.3, 0.2],
        tspan=(0.0, 5.0),
        n_points=25,
        noise_std=0.05,
        input_values=Dict(:X1 => 4.0, :X2 => 3.0)
    )
    
    println("✓ Generated custom data:")
    println("  Time points: $(length(t))")
    println("  State matrix: $(size(X))")
    println("  IC sum: $(sum([0.5, 0.3, 0.2]))  # Should be 1.0")
catch e
    println("✗ Failed: $e")
    rethrow(e)
end

# Test 7: Generate Multiple Experiments (Single Trajectory)
println("\n[Test 7] Generating experiments (num_trajectories=1)...")
try
    problem = SimpleLin1()
    experiments = BaseProblemModule.generate_experiments(problem)
    
    println("✓ Generated experiments:")
    println("  Total experiments: $(length(experiments))")
    println("  Unique experiment IDs: $(sort(unique([e[:experiment] for e in experiments])))")
    println("  Unique trajectory IDs: $(sort(unique([e[:trajectory] for e in experiments])))")
    
    # Check first experiment
    exp1 = experiments[1]
    println("\n  First experiment:")
    println("    Experiment: $(exp1[:experiment]), Trajectory: $(exp1[:trajectory])")
    println("    IC: $(exp1[:ic])")
    println("    Params: $(exp1[:params])")
    println("    Data shape: $(size(exp1[:X]))")
catch e
    println("✗ Failed: $e")
    rethrow(e)
end

# Test 8: Generate Multiple Trajectories
println("\n[Test 8] Generating experiments (num_trajectories=3)...")
try
    problem = SimpleLin1()
    experiments = BaseProblemModule.generate_experiments(
        problem;
        num_trajectories=3
    )
    
    println("✓ Generated multi-trajectory experiments:")
    println("  Total experiments: $(length(experiments))")
    println("  Expected: 8 experiments × 3 trajectories = 24")
    
    unique_experiments = sort(unique([e[:experiment] for e in experiments]))
    unique_trajectories = sort(unique([e[:trajectory] for e in experiments]))
    
    println("  Unique experiment IDs: $unique_experiments")
    println("  Unique trajectory IDs: $unique_trajectories")
    
    if length(experiments) != 24
        error("Expected 24 experiments, got $(length(experiments))")
    end
    
    # Check conservation law
    println("\n  Checking conservation law for experiment 1:")
    exp1_trajs = filter(e -> e[:experiment] == 1, experiments)
    for traj in exp1_trajs
        ic_sum = traj[:ic].X3_0 + traj[:ic].X4_0 + traj[:ic].X5_0
        println("    Trajectory $(traj[:trajectory]): Sum = $(round(ic_sum, digits=10))")
        if abs(ic_sum - 1.0) > 1e-10
            error("Conservation law violated!")
        end
    end
    
    println("  ✓ All conservation laws satisfied")
catch e
    println("✗ Failed: $e")
    rethrow(e)
end

# Test 9: Generate with Noise
println("\n[Test 9] Generating noisy data...")
try
    problem = SimpleLin2()  # Has noise_std = 0.1
    experiments = BaseProblemModule.generate_experiments(problem)
    
    println("✓ Generated noisy experiments:")
    println("  Problem noise level: $(problem.default_noise)")
    println("  Total experiments: $(length(experiments))")
catch e
    println("✗ Failed: $e")
    rethrow(e)
end

# Test 10: Tree Evaluation
println("\n[Test 10] Evaluating expression trees...")
try
    problem = SimpleLin1()
    trees = BaseProblemModule.get_tree_equations(problem)
    
    using SymbolicRegression
    opts = Options(binary_operators=(+, -, *, /), unary_operators=())
    
    # Evaluate at a test point
    # Features: [X3, X4, X5, X1_input, X2_input]
    X_test = [0.5, 0.3, 0.2, 3.0, 2.0]
    
    println("✓ Evaluating trees at test point:")
    println("  X = $X_test")
    
    for (i, tree) in enumerate(trees)
        result = eval_tree_array(tree, X_test, opts)
        println("  dx$i/dt = $(result[1])")
    end
catch e
    println("✗ Failed: $e")
    rethrow(e)
end

println("\n" * "="^80)
println("All tests passed! ✓")
println("="^80)
println("\nSummary:")
println("  ✓ Problem creation and info")
println("  ✓ Tree equation access")
println("  ✓ Equation string formatting")
println("  ✓ Single trajectory generation")
println("  ✓ Custom parameter generation")
println("  ✓ Multiple experiment generation")
println("  ✓ Multiple trajectory support (num_trajectories)")
println("  ✓ Conservation law enforcement")
println("  ✓ Noise addition")
println("  ✓ Tree evaluation")
println("\nThe unified architecture is working correctly!")
