"""
benchmark_reporting.jl

Reporting and output functions for ODE discovery benchmark tests.
"""

using Dates
using LinearAlgebra
using JSON
using DataFrames
using CSV
using Printf

"""
    write_equation_scores(io, equation_scores; indent="  ", show_match_assessment=true)

Write equation similarity scores to an IO stream (file or stdout).
Unified function to avoid duplication between file and console output.
"""
function write_equation_scores(io::IO, equation_scores::Vector; indent="  ", show_match_assessment=true)
    if isempty(equation_scores)
        return
    end
    
    for score in equation_scores
        i = score["equation_index"]
        println(io, indent, "Equation $i:")
        
        if haskey(score, "error")
            prefix = show_match_assessment ? "❌ " : ""
            println(io, indent, "  ", prefix, "Error: $(score["error"])")
        elseif score["valid_samples"] < 10
            prefix = show_match_assessment ? "⚠ " : ""
            println(io, indent, "  ", prefix, "Insufficient valid samples: $(score["valid_samples"])")
        else
            # Check if values are NaN
            if isnan(score["rmse"])
                prefix = show_match_assessment ? "⚠ " : ""
                println(io, indent, "  ", prefix, "Unable to compute metrics (NaN values)")
            else
                println(io, indent, "  RMSE: ", @sprintf("%.6e", score["rmse"]))
                println(io, indent, "  NRMSE: ", isnan(score["nrmse"]) ? "N/A" : @sprintf("%.4f", score["nrmse"]))
                println(io, indent, "  MAE: ", @sprintf("%.6e", score["mae"]))
                println(io, indent, "  Max Error: ", @sprintf("%.6e", score["max_error"]))
                println(io, indent, "  R²: ", isnan(score["r2"]) ? "N/A" : @sprintf("%.6f", score["r2"]))
                println(io, indent, "  Valid samples: $(score["valid_samples"])")
                
                # Add qualitative match assessment if requested
                if show_match_assessment
                    if !isnan(score["r2"]) && score["r2"] > 0.99
                        println(io, indent, "  ✓ Excellent match (R² > 0.99)")
                    elseif !isnan(score["r2"]) && score["r2"] > 0.95
                        println(io, indent, "  ✓ Good match (R² > 0.95)")
                    elseif !isnan(score["r2"]) && score["r2"] > 0.8
                        println(io, indent, "  ~ Fair match (R² > 0.8)")
                    else
                        println(io, indent, "  ✗ Poor match")
                    end
                end
            end
        end
    end
end

"""
    print_test_header(problems, test_options, num_trajectories, noise_std, max_problems, timeout_seconds, n_points=nothing, problems_override=nothing)

Print the benchmark test suite header with configuration information.
"""
function print_test_header(problems, test_options, num_trajectories, noise_std, max_problems, timeout_seconds, n_points=nothing, problems_override=nothing)
    println("="^80)
    println("ODE Discovery Benchmark Test Suite - Multi-Trajectory")
    println("="^80)
    println("Total problems: $(length(problems.all))")
    println("Excluded (timeout): $(length(problems.excluded))")
    println("Testing: $(length(problems.testable)) problems")
    if max_problems !== nothing
        println("  (Limited to first $max_problems for faster iteration)")
    end
    println()
    println("Configuration:")
    println("  - Derivative iterations: $(test_options.niterations_derivative)")
    println("  - Integration iterations: $(test_options.niterations_integration)")
    binary_ops_str = join(string.(test_options.binary_operators), ", ")
    unary_ops_str = isempty(test_options.unary_operators) ? "none" : join(string.(test_options.unary_operators), ", ")
    println("  - Binary operators: $binary_ops_str")
    println("  - Unary operators: $unary_ops_str")
    println("  - Trajectories per experiment: $num_trajectories")
    println("  - Noise level: $noise_std")
    n_points_msg = n_points === nothing ? "problem default" : string(n_points)
    println("  - Time points per trajectory: $n_points_msg")
    timeout_msg = timeout_seconds === nothing ? "none (no timeout)" : "$(timeout_seconds)s"
    println("  - Timeout per system: $timeout_msg")
    override_msg = problems_override === nothing ? "none" : join(problems_override, ", ")
    println("  - Problems override: $override_msg")
    println("="^80)
    println()
end

"""
    write_result_to_file(file, result)

Write a single test result to the output file.
"""
function write_result_to_file(file, result)
    try
        problem_name = get(result, "problem_name", "Unknown Problem")
        println(file, "Problem: $problem_name")
        println(file, "  Success: $(get(result, "success", false))")
        println(file, "  Integration Loss: $(get(result, "integration_loss", NaN))")
        println(file, "  Discovery Time: $(get(result, "discovery_time", 0.0))s")
        println(file, "  N States: $(get(result, "n_states", 0))")
        
        if get(result, "timeout", false)
            println(file, "  Status: TIMEOUT")
        end
        
        if haskey(result, "error") && result["error"] !== nothing
            println(file, "  Error: $(result["error"])")
        end
        
        if haskey(result, "ground_truth_equations")
            println(file, "  Ground Truth Equations:")
            for eq in result["ground_truth_equations"]
                println(file, "    $eq")
            end
        end
        
        if haskey(result, "derivative_stage_equations")
            println(file, "  Derivative Stage Candidates (Stage 1):")
            for (state_idx, candidates) in enumerate(result["derivative_stage_equations"])
                println(file, "    State $state_idx candidates:") 
                for eq in candidates
                    println(file, "      $eq")
                end
            end
        end
        
        if haskey(result, "initial_equations")
            println(file, "  Initial Equations (Best combination from Stage 1):")
            if haskey(result, "initial_loss")
                println(file, "    Initial integration loss: $(result["initial_loss"])")
            end
            for (i, eq) in enumerate(result["initial_equations"])
                println(file, "    X$i' = $eq")
            end
        end
        
        if haskey(result, "discovered_equations")
            println(file, "  Final Discovered Equations (After Integration Refinement):")
            for (i, eq) in enumerate(result["discovered_equations"])
                println(file, "    X$i' = $eq")
            end
        end
        
        # Add equation similarity scores
        if haskey(result, "equation_scores") && !isempty(result["equation_scores"])
            println(file, "  Equation Similarity Scores:")
            println(file, "    (Evaluated on random test inputs)")
            write_equation_scores(file, result["equation_scores"]; indent="    ", show_match_assessment=true)
        end
        
        println(file)
        flush(file)
    catch e
        @error "Failed to write results for $(get(result, "problem_name", "unknown")) to file: $e"
        # Print a simple placeholder so we know something went wrong but keep going
        println(file, "FAILED TO WRITE FULL RESULT FOR: $(get(result, "problem_name", "unknown"))")
        println(file, "Error: $e")
        println(file)
        flush(file)
    end
end

"""
    print_failure_diagnostics(problem_name, result)

Print diagnostic information for failed tests.
"""
function print_failure_diagnostics(problem_name, result)
    if get(result, "timeout", false)
        println("\n⏱ $problem_name TIMEOUT after $(result["discovery_time"])s")
    else
        println("\n⚠ $problem_name FAILED:")
        println("  Integration loss: $(result["integration_loss"])")
        println("  Discovery time: $(result["discovery_time"])s")
        
        if haskey(result, "error") && result["error"] !== nothing
            println("  Error: $(result["error"])")
        end
    end
end
"""    print_equation_similarity(result)

Print equation similarity scores to console.
"""
function print_equation_similarity(result)
    if haskey(result, "equation_scores") && !isempty(result["equation_scores"])
        println("\n" * "="^80)
        println("Equation Similarity Analysis")
        println("="^80)
        println()
        write_equation_scores(stdout, result["equation_scores"]; indent="", show_match_assessment=true)
        println("="^80)
    end
end

"""
    write_summary(file, results)

Write summary statistics to the results file.
"""
function write_summary(file, results)
    successes = count(r -> r["success"], values(results))
    failures = length(results) - successes
    
    println(file, "="^80)
    println(file, "SUMMARY")
    println(file, "="^80)
    println(file, "Completed: $(now())")
    println(file, "✓ Successful: $successes / $(length(results))")
    println(file, "✗ Failed: $failures / $(length(results))")
    
    if failures > 0
        println(file, "\nFailed problems:")
        for (name, result) in sort(collect(results), by=x->x[1])
            if !result["success"]
                loss = result["integration_loss"]
                if get(result, "timeout", false)
                    println(file, "  - $name (TIMEOUT)")
                else
                    println(file, "  - $name (loss: $(round(loss, digits=4)))")
                end
            end
        end
    end
    
    println(file, "="^80)
end

"""
    print_final_summary(results_summary, results_file)

Print final summary statistics to console.
"""
function print_final_summary(results_summary, results_file)
    println()
    println("="^80)
    println("Benchmark Test Suite Summary")
    println("="^80)

    successes = count(r -> r["success"], values(results_summary))
    failures = length(results_summary) - successes

    println("✓ Successful: $successes / $(length(results_summary))")
    println("✗ Failed: $failures / $(length(results_summary))")

    if failures > 0
        println("\nFailed problems:")
        for (name, result) in sort(collect(results_summary), by=x->x[1])
            if !result["success"]
                if get(result, "timeout", false)
                    println("  - $name (TIMEOUT)")
                else
                    loss = result["integration_loss"]
                    println("  - $name (loss: $(round(loss, digits=4)))")
                end
            end
        end
    end

    println("="^80)
    println("\nResults written to: $results_file")
end

"""
    write_file_header(file, test_options, num_trajectories, noise_std, max_problems, timeout_seconds, timeout_problems, n_points=nothing, problems_override=nothing)

Write header to results file.
"""
function write_file_header(file, test_options, num_trajectories, noise_std, max_problems, timeout_seconds, timeout_problems, n_points=nothing, problems_override=nothing)
    println(file, "="^80)
    println(file, "ODE Discovery Benchmark Test Results")
    println(file, "Num trajectories: $num_trajectories")
    println(file, "Noise level: $noise_std")
    println(file, "Started: $(now())")
    println(file)
    println(file, "Runtime Environment:")
    println(file, "  - System CPU threads (logical): $(Sys.CPU_THREADS)")
    println(file, "  - Julia threads (Threads.nthreads()): $(Base.Threads.nthreads())")
    blas_threads = try
        BLAS.get_num_threads()
    catch
        "unknown"
    end
    println(file, "  - BLAS threads: $blas_threads")
    omp = get(ENV, "OMP_NUM_THREADS", "not set")
    println(file, "  - OMP_NUM_THREADS: $omp")
    println(file)
    println(file, "Configuration:")
    println(file, "  - niterations_derivative: $(test_options.niterations_derivative)")
    println(file, "  - niterations_integration: $(test_options.niterations_integration)")
    println(file, "  - complexity_derivative: $(test_options.complexity_derivative)")
    println(file, "  - complexity_integration: $(test_options.complexity_integration)")
    binary_ops_str = join(string.(test_options.binary_operators), ", ")
    unary_ops_str = isempty(test_options.unary_operators) ? "none" : join(string.(test_options.unary_operators), ", ")
    println(file, "  - binary_operators: $binary_ops_str")
    println(file, "  - unary_operators: $unary_ops_str")
    println(file, "  - parallelism: $(test_options.parallelism)")
    println(file, "  - verbose: $(test_options.verbose)")
    n_points_msg = n_points === nothing ? "problem default" : string(n_points)
    println(file, "  - n_points: $n_points_msg")
    timeout_msg = timeout_seconds === nothing ? "none (no timeout)" : "$(timeout_seconds)s"
    println(file, "  - timeout_seconds: $timeout_msg")
    max_msg = max_problems === nothing ? "none (all problems)" : string(max_problems)
    println(file, "  - max_problems_to_test: $max_msg")
    override_msg = problems_override === nothing ? "none" : join(problems_override, ", ")
    println(file, "  - problems_override: $override_msg")
    println(file, "  - timeout_problems: ")
    for p in timeout_problems
        println(file, "      - $p")
    end
    println(file, "="^80)
    println(file)
end

"""
    save_results_json(file_path, results)

Save benchmark results summary to a JSON file for machine readability.
"""
function save_results_json(file_path, results)
    try
        open(file_path, "w") do f
            JSON.print(f, results, 4)
        end
        println("JSON results saved to: $file_path")
    catch e
        @warn "Failed to save JSON results to $file_path: $e"
        # Try a more robust print if possible, or just skip
    end
end

"""
    save_results_csv(file_path, results)

Save benchmark results summary to a CSV file for analysis (e.g., pandas).
Flattens the summary to one row per problem with key metrics.
"""
function save_results_csv(file_path, results)
    rows = []
    
    for (name, result) in sort(collect(results), by=x->x[1])
        try
            # Base metrics
            row = Dict(
                "problem" => name,
                "success" => get(result, "success", false),
                "discovery_time" => get(result, "discovery_time", 0.0),
                "integration_loss" => get(result, "integration_loss", NaN),
                "n_states" => get(result, "n_states", 0),
                "timeout" => get(result, "timeout", false)
            )
            
            # Add average equation similarity if available
            if haskey(result, "equation_scores") && !isempty(result["equation_scores"])
                scores = result["equation_scores"]
                valid_scores = filter(s -> haskey(s, "rmse") && !isnan(s["rmse"]), scores)
                
                if !isempty(valid_scores)
                    row["avg_rmse"] = sum(s["rmse"] for s in valid_scores) / length(valid_scores)
                    row["avg_r2"] = sum(s["r2"] for s in valid_scores) / length(valid_scores)
                    row["min_r2"] = minimum(s["r2"] for s in valid_scores)
                else
                    row["avg_rmse"] = NaN
                    row["avg_r2"] = NaN
                    row["min_r2"] = NaN
                end
            else
                row["avg_rmse"] = NaN
                row["avg_r2"] = NaN
                row["min_r2"] = NaN
            end
            
            push!(rows, row)
        catch e
            @warn "Failed to process result for $name in CSV export: $e"
            continue
        end
    end
    
    try
        if !isempty(rows)
            df = DataFrame(rows)
            CSV.write(file_path, df)
            println("CSV results saved to: $file_path")
        else
            @warn "No valid rows to write to CSV"
        end
    catch e
        @warn "Failed to write CSV file $file_path: $e"
    end
end
