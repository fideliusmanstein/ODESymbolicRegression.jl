"""
benchmark_reporting.jl

Reporting and output functions for ODE discovery benchmark tests.
"""

using Dates

"""
    print_test_header(problems, test_options, num_trajectories, noise_std, max_problems, timeout_seconds)

Print the benchmark test suite header with configuration information.
"""
function print_test_header(problems, test_options, num_trajectories, noise_std, max_problems, timeout_seconds)
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
    timeout_msg = timeout_seconds === nothing ? "none (no timeout)" : "$(timeout_seconds)s"
    println("  - Timeout per system: $timeout_msg")
    println("="^80)
    println()
end

"""
    write_result_to_file(file, result)

Write a single test result to the output file.
"""
function write_result_to_file(file, result)
    println(file, "Problem: $(result["problem_name"])")
    println(file, "  Success: $(result["success"])")
    println(file, "  Integration Loss: $(result["integration_loss"])")
    println(file, "  Discovery Time: $(result["discovery_time"])s")
    println(file, "  N States: $(result["n_states"])")
    
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
        for score in result["equation_scores"]
            i = score["equation_index"]
            println(file, "    Equation $i:")
            if haskey(score, "error")
                println(file, "      Error: $(score["error"])")
            else
                println(file, "      RMSE: ", @sprintf("%.6e", score["rmse"]))
                println(file, "      NRMSE: ", @sprintf("%.4f", score["nrmse"]))
                println(file, "      MAE: ", @sprintf("%.6e", score["mae"]))
                println(file, "      Max Error: ", @sprintf("%.6e", score["max_error"]))
                println(file, "      R²: ", @sprintf("%.6f", score["r2"]))
                println(file, "      Valid samples: $(score["valid_samples"])")
            end
        end
    end
    
    println(file)
    flush(file)
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

"""
    write_summary(file, results)

Write summary statistics to the output file.
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
    write_file_header(file, num_trajectories, noise_std)

Write header to results file.
"""
function write_file_header(file, num_trajectories, noise_std)
    println(file, "="^80)
    println(file, "ODE Discovery Benchmark Test Results")
    println(file, "Multi-Trajectory Evaluation ($(num_trajectories) ICs per experiment)")
    println(file, "Noise level: $noise_std")
    println(file, "Started: $(now())")
    println(file, "="^80)
    println(file)
end
