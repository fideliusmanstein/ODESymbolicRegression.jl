"""
analyze_results.jl

Analysis tools for benchmark results.
Reads CSV summaries and JSON details to provide comprehensive analysis.
"""

using CSV
using DataFrames
using JSON
using Statistics
using Printf

"""
    analyze_benchmark_summary(csv_file)

Analyze benchmark results from CSV summary.

# Arguments
- `csv_file`: Path to summary CSV file

# Returns
- DataFrame with the loaded data

# Example
```julia
df = analyze_benchmark_summary("benchmark_results/summary_20260209_152233.csv")
```
"""
function analyze_benchmark_summary(csv_file)
    df = CSV.read(csv_file, DataFrame)
    
    println("\n" * "="^80)
    println("BENCHMARK ANALYSIS")
    println("="^80)
    println("Source: $csv_file")
    
    # Overall statistics
    n_total = nrow(df)
    n_success = count(df.success)
    n_failed = n_total - n_success
    
    println("\n📊 Overall Results:")
    println("  Total problems: $n_total")
    println("  ✓ Successful: $n_success ($(round(100*n_success/n_total, digits=1))%)")
    println("  ✗ Failed: $n_failed ($(round(100*n_failed/n_total, digits=1))%)")
    
    # Equation-level success
    successful = df[df.success .== true, :]
    if !isempty(successful)
        total_equations = sum(successful.n_equations_total)
        correct_equations = sum(successful.n_equations_correct)
        
        println("\n🎯 Equation Recovery (successful problems only):")
        println("  Total equations: $total_equations")
        println("  Correctly recovered (R² > 0.9): $correct_equations ($(round(100*correct_equations/total_equations, digits=1))%)")
        
        # Calculate average R² only from non-NaN values
        valid_r2 = successful.avg_r2[.!isnan.(successful.avg_r2)]
        if !isempty(valid_r2)
            println("  Average R² across all equations: $(round(mean(valid_r2), digits=3))")
        end
        
        # Perfect recovery (all equations correct)
        perfect = successful[successful.n_equations_correct .== successful.n_equations_total, :]
        partial = successful[successful.n_equations_correct .< successful.n_equations_total, :]
        println("  Perfect recovery (all equations): $(nrow(perfect)) / $(nrow(successful)) problems ($(round(100*nrow(perfect)/nrow(successful), digits=1))%)")
        println("  Partial recovery (some equations): $(nrow(partial)) / $(nrow(successful)) problems")
    end
    
    # Performance statistics
    if !isempty(successful)
        println("\n⏱️  Performance:")
        println("  Total discovery time: $(round(sum(successful.discovery_time), digits=1))s")
        println("  Avg discovery time: $(round(mean(successful.discovery_time), digits=1))s")
        println("  Median discovery time: $(round(median(successful.discovery_time), digits=1))s")
        println("  Min/Max time: $(round(minimum(successful.discovery_time), digits=1))s / $(round(maximum(successful.discovery_time), digits=1))s")
        
        # Filter finite values for loss statistics
        finite_losses = successful.integration_loss[isfinite.(successful.integration_loss)]
        if !isempty(finite_losses)
            println("  Avg integration loss: $(@sprintf("%.2e", mean(finite_losses)))")
            println("  Median integration loss: $(@sprintf("%.2e", median(finite_losses)))")
        end
    end
    
    # Error analysis
    if n_failed > 0
        failed = df[df.success .== false, :]
        println("\n❌ Failure Analysis:")
        
        # Group by error type
        error_groups = failed[failed.has_error .== true, :]
        if !isempty(error_groups)
            error_counts = combine(groupby(error_groups, :error_type), nrow => :count)
            sort!(error_counts, :count, rev=true)
            for row in eachrow(error_counts)
                if row.error_type != ""
                    println("  $(row.error_type): $(row.count)")
                end
            end
        end
        
        # Failed without explicit error
        no_error_fails = count(failed.has_error .== false)
        if no_error_fails > 0
            println("  Failed (no explicit error): $no_error_fails")
        end
    end
    
    # Per-state analysis
    if !isempty(df)
        println("\n📈 Success Rate by Problem Size:")
        by_states = combine(groupby(df, :n_states)) do g
            success_df = g[g.success .== true, :]
            (n_problems = nrow(g),
             success_rate = mean(g.success),
             avg_equations_correct = !isempty(success_df) ? 
                mean(success_df.n_equations_correct) : 0.0,
             avg_time = !isempty(success_df) ? mean(success_df.discovery_time) : NaN)
        end
        sort!(by_states, :n_states)
        
        for row in eachrow(by_states)
            time_str = isnan(row.avg_time) ? "N/A" : @sprintf("%.1fs", row.avg_time)
            println("  $(row.n_states) states: $(round(100*row.success_rate, digits=1))% success " *
                   "($(row.n_problems) problems), " *
                   "avg $(round(row.avg_equations_correct, digits=1))/$(row.n_states) equations correct, " *
                   "avg time $time_str")
        end
    end
    
    # Top performers
    if nrow(successful) > 0
        println("\n🏆 Top 5 Best Matches (by avg R²):")
        valid_r2_rows = successful[.!isnan.(successful.avg_r2), :]
        if nrow(valid_r2_rows) > 0
            top5 = sort(valid_r2_rows, :avg_r2, rev=true)[1:min(5, nrow(valid_r2_rows)), :]
            for row in eachrow(top5)
                println("  $(row.problem_name): R²=$(round(row.avg_r2, digits=4)), " *
                       "$(row.n_equations_correct)/$(row.n_equations_total) equations")
            end
        end
    end
    
    println("\n" * "="^80)
    
    return df
end

"""
    analyze_problem_details(json_file, problem_name)

Deep dive into specific problem from JSON detailed results.

# Arguments
- `json_file`: Path to detailed JSON file
- `problem_name`: Name of the problem to analyze

# Example
```julia
analyze_problem_details("benchmark_results/detailed_20260209_142430.json", "bifeedb1")
```
"""
function analyze_problem_details(json_file, problem_name)
    results = JSON.parsefile(json_file)
    
    problem_idx = findfirst(r -> r["problem_name"] == problem_name, results)
    if problem_idx === nothing
        println("❌ Problem not found: $problem_name")
        println("\nAvailable problems:")
        for r in results
            println("  - $(r["problem_name"])")
        end
        return
    end
    
    result = results[problem_idx]
    
    println("\n" * "="^80)
    println("DETAILED ANALYSIS: $problem_name")
    println("="^80)
    
    # Basic info
    println("\n📋 Basic Information:")
    println("  Success: $(result["success"])")
    println("  States: $(get(result, "n_states", "N/A"))")
    println("  Discovery time: $(@sprintf("%.2f", result["discovery_time"]))s")
    println("  Integration loss: $(@sprintf("%.6e", result["integration_loss"]))")
    if haskey(result, "initial_loss")
        println("  Initial loss: $(@sprintf("%.6e", result["initial_loss"]))")
        improvement = (result["initial_loss"] - result["integration_loss"]) / result["initial_loss"] * 100
        println("  Improvement: $(@sprintf("%.1f%%", improvement))")
    end
    
    # Error info
    if result["error"] !== nothing
        println("\n❌ Error: $(result["error"])")
        return
    end
    
    # Equations comparison
    println("\n📐 Ground Truth Equations:")
    for (i, eq) in enumerate(get(result, "ground_truth_equations", []))
        println("  $i: $eq")
    end
    
    println("\n🔍 Discovered Equations:")
    if haskey(result, "initial_equations")
        println("\n  Initial (Stage 1):")
        for (i, eq) in enumerate(result["initial_equations"])
            println("    X$i' = $eq")
        end
    end
    
    println("\n  Final (After Refinement):")
    for (i, eq) in enumerate(get(result, "discovered_equations", []))
        println("    X$i' = $eq")
    end
    
    # Equation-by-equation similarity
    if haskey(result, "equation_scores") && !isempty(result["equation_scores"])
        println("\n🎯 Equation Similarity Analysis:")
        println("  (Based on random test inputs)")
        
        for score in result["equation_scores"]
            i = score["equation_index"]
            r2 = score["r2"]
            
            # Determine match quality (handle both NaN and null values)
            match_quality, symbol = if r2 === nothing || isnan(r2)
                ("No valid samples", "⚠")
            elseif r2 > 0.99
                ("Excellent", "✓")
            elseif r2 > 0.9
                ("Good", "✓")
            elseif r2 > 0.7
                ("Fair", "~")
            else
                ("Poor", "✗")
            end
            
            # Format values (handle null)
            r2_str = r2 === nothing ? "N/A" : @sprintf("%.6f", r2)
            rmse_str = score["rmse"] === nothing ? "N/A" : @sprintf("%.2e", score["rmse"])
            nrmse_str = score["nrmse"] === nothing ? "N/A" : @sprintf("%.4f", score["nrmse"])
            mae_str = score["mae"] === nothing ? "N/A" : @sprintf("%.2e", score["mae"])
            maxerr_str = score["max_error"] === nothing ? "N/A" : @sprintf("%.2e", score["max_error"])
            
            println("\n  Equation $i: $symbol $match_quality")
            println("    R² = $r2_str")
            println("    RMSE = $rmse_str")
            println("    NRMSE = $nrmse_str")
            println("    MAE = $mae_str")
            println("    Max Error = $maxerr_str")
            println("    Valid samples = $(get(score, "valid_samples", 0))")
        end
        
        # Overall summary (handle both null and NaN values)
        r2_values = [s["r2"] for s in result["equation_scores"] 
                     if s["r2"] !== nothing && !isnan(s["r2"])]
        if !isempty(r2_values)
            avg_r2 = mean(r2_values)
            n_good = count(r2 -> r2 > 0.9, r2_values)
            println("\n  Overall: $(length(r2_values)) equations, $n_good correctly recovered (R² > 0.9)")
            println("  Average R²: $(@sprintf("%.4f", avg_r2))")
        end
    end
    
    println("\n" * "="^80)
end

"""
    compare_runs(csv_files...)

Compare multiple benchmark runs side-by-side.

# Arguments
- `csv_files...`: Paths to summary CSV files to compare

# Example
```julia
compare_runs(
    "benchmark_results/summary_20260209_120000.csv",
    "benchmark_results/summary_20260209_140000.csv"
)
```
"""
function compare_runs(csv_files...)
    if length(csv_files) < 2
        println("❌ Need at least 2 CSV files to compare")
        return
    end
    
    println("\n" * "="^80)
    println("BENCHMARK COMPARISON")
    println("="^80)
    
    dfs = [CSV.read(f, DataFrame) for f in csv_files]
    labels = ["Run $i" for i in 1:length(csv_files)]
    
    # Compare overall success rates
    println("\n📊 Success Rates:")
    for (i, df) in enumerate(dfs)
        n_success = count(df.success)
        n_total = nrow(df)
        println("  $(@sprintf("%-8s", labels[i])): $n_success/$n_total ($(round(100*n_success/n_total, digits=1))%)")
    end
    
    # Compare equation recovery
    println("\n🎯 Equation Recovery Rates:")
    for (i, df) in enumerate(dfs)
        successful = df[df.success .== true, :]
        if !isempty(successful)
            total_eq = sum(successful.n_equations_total)
            correct_eq = sum(successful.n_equations_correct)
            println("  $(@sprintf("%-8s", labels[i])): $correct_eq/$total_eq ($(round(100*correct_eq/total_eq, digits=1))%)")
        else
            println("  $(@sprintf("%-8s", labels[i])): No successful runs")
        end
    end
    
    # Compare performance
    println("\n⏱️  Average Discovery Time:")
    for (i, df) in enumerate(dfs)
        successful = df[df.success .== true, :]
        if !isempty(successful)
            avg_time = mean(successful.discovery_time)
            println("  $(@sprintf("%-8s", labels[i])): $(@sprintf("%.2f", avg_time))s")
        else
            println("  $(@sprintf("%-8s", labels[i])): N/A")
        end
    end
    
    println("\n" * "="^80)
end

println("\n" * "="^80)
println("Benchmark Analysis Tools Loaded")
println("="^80)
println("\nAvailable functions:")
println("  analyze_benchmark_summary(csv_file)")
println("  analyze_problem_details(json_file, problem_name)")
println("  compare_runs(csv_file1, csv_file2, ...)")
println("\nExample usage:")
println("  df = analyze_benchmark_summary(\"benchmark_results/summary_TIMESTAMP.csv\")")
println("  analyze_problem_details(\"benchmark_results/detailed_TIMESTAMP.json\", \"bifeedb1\")")
println("="^80)
