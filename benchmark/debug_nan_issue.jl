"""
debug_nan_issue.jl

Debug script to identify why equation similarity metrics return NaN.
This script simulates the exact process used in the benchmark to isolate the issue.
"""

# Activate project environment
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

# Suppress progress bars and verbose output
ENV["SYMBOLIC_REGRESSION_PROGRESS"] = "false"

include("benchmark_ode_discovery.jl")
using .BenchmarkSystems
using .SymbolicRegressionODE
using SymbolicRegression
using Statistics
using Printf
using Random

# Set random seed for reproducibility
Random.seed!(42)

# Custom operators
square(x) = x * x

# Minimal test configuration
const TEST_OPTIONS = SymbolicRegressionODE.ODERegressionOptions(
    niterations_derivative = 3,
    niterations_integration = 3,
    complexity_derivative = 15,
    complexity_integration = 15,
    binary_operators = (+, *, -, /),
    unary_operators = (square,),
    parallelism = :serial,
    verbose = false
)

println("="^80)
println("Debug Script: Investigating NaN in Equation Similarity Metrics")
println("="^80)

# Test with the first available problem
problem_name = "simpleLin1"
println("\nTesting with problem: $problem_name")

try
    # Load problem
    println("\n1. Loading problem...")
    experiments = BenchmarkSystems.load_problem(problem_name, num_trajectories=1, noise_std=0.0)
    n_states = size(experiments[1][:X], 2)
    println("   ✓ Problem loaded successfully")
    println("   - Number of states: $n_states")
    println("   - Number of experiments: $(length(experiments))")
    
    # Get ground truth equations
    println("\n2. Getting ground truth equations...")
    ground_truth_equations_raw = get_ground_truth_equations(problem_name)
    println("   ✓ Ground truth equations retrieved:")
    for (i, eq) in enumerate(ground_truth_equations_raw)
        println("     Equation $i: $eq")
    end
    
    # Run discovery
    println("\n3. Running ODE discovery...")
    t_start = time()
    result = run_ode_discovery(experiments, TEST_OPTIONS)
    t_end = time()
    println("   ✓ Discovery completed in $(round(t_end - t_start, digits=2))s")
    println("   - Integration loss: $(result.integration_loss)")
    
    # Check if we have results
    if isempty(result.best_trees)
        println("\n   ⚠ ERROR: No equations were discovered!")
        exit(1)
    end
    
    println("   - Number of discovered equations: $(length(result.best_trees))")
    
    # Print discovered equations
    println("\n4. Discovered equations:")
    for (i, expr) in enumerate(result.best_trees)
        disc_tree = expr.tree
        disc_str = string_tree(disc_tree, TEST_OPTIONS)
        println("   Equation $i: $disc_str")
    end
    
    # Now test the equation similarity evaluation
    println("\n5. Testing equation similarity evaluation...")
    println("="^80)
    
    for i in 1:min(length(result.best_trees), length(ground_truth_equations_raw))
        println("\n--- Testing Equation $i ---")
        
        try
            # Get ground truth equation
            gt_eq_str = ground_truth_equations_raw[i]
            # Remove "x_i' = " prefix if present
            gt_eq_str = replace(gt_eq_str, r"^[xX]\d+'\s*=\s*" => "")
            println("Ground truth: $gt_eq_str")
            
            # Get discovered equation
            disc_expr = result.best_trees[i]
            disc_tree = disc_expr.tree
            disc_str = string_tree(disc_tree, TEST_OPTIONS)
            println("Discovered: $disc_str")
            
            # Test evaluation on random points
            n_samples = 100 * n_states
            println("\nTesting with $n_samples random samples...")
            
            # Use a range [0.1, 5.0] to avoid extreme values
            test_points = 0.1 .+ 4.9 .* rand(n_samples, n_states)
            
            ground_truth_outputs = Float64[]
            discovered_outputs = Float64[]
            
            error_count = 0
            first_error = nothing
            
            # Test first few points in detail
            println("\nDetailed test of first 5 samples:")
            for j in 1:min(5, n_samples)
                x_vals = test_points[j, :]
                println("\n  Sample $j: x = $(round.(x_vals, digits=3))")
                
                try
                    # Evaluate ground truth
                    var_assignments = String[]
                    for k in 1:n_states
                        push!(var_assignments, "X$k = $(x_vals[k])")
                    end
                    
                    eval_str = """
                    begin
                        square(x) = x * x
                        $(join(var_assignments, "; "))
                        $gt_eq_str
                    end
                    """
                    
                    gt_val = @eval Main $(Meta.parse(eval_str))
                    println("    Ground truth value: $gt_val")
                    
                    # Evaluate discovered tree
                    disc_result = eval_tree_array(disc_tree, x_vals, TEST_OPTIONS.operators)
                    disc_val = disc_result[1][1]
                    println("    Discovered value: $disc_val")
                    
                    # Check if values are finite
                    if isfinite(gt_val) && isfinite(disc_val)
                        if abs(gt_val) < 1e10 && abs(disc_val) < 1e10
                            push!(ground_truth_outputs, gt_val)
                            push!(discovered_outputs, disc_val)
                            println("    ✓ Both values are valid and within bounds")
                        else
                            println("    ⚠ Values exceed bounds (|val| < 1e10)")
                        end
                    else
                        println("    ⚠ Non-finite values detected")
                    end
                catch e
                    println("    ✗ Error: $e")
                    if first_error === nothing
                        first_error = e
                    end
                    error_count += 1
                end
            end
            
            # Evaluate all samples
            println("\nEvaluating all $n_samples samples...")
            for j in 6:n_samples
                x_vals = test_points[j, :]
                
                try
                    # Evaluate ground truth
                    var_assignments = String[]
                    for k in 1:n_states
                        push!(var_assignments, "X$k = $(x_vals[k])")
                    end
                    
                    eval_str = """
                    begin
                        square(x) = x * x
                        $(join(var_assignments, "; "))
                        $gt_eq_str
                    end
                    """
                    
                    gt_val = @eval Main $(Meta.parse(eval_str))
                    
                    # Evaluate discovered tree
                    disc_result = eval_tree_array(disc_tree, x_vals, TEST_OPTIONS.operators)
                    disc_val = disc_result[1][1]
                    
                    # Only include if both are finite and not too extreme
                    if isfinite(gt_val) && isfinite(disc_val) && 
                       abs(gt_val) < 1e10 && abs(disc_val) < 1e10
                        push!(ground_truth_outputs, gt_val)
                        push!(discovered_outputs, disc_val)
                    end
                catch e
                    if first_error === nothing
                        first_error = e
                    end
                    error_count += 1
                    continue
                end
            end
            
            println("\nResults:")
            println("  Valid samples: $(length(ground_truth_outputs)) / $n_samples")
            println("  Errors encountered: $error_count")
            if first_error !== nothing
                println("  First error: $first_error")
            end
            
            # Compute metrics if we have enough valid samples
            if length(ground_truth_outputs) >= 10
                println("\n  Computing error metrics...")
                
                errors = discovered_outputs .- ground_truth_outputs
                abs_errors = abs.(errors)
                
                rmse = sqrt(mean(errors.^2))
                mae = mean(abs_errors)
                max_error = maximum(abs_errors)
                
                println("    RMSE: ", @sprintf("%.6e", rmse))
                println("    MAE: ", @sprintf("%.6e", mae))
                println("    Max Error: ", @sprintf("%.6e", max_error))
                
                # Check for potential NaN sources
                gt_std = std(ground_truth_outputs)
                println("    Ground truth std: $gt_std")
                
                if gt_std > 1e-10
                    nrmse = rmse / gt_std
                    println("    NRMSE: ", @sprintf("%.4f", nrmse))
                else
                    println("    ⚠ NRMSE: Cannot compute (std too small: $gt_std)")
                end
                
                ss_res = sum(errors.^2)
                ss_tot = sum((ground_truth_outputs .- mean(ground_truth_outputs)).^2)
                println("    SS_res: $ss_res")
                println("    SS_tot: $ss_tot")
                
                if ss_tot > 1e-10
                    r2 = 1.0 - (ss_res / ss_tot)
                    println("    R²: ", @sprintf("%.6f", r2))
                else
                    println("    ⚠ R²: Cannot compute (SS_tot too small: $ss_tot)")
                end
                
                # Check for NaN in outputs
                if any(isnan.(ground_truth_outputs))
                    println("    ⚠ WARNING: NaN values in ground truth outputs!")
                end
                if any(isnan.(discovered_outputs))
                    println("    ⚠ WARNING: NaN values in discovered outputs!")
                end
                
            else
                println("\n  ⚠ Insufficient valid samples to compute metrics")
                println("    This would result in NaN metrics in the benchmark!")
            end
            
        catch e
            println("\n✗ Error in equation similarity test:")
            println("  $e")
            for (exc, bt) in Base.catch_stack()
                showerror(stdout, exc, bt)
                println()
            end
        end
    end
    
    println("\n" * "="^80)
    println("Debug script completed")
    println("="^80)
    
catch e
    println("\n✗ Error in debug script:")
    println("  $e")
    for (exc, bt) in Base.catch_stack()
        showerror(stdout, exc, bt)
        println()
    end
end
