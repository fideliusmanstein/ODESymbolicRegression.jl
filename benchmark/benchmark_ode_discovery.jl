"""
benchmark_ode_discovery.jl

Comprehensive benchmarking of ODE discovery algorithm on all benchmark problems.
Automatically compares discovered equations with ground truth.
"""

# Activate project environment if not already activated
if !haskey(ENV, "JULIA_PROJECT") || !endswith(ENV["JULIA_PROJECT"], "ODESymbolicRegression.jl")
    import Pkg
    Pkg.activate(joinpath(@__DIR__, ".."))
end

include("../src/SymbolicRegressionODE.jl")
include("benchmarkProblems/BenchmarkSystems.jl")

using .SymbolicRegressionODE
using .BenchmarkSystems
using SymbolicRegression
using Statistics
using Printf
using Dates
using SymbolicUtils
using Symbolics
using JSON
using CSV
using DataFrames

"""
    round_equation_constants(equation_str::String; digits=2)

Round all numeric constants in an equation string to specified number of decimal places.
"""
function round_equation_constants(equation_str::String; digits=2)
    # Match floating point numbers (including scientific notation)
    pattern = r"(-?\d+\.?\d*(?:[eE][+-]?\d+)?)"
    
    result = replace(equation_str, pattern => m -> begin
        num = parse(Float64, m)  # m is already a string, not a match object
        # Round to specified digits
        rounded = round(num, digits=digits)
        # Format: remove trailing zeros and unnecessary decimal point
        formatted = string(rounded)
        # Clean up formatting
        if occursin('.', formatted)
            formatted = replace(formatted, r"\.?0+$" => "")
        end
        formatted
    end)
    
    return result
end

"""
    normalize_equation_unified(eq_input; sr_options=nothing, use_symbolic=true)

Unified normalization for both trees and strings:
1. Convert input to string (from tree or normalize variable names in string)
2. Apply symbolic simplification using SymbolicUtils
3. Round constants to 2 decimal places

This ensures identical normalization behavior for ground truth and discovered equations.
"""
function normalize_equation_unified(eq_input; sr_options=nothing, use_symbolic=true)
    # Step 1: Convert to string
    if sr_options !== nothing
        # Input is a tree - convert to string with canonical variable names
        eq_str = string_tree(eq_input, sr_options)
    else
        # Input is a string - normalize variable names (X1→x1, X2→x2, etc.)
        eq_str = eq_input
        for i in 1:20
            eq_str = replace(eq_str, "X$i" => "x$i")
        end
    end
    
    # Step 2: Symbolic simplification (same for both trees and strings)
    if use_symbolic
        try
            # Define symbolic variables
            Symbolics.@variables x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20
            
            # Define square function for symbolic evaluation
            square(x) = x * x
            
            # Parse and evaluate the equation string
            expr = Meta.parse(eq_str)
            symbolic_expr = eval(expr)
            
            # Simplification pipeline: simplify → expand → simplify again
            simplified = SymbolicUtils.simplify(symbolic_expr)
            simplified = Symbolics.expand(simplified)
            simplified = SymbolicUtils.simplify(simplified)
            
            # Convert back to string
            eq_str = string(simplified)
            
        catch e
            # If symbolic processing fails, continue with original string
        end
    end
    
    # Step 3: Round constants (same for both)
    eq_str = round_equation_constants(eq_str, digits=2)
    
    return eq_str
end

# Convenience wrappers for backward compatibility
"""
    normalize_equation(tree, sr_options; use_symbolic=true)

Normalize equation from tree representation.
"""
normalize_equation(tree, sr_options; use_symbolic=true) = 
    normalize_equation_unified(tree; sr_options=sr_options, use_symbolic=use_symbolic)

"""
    normalize_equation_string(eq_str::String; use_symbolic=true)

Normalize equation from string representation.
"""
normalize_equation_string(eq_str::String; use_symbolic=true) = 
    normalize_equation_unified(eq_str; use_symbolic=use_symbolic)

"""
    get_ground_truth_equations(problem_name)

Get ground truth equation descriptions for benchmark problems.
Retrieves equations directly from the benchmark module functions.
"""
function get_ground_truth_equations(problem_name)
    # Map problem prefixes to their modules
    # IMPORTANT: Check more specific prefixes first to avoid conflicts
    # (e.g., "ss_feedf" before "feedf", "gma_inhosc" before "inhosc")
    
    # GMA Problems (check first - most specific with gma_ prefix)
    if startswith(problem_name, "gma_feedf")
        return BenchmarkSystems.GmaFeedfModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "gma_inhosc")
        return BenchmarkSystems.GmaInhoscModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "gma_bifeedb")
        return BenchmarkSystems.GmaBifeedbModule.get_equation_strings(problem_name)
    # S-System Problems (check second - specific with ss_ prefix)
    elseif startswith(problem_name, "ss_cascade")
        return BenchmarkSystems.SsCascadeModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "ss_branch")
        return BenchmarkSystems.SsBranchModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "ss_5genes")
        return BenchmarkSystems.Ss5genesModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "ss_15genes")
        return BenchmarkSystems.Ss15genesModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "ss_30genes")
        return BenchmarkSystems.Ss30genesModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "ss_feedf")
        return BenchmarkSystems.SsFeedfModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "ss_inhosc")
        return BenchmarkSystems.SsInhoscModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "ss_bifeedb")
        return BenchmarkSystems.SsBifeedbModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "ss_ethanolferm")
        return BenchmarkSystems.SsEthanolfermModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "ss_sosrepair")
        return BenchmarkSystems.SsSosrepairModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "ss_cadBA")
        return BenchmarkSystems.SsCadBAModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "ss_clock")
        return BenchmarkSystems.SsClockModule.get_equation_strings(problem_name)
    # Chemical Rate Problems (check last - generic names without prefix)
    elseif startswith(problem_name, "simpleLin")
        return BenchmarkSystems.SimpleLinModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "simpleFb")
        return BenchmarkSystems.SimpleFbModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "threeGenes")
        return BenchmarkSystems.ThreeGenesModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "metabol")
        return BenchmarkSystems.MetabolModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "feedf")
        return BenchmarkSystems.FeedfModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "inhosc")
        return BenchmarkSystems.InhoscModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "bifeedb")
        return BenchmarkSystems.BifeedbModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "cytokine")
        return BenchmarkSystems.CytokineModule.get_equation_strings(problem_name)
    elseif startswith(problem_name, "osc")
        return BenchmarkSystems.OscModule.get_equation_strings(problem_name)
    else
        return ["Ground truth equations not yet implemented for: $problem_name"]
    end
end

"""
    evaluate_tree_on_data(tree, X_features, sr_options)

Evaluate a symbolic expression tree on input data.

# Arguments
- `tree`: Expression tree
- `X_features`: Feature matrix (n_features × n_samples)
- `sr_options`: SymbolicRegression.Options for tree evaluation

# Returns
- Predictions vector
"""
function evaluate_tree_on_data(tree, X_features, sr_options)
    n_samples = size(X_features, 2)
    predictions = zeros(n_samples)
    
    for i in 1:n_samples
        x = X_features[:, i]
        predictions[i] = eval_tree_array(tree, x, sr_options)[1]
    end
    
    return predictions
end

"""
    compute_r2_score(y_true, y_pred)

Compute R² coefficient of determination.

# Arguments
- `y_true`: True values
- `y_pred`: Predicted values

# Returns
- R² score (1.0 = perfect fit, 0.0 = no better than mean, negative = worse than mean)
"""
function compute_r2_score(y_true, y_pred)
    ss_res = sum((y_true .- y_pred).^2)
    ss_tot = sum((y_true .- mean(y_true)).^2)
    
    if ss_tot ≈ 0.0
        return ss_res ≈ 0.0 ? 1.0 : -Inf
    end
    
    return 1.0 - ss_res / ss_tot
end

"""
    compute_symbolic_accuracy(discovered_tree, true_derivatives, X_features, sr_options; 
                             r2_threshold=0.95, max_error_threshold=0.1)

Compare discovered equation with ground truth using multiple metrics.

# Arguments
- `discovered_tree`: Discovered expression tree
- `true_derivatives`: Ground truth derivative values
- `X_features`: Feature matrix used for symbolic regression
- `sr_options`: SymbolicRegression options
- `r2_threshold`: R² threshold for considering equations equivalent (default: 0.95)
- `max_error_threshold`: Maximum relative error threshold (default: 0.1)

# Returns
- Dictionary with comparison metrics
"""
function compute_symbolic_accuracy(discovered_tree, true_derivatives, X_features, sr_options;
                                   r2_threshold=0.95, max_error_threshold=0.1)
    # Evaluate discovered equation on feature data
    predictions = evaluate_tree_on_data(discovered_tree, X_features, sr_options)
    
    # Compute metrics
    r2 = compute_r2_score(true_derivatives, predictions)
    
    # Compute error metrics
    abs_errors = abs.(predictions .- true_derivatives)
    mean_abs_error = mean(abs_errors)
    max_abs_error = maximum(abs_errors)
    
    # Relative errors (avoid division by zero)
    relative_errors = abs_errors ./ (abs.(true_derivatives) .+ 1e-10)
    mean_rel_error = mean(relative_errors)
    max_rel_error = maximum(relative_errors)
    
    # Determine if equations are equivalent
    is_equivalent = (r2 >= r2_threshold) && (max_rel_error <= max_error_threshold)
    
    return Dict(
        "r2" => r2,
        "mean_absolute_error" => mean_abs_error,
        "max_absolute_error" => max_abs_error,
        "mean_relative_error" => mean_rel_error,
        "max_relative_error" => max_rel_error,
        "is_equivalent" => is_equivalent,
        "equation" => string_tree(discovered_tree, sr_options)
    )
end

"""
    evaluate_equation_similarity(ground_truth_tree, discovered_tree, sr_options, n_states; n_samples=100)

Evaluate similarity between ground truth and discovered equations by testing on random inputs.

# Arguments
- `ground_truth_tree`: Ground truth equation tree
- `discovered_tree`: Discovered equation tree  
- `sr_options`: SymbolicRegression options
- `n_states`: Number of state variables
- `n_samples`: Number of random test points (default: 100 * n_states)

# Returns
Dictionary with error metrics:
- `rmse`: Root mean squared error
- `nrmse`: Normalized RMSE (RMSE / std of ground truth outputs)
- `mae`: Mean absolute error
- `max_error`: Maximum absolute error
- `r2`: R² coefficient of determination
"""
function evaluate_equation_similarity(ground_truth_tree, discovered_tree, sr_options, n_states; n_samples=nothing)
    if n_samples === nothing
        n_samples = 100 * n_states
    end
    
    # Generate random test points in a reasonable range [0.1, 10.0]
    # Avoid zeros to prevent division issues
    test_points = 0.1 .+ 9.9 .* rand(n_samples, n_states)
    
    ground_truth_outputs = Float64[]
    discovered_outputs = Float64[]
    
    # Evaluate both equations on each test point
    for i in 1:n_samples
        x = test_points[i, :]
        
        try
            # Evaluate ground truth
            gt_val = eval_tree_array(ground_truth_tree, x, sr_options)[1]
            
            # Evaluate discovered equation
            disc_val = eval_tree_array(discovered_tree, x, sr_options)[1]
            
            # Only include valid numeric results
            if isfinite(gt_val) && isfinite(disc_val)
                push!(ground_truth_outputs, gt_val)
                push!(discovered_outputs, disc_val)
            end
        catch
            # Skip points where evaluation fails
            continue
        end
    end
    
    # If we don't have enough valid points, return NaN metrics
    if length(ground_truth_outputs) < 10
        return Dict(
            "rmse" => NaN,
            "nrmse" => NaN,
            "mae" => NaN,
            "max_error" => NaN,
            "r2" => NaN,
            "valid_samples" => length(ground_truth_outputs)
        )
    end
    
    # Compute error metrics
    errors = discovered_outputs .- ground_truth_outputs
    abs_errors = abs.(errors)
    
    rmse = sqrt(mean(errors.^2))
    mae = mean(abs_errors)
    max_error = maximum(abs_errors)
    
    # Normalized RMSE (by standard deviation of ground truth)
    gt_std = std(ground_truth_outputs)
    nrmse = gt_std > 1e-10 ? rmse / gt_std : NaN
    
    # R² coefficient (1 = perfect, 0 = no better than mean, <0 = worse than mean)
    ss_res = sum(errors.^2)
    ss_tot = sum((ground_truth_outputs .- mean(ground_truth_outputs)).^2)
    r2 = ss_tot > 1e-10 ? 1.0 - (ss_res / ss_tot) : NaN
    
    return Dict(
        "rmse" => rmse,
        "nrmse" => nrmse,
        "mae" => mae,
        "max_error" => max_error,
        "r2" => r2,
        "valid_samples" => length(ground_truth_outputs)
    )
end

"""
    benchmark_single_problem(problem_name; ode_options=nothing)

Benchmark ODE discovery on a single problem.

# Arguments
- `problem_name`: Name of the problem from BenchmarkSystems
- `ode_options`: ODERegressionOptions (if nothing, uses default fast settings)

# Returns
- Dictionary with benchmark results (success based on integration_loss < 1.0)
"""
function benchmark_single_problem(problem_name; 
                                 ode_options=nothing,
                                 num_trajectories=1,
                                 noise_std=0.0)
    
    println("\n" * "="^80)
    println("Benchmarking: $problem_name")
    if num_trajectories > 1
        println("Multi-trajectory mode: $num_trajectories ICs per experiment")
    end
    if noise_std > 0.0
        println("Noise level: $noise_std")
    end
    println("="^80)
    
    # Load problem with multiple trajectories for robust evaluation
    experiments = BenchmarkSystems.load_problem(problem_name, num_trajectories=num_trajectories, noise_std=noise_std)
    
    # Use default fast options if not provided
    if ode_options === nothing
        ode_options = ODERegressionOptions(
            niterations_derivative=8,
            niterations_integration=4,
            complexity_derivative=12,
            complexity_integration=10,
            parallelism=:multithreading,
            verbose=false
        )
    end
    
    # Time the discovery process
    start_time = time()
    
    try
        # Discover ODE system
        result = SymbolicRegressionODE.discover_ode_system(experiments; ode_options=ode_options)
        
        discovery_time = time() - start_time
        
        # Extract basic info from first experiment
        exp = experiments[1]
        n_states = size(exp[:X], 2)
        
        # Success based on integration loss (no ground truth comparison)
        success = result.integration_loss < 1.0  # Threshold for reasonable discovery
        
        # Convert discovered trees to equation strings with normalization
        sr_options = SymbolicRegression.Options(
            binary_operators=ode_options.binary_operators,
            unary_operators=ode_options.unary_operators
        )
        discovered_equations = [normalize_equation(tree, sr_options) for tree in result.best_trees]
        
        # Extract initial equations (before integration refinement)
        initial_equations = [normalize_equation(tree, sr_options) for tree in result.initial_trees]
        
        # Get ground truth equations and normalize them
        ground_truth_equations_raw = get_ground_truth_equations(problem_name)
        ground_truth_equations = [normalize_equation_string(eq) for eq in ground_truth_equations_raw]
        
        # Compute equation similarity scores
        equation_scores = []
        println("\n" * "="^80)
        println("Equation Similarity Analysis")
        println("="^80)
        println("Testing each equation with $(100 * n_states) random input samples...")
        
        for i in 1:min(length(result.best_trees), length(ground_truth_equations_raw))
            try
                # Parse ground truth equation string
                gt_eq_str = ground_truth_equations_raw[i]
                # Remove "x_i' = " prefix if present
                gt_eq_str = replace(gt_eq_str, r"^[xX]\d+'\s*=\s*" => "")
                
                disc_tree = result.best_trees[i]
                
                # Create a function to evaluate the ground truth equation
                arg_symbols = [Symbol("x$k") for k in 1:n_states]
                func_body = Meta.parse("begin; square(x) = x * x; $gt_eq_str; end")
                gt_func = @eval ($(arg_symbols...),) -> $func_body
                
                # Direct numerical comparison
                n_samples = 100 * n_states
                # Use a range [0.1, 5.0] to avoid extreme values
                test_points = 0.1 .+ 4.9 .* rand(n_samples, n_states)
                
                ground_truth_outputs = Float64[]
                discovered_outputs = Float64[]
                
                error_count = 0
                
                # Evaluate both equations on test points
                for j in 1:n_samples
                    x_vals = test_points[j, :]
                    
                    try
                        # Evaluate ground truth using the created function
                        gt_val = gt_func(x_vals...)
                        
                        # Evaluate discovered tree
                        disc_val = eval_tree_array(disc_tree, x_vals, sr_options)[1]
                        
                        # Only include if both are finite and not too extreme
                        if isfinite(gt_val) && isfinite(disc_val) && 
                           abs(gt_val) < 1e10 && abs(disc_val) < 1e10
                            push!(ground_truth_outputs, gt_val)
                            push!(discovered_outputs, disc_val)
                        end
                    catch e
                        # Count errors for debugging
                        error_count += 1
                        if error_count == 1
                            # Print first error for debugging
                            println("    First evaluation error: ", e)
                        end
                        continue
                    end
                end
                
                # Compute error metrics
                if length(ground_truth_outputs) >= 10
                    errors = discovered_outputs .- ground_truth_outputs
                    abs_errors = abs.(errors)
                    
                    rmse = sqrt(mean(errors.^2))
                    mae = mean(abs_errors)
                    max_error = maximum(abs_errors)
                    
                    gt_std = std(ground_truth_outputs)
                    nrmse = gt_std > 1e-10 ? rmse / gt_std : NaN
                    
                    ss_res = sum(errors.^2)
                    ss_tot = sum((ground_truth_outputs .- mean(ground_truth_outputs)).^2)
                    r2 = ss_tot > 1e-10 ? 1.0 - (ss_res / ss_tot) : NaN
                    
                    score = Dict(
                        "equation_index" => i,
                        "rmse" => rmse,
                        "nrmse" => nrmse,
                        "mae" => mae,
                        "max_error" => max_error,
                        "r2" => r2,
                        "valid_samples" => length(ground_truth_outputs)
                    )
                    
                    push!(equation_scores, score)
                    
                    println("\nEquation $i:")
                    println("  RMSE: ", @sprintf("%.6e", rmse))
                    println("  NRMSE: ", @sprintf("%.4f", nrmse))
                    println("  MAE: ", @sprintf("%.6e", mae))
                    println("  Max Error: ", @sprintf("%.6e", max_error))
                    println("  R²: ", @sprintf("%.6f", r2))
                    println("  Valid samples: $(length(ground_truth_outputs))/$(n_samples)")
                else
                    println("\nEquation $i: Insufficient valid samples ($(length(ground_truth_outputs))/$(n_samples))")
                    if error_count > 0
                        println("  Errors encountered: $error_count")
                    end
                    push!(equation_scores, Dict(
                        "equation_index" => i,
                        "rmse" => NaN,
                        "nrmse" => NaN,
                        "mae" => NaN,
                        "max_error" => NaN,
                        "r2" => NaN,
                        "valid_samples" => length(ground_truth_outputs)
                    ))
                end
            catch e
                println("\nEquation $i: Error computing similarity - ", e)
                println("  Stack trace: ")
                for (exc, bt) in Base.catch_stack()
                    showerror(stdout, exc, bt)
                    println()
                end
                push!(equation_scores, Dict(
                    "equation_index" => i,
                    "rmse" => NaN,
                    "nrmse" => NaN,
                    "mae" => NaN,
                    "max_error" => NaN,
                    "r2" => NaN,
                    "valid_samples" => 0,
                    "error" => string(e)
                ))
            end
        end
        println("="^80)
        
        println("\n" * "-"^80)
        println("Overall Result: ", success ? "✓ SUCCESS" : "✗ FAILED")
        println("Discovery time: ", @sprintf("%.2f", discovery_time), " seconds")
        println("Integration loss: ", @sprintf("%.6e", result.integration_loss))
        println("Number of states: ", n_states)
        println("\nGround Truth Equations:")
        for (i, eq) in enumerate(ground_truth_equations)
            println("  ", eq)
        end
        println("\nDiscovered Equations:")
        for (i, eq) in enumerate(discovered_equations)
            println("  X", i, "' = ", eq)
        end
        println("-"^80)
        
        return Dict(
            "problem_name" => problem_name,
            "success" => success,
            "discovery_time" => discovery_time,
            "integration_loss" => result.integration_loss,
            "initial_loss" => result.initial_loss,
            "n_states" => n_states,
            "discovered_equations" => discovered_equations,
            "initial_equations" => initial_equations,
            "ground_truth_equations" => ground_truth_equations,
            "equation_scores" => equation_scores,
            "error" => nothing
        )
        
    catch e
        discovery_time = time() - start_time
        
        println("\n✗ ERROR during discovery: ", e)
        println("Discovery time before error: ", @sprintf("%.2f", discovery_time), " seconds")
        
        return Dict(
            "problem_name" => problem_name,
            "success" => false,
            "discovery_time" => discovery_time,
            "integration_loss" => Inf,
            "n_states" => 0,
            "error" => string(e)
        )
    end
end

"""
    benchmark_all_problems(; ode_options=nothing, 
                          problem_filter=nothing,
                          save_results=true)

Benchmark ODE discovery on all (or filtered) benchmark problems.

# Arguments
- `ode_options`: ODERegressionOptions (if nothing, uses default fast settings)
- `problem_filter`: Function to filter problems (e.g., name -> startswith(name, "ss_"))
- `save_results`: Save results to file

# Returns
- Vector of result dictionaries (success based on integration_loss < 1.0)
"""
function clean_nan_for_json(obj)
    """Replace NaN values with nothing (null in JSON) for JSON serialization."""
    if obj isa Dict
        return Dict(k => clean_nan_for_json(v) for (k, v) in obj)
    elseif obj isa Array
        return [clean_nan_for_json(x) for x in obj]
    elseif obj isa Float64 && isnan(obj)
        return nothing
    else
        return obj
    end
end

function save_benchmark_results(all_results, timestamp)
    """
    Save benchmark results to CSV (summary) and JSON (detailed).
    
    # Arguments
    - `all_results`: Vector of result dictionaries
    - `timestamp`: Timestamp string for filenames
    
    # Returns
    - DataFrame with summary statistics
    """
    results_dir = "benchmark_results"
    mkpath(results_dir)
    
    # 1. CSV Summary - one row per problem
    summary_rows = []
    for result in all_results
        # Count equations with good match (R² > 0.9)
        n_good_equations = 0
        n_total_equations = 0
        avg_r2 = NaN
        
        if haskey(result, "equation_scores") && !isempty(result["equation_scores"])
            scores = result["equation_scores"]
            n_total_equations = length(scores)
            r2_values = [s["r2"] for s in scores if !isnan(s["r2"])]
            n_good_equations = count(r2 -> r2 > 0.9, r2_values)
            avg_r2 = isempty(r2_values) ? NaN : mean(r2_values)
        end
        
        push!(summary_rows, (
            problem_name = result["problem_name"],
            success = result["success"],
            n_states = get(result, "n_states", 0),
            n_equations_correct = n_good_equations,
            n_equations_total = n_total_equations,
            avg_r2 = avg_r2,
            integration_loss = result["integration_loss"],
            initial_loss = get(result, "initial_loss", NaN),
            discovery_time = result["discovery_time"],
            has_error = result["error"] !== nothing,
            error_type = result["error"] !== nothing ? split(string(result["error"]), ":")[1] : ""
        ))
    end
    
    df = DataFrame(summary_rows)
    CSV.write(joinpath(results_dir, "summary_$timestamp.csv"), df)
    
    # 2. JSON Detailed - complete nested structure (clean NaN values first)
    cleaned_results = clean_nan_for_json(all_results)
    open(joinpath(results_dir, "detailed_$timestamp.json"), "w") do io
        JSON.print(io, cleaned_results, 2)  # Pretty print with indent=2
    end
    
    return df
end

"""
    save_results_text(all_results, timestamp)

Save human-readable text report of benchmark results.
"""
function save_results_text(all_results, timestamp)
    results_dir = "benchmark_results"
    mkpath(results_dir)
    filename = joinpath(results_dir, "results_$(timestamp).txt")
    
    successful = filter(r -> r["success"], all_results)
    failed = filter(r -> !r["success"], all_results)
    
    open(filename, "w") do io
        println(io, "ODE Discovery Benchmark Results")
        println(io, "="^80)
        println(io, "Timestamp: ", timestamp)
        println(io, "Total problems: ", length(all_results))
        println(io, "Successful: ", length(successful))
        println(io, "Failed: ", length(failed))
        println(io, "\n" * "="^80)
        
        for result in all_results
            println(io, "\nProblem: ", result["problem_name"])
            println(io, "Success: ", result["success"])
            println(io, "Time: ", @sprintf("%.2f", result["discovery_time"]), "s")
            println(io, "Integration loss: ", @sprintf("%.6e", result["integration_loss"]))
            
            if result["error"] !== nothing
                println(io, "Error: ", result["error"])
            else
                println(io, "States: ", result["n_states"])
                
                # Print ground truth equations
                println(io, "\nGround Truth Equations:")
                for (i, eq) in enumerate(get(result, "ground_truth_equations", []))
                    println(io, "  ", eq)
                end
                
                # Print discovered equations
                println(io, "\nDiscovered Equations:")
                for (i, eq) in enumerate(get(result, "discovered_equations", []))
                    println(io, "  X", i, "' = ", eq)
                end
                
                # Print equation similarity scores if available
                if haskey(result, "equation_scores") && !isempty(result["equation_scores"])
                    println(io, "\nEquation Similarity Scores:")
                    for score in result["equation_scores"]
                        i = score["equation_index"]
                        println(io, "  Equation $i:")
                        println(io, "    R² = ", @sprintf("%.6f", score["r2"]))
                        println(io, "    RMSE = ", @sprintf("%.6e", score["rmse"]))
                        println(io, "    NRMSE = ", @sprintf("%.4f", score["nrmse"]))
                        println(io, "    Valid samples = ", score["valid_samples"])
                    end
                end
            end
            
            println(io, "-"^80)
        end
    end
    
    return filename
end

"""
    benchmark_all_problems(; ode_options=nothing, 
                          problem_filter=nothing,
                          save_results=true)

Benchmark ODE discovery on all (or filtered) benchmark problems.

# Arguments
- `ode_options`: ODERegressionOptions (if nothing, uses default fast settings)
- `problem_filter`: Function to filter problems (e.g., name -> startswith(name, "ss_"))
- `save_results`: Save results to file

# Returns
- Vector of result dictionaries (success based on integration_loss < 1.0)
"""
function benchmark_all_problems(;
                               ode_options=nothing,
                               problem_filter=nothing,
                               save_results=true)
    
    # Get all problems
    all_problems = BenchmarkSystems.list_problems()
    problem_names = sort(collect(keys(all_problems)))
    
    # Apply filter if provided
    if problem_filter !== nothing
        problem_names = filter(problem_filter, problem_names)
    end
    
    println("\n" * "="^80)
    println("BENCHMARK: ODE Discovery System")
    println("="^80)
    println("Total problems to test: ", length(problem_names))
    println("Success criterion: Integration loss < 1.0")
    if ode_options !== nothing
        println("Derivative iterations: ", ode_options.niterations_derivative)
        println("Integration iterations: ", ode_options.niterations_integration)
        println("Differentiation method: ", ode_options.differentiation_method)
    end
    println("="^80)
    
    # Run benchmarks
    all_results = []
    
    for (idx, problem_name) in enumerate(problem_names)
        println("\n[Progress: $idx/$(length(problem_names))]")
        
        result = benchmark_single_problem(
            problem_name;
            ode_options=ode_options
        )
        
        push!(all_results, result)
    end
    
    # Compute summary statistics
    println("\n\n" * "="^80)
    println("BENCHMARK SUMMARY")
    println("="^80)
    
    successful = filter(r -> r["success"], all_results)
    failed = filter(r -> !r["success"], all_results)
    errors = filter(r -> r["error"] !== nothing, all_results)
    
    println("Total problems tested: ", length(all_results))
    println("Successful: ", length(successful), " (", 
            @sprintf("%.1f%%", 100 * length(successful) / length(all_results)), ")")
    println("Failed: ", length(failed), " (", 
            @sprintf("%.1f%%", 100 * length(failed) / length(all_results)), ")")
    println("Errors: ", length(errors))
    
    if !isempty(all_results)
        total_time = sum(r["discovery_time"] for r in all_results)
        avg_time = mean(r["discovery_time"] for r in all_results)
        
        println("\nTotal time: ", @sprintf("%.2f", total_time), " seconds")
        println("Average time per problem: ", @sprintf("%.2f", avg_time), " seconds")
    end
    
    # List failed problems
    if !isempty(failed)
        println("\nFailed problems:")
        for r in failed
            println("  - ", r["problem_name"], 
                   r["error"] !== nothing ? " (ERROR: $(r["error"]))" : "")
        end
    end
    
    # Save results if requested
    if save_results
        timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
        
        # Save structured data (CSV + JSON)
        df = save_benchmark_results(all_results, timestamp)
        
        # Save human-readable text report
        text_file = save_results_text(all_results, timestamp)
        
        println("\n📁 Results saved:")
        println("  Summary CSV: benchmark_results/summary_$timestamp.csv")
        println("  Detailed JSON: benchmark_results/detailed_$timestamp.json")
        println("  Text report: $text_file")
    end
    
    return all_results
end

"""
    quick_benchmark(n_problems=5)

Quick benchmark on a small subset of problems for testing.
Runs with the same settings as the full benchmark command:
- 10 derivative iterations
- 5 integration iterations
- Complexity limits: 12 for derivatives, 10 for integration
- Finite difference method
- Saves results to file
"""
function quick_benchmark(n_problems=5)
    all_problems = BenchmarkSystems.list_problems()
    problem_names = sort(collect(keys(all_problems)))
    selected = problem_names[1:min(n_problems, length(problem_names))]
    
    results = benchmark_all_problems(
        problem_filter = name -> name in selected,
        ode_options = ODERegressionOptions(
            niterations_derivative=10,
            niterations_integration=5,
            complexity_derivative=12,
            complexity_integration=10,
            differentiation_method=:finite_difference,
            verbose=false
        ),
        save_results=true
    )
    
    println("\n✓ Quick benchmark complete! Tested $(length(results)) problems.")
    
    return results
end

# Export functions
export benchmark_single_problem, benchmark_all_problems, quick_benchmark

