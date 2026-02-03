"""
Test that all benchmark problems support the noise_std parameter
"""

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

include("../benchmark/benchmarkProblems/BenchmarkSystems.jl")
using .BenchmarkSystems
using Test
using Statistics
using Random

# Set random seed for reproducibility
Random.seed!(42)

"""
Check if noise was actually applied by comparing clean vs noisy data.
Uses statistical test: noisy data should have higher variance than clean data.
"""
function verify_noise_applied(X_clean, X_noisy)
    # Extract just the state data matrices
    if isa(X_clean, Tuple)
        X_clean_data = X_clean[2]
        X_noisy_data = X_noisy[2]
    else
        X_clean_data = X_clean
        X_noisy_data = X_noisy
    end
    
    # Calculate variance of differences - should be non-zero if noise was added
    diff = X_noisy_data - X_clean_data
    variance = var(diff)
    
    # Also check that at least some values are different
    any_different = any(abs.(diff) .> 1e-10)
    
    return variance > 1e-10 && any_different
end

@testset "Noise Parameter Support" begin
    println("\n" * "="^80)
    println("Testing noise_std parameter support for all problem types")
    println("="^80)
    
    # Get all problems from the registry
    all_problems = list_problems()
    
    # Extract unique problem prefixes (module types)
    problem_prefixes = unique([BenchmarkSystems.find_problem_config(name)[1] for name in keys(all_problems)])
    
    println("Found $(length(problem_prefixes)) unique problem types to test")
    
    failed_problems = []
    noise_not_applied = []
    
    for prefix in sort(problem_prefixes)
        @testset "$prefix" begin
            # Get configuration for this problem type
            _, module_ref, _, data_func, returns_3tuple, needs_inputs = BenchmarkSystems.find_problem_config(prefix * "1")
            
            gen_func = getfield(module_ref, data_func)
            
            # Build base arguments
            base_args = Dict{Symbol, Any}()
            
            # Add input parameters based on problem type
            if prefix == "simpleLin" || prefix == "metabol"
                base_args[:X1_const] = 3.0
                base_args[:X2_const] = 2.0
            elseif prefix == "feedf"
                base_args[:In1_const] = 1.0
                base_args[:In2_const] = 1.0
            elseif prefix == "inhosc"
                base_args[:In_const] = 1.0
                base_args[:Out_const] = 1.0
            elseif prefix == "ss_cascade"
                base_args[:X4_const] = 5.0
            elseif prefix == "gma_feedf"
                base_args[:In1_const] = 1.0
                base_args[:In2_const] = 1.0
            elseif prefix == "gma_inhosc"
                base_args[:In_const] = 1.0
                base_args[:Out_const] = 1.0
            end
            
            # Test with noise_std = 0.0 (no noise)
            local result_clean
            try
                args = merge(base_args, Dict(:noise_std => 0.0))
                result_clean = gen_func(; args...)
                println("✓ $prefix: noise_std=0.0 works")
                @test true
            catch e
                println("✗ $prefix: FAILED with noise_std=0.0")
                println("  Error: $e")
                push!(failed_problems, (prefix, "noise_std=0.0", e))
                @test false
                continue
            end
            
            # Test with noise_std = 0.1 (10% noise) and verify noise is applied
            local result_noisy
            try
                # Set seed for reproducibility, but noise should still be different
                Random.seed!(12345)
                args = merge(base_args, Dict(:noise_std => 0.1))
                result_noisy = gen_func(; args...)
                
                # Verify noise was actually applied
                if verify_noise_applied(result_clean, result_noisy)
                    println("✓ $prefix: noise_std=0.1 works and noise is applied")
                    @test true
                else
                    println("⚠ $prefix: noise_std=0.1 works but NO NOISE detected")
                    push!(noise_not_applied, prefix)
                    @test false
                end
            catch e
                println("✗ $prefix: FAILED with noise_std=0.1")
                println("  Error: $e")
                push!(failed_problems, (prefix, "noise_std=0.1", e))
                @test false
            end
            
            # Test with noise_std = 0.3 (30% noise)
            try
                args = merge(base_args, Dict(:noise_std => 0.3))
                result = gen_func(; args...)
                println("✓ $prefix: noise_std=0.3 works")
                @test true
            catch e
                println("✗ $prefix: FAILED with noise_std=0.3")
                println("  Error: $e")
                push!(failed_problems, (prefix, "noise_std=0.3", e))
                @test false
            end
        end
    end
    
    println("\n" * "="^80)
    if isempty(failed_problems) && isempty(noise_not_applied)
        println("✅ All $(length(problem_prefixes)) problem types support noise_std parameter")
        println("✅ All problems correctly apply noise to data")
    else
        if !isempty(failed_problems)
            println("❌ $(length(failed_problems)) test(s) failed:")
            for (name, test, err) in failed_problems
                println("  - $name ($test): $err")
            end
        end
        if !isempty(noise_not_applied)
            println("⚠ $(length(noise_not_applied)) problem(s) don't apply noise:")
            for name in noise_not_applied
                println("  - $name")
            end
        end
    end
    println("="^80)
end
