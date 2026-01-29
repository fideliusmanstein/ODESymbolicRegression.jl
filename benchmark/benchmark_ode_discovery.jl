"""
benchmark_ode_discovery.jl

Comprehensive benchmarking of ODE discovery algorithm on all benchmark problems.
Automatically compares discovered equations with ground truth.
"""

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
                                 num_trajectories=1)
    
    println("\n" * "="^80)
    println("Benchmarking: $problem_name")
    if num_trajectories > 1
        println("Multi-trajectory mode: $num_trajectories ICs per experiment")
    end
    println("="^80)
    
    # Load problem with multiple trajectories for robust evaluation
    experiments = BenchmarkSystems.load_problem(problem_name, num_trajectories=num_trajectories)
    
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
        filename = "results/benchmark_results/benchmark_results_$(timestamp).txt"
        
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
                end
                
                println(io, "-"^80)
            end
        end
        
        println("\nResults saved to: ", filename)
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

