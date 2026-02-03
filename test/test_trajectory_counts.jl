"""
test_trajectory_counts.jl

Test suite to verify that the num_trajectories parameter correctly generates
the expected number of trajectories for each benchmark problem.

This validates that:
1. Different num_trajectories values produce different numbers of experiments
2. The actual count matches the requested count
3. All benchmark problems support multi-trajectory loading

Run with: julia --project=. test/test_trajectory_counts.jl
"""

# =============================================================================
# Setup
# =============================================================================

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using Random
# Set random seed for reproducibility
Random.seed!(42)

include("../benchmark/benchmarkProblems/BenchmarkSystems.jl")
using .BenchmarkSystems
using Test
using Statistics

# =============================================================================
# Helper Functions
# =============================================================================

"""
    verify_trajectories_different(experiments)

Verify that multiple trajectories are actually different from each other.
Checks initial conditions, inputs, and actual trajectory data.

Returns (all_different, num_unique, details)
"""
function verify_trajectories_different(experiments)
    if length(experiments) <= 1
        return true, length(experiments), "Only one trajectory"
    end
    
    # Check 1: Initial conditions should be different (if X0 is available)
    unique_X0 = 1
    has_X0 = all(haskey(exp, :X0) for exp in experiments)
    if has_X0
        X0_list = [exp[:X0] for exp in experiments]
        unique_X0 = length(unique(X0_list))
    end
    
    # Check 2: Check if inputs are different (for problems with varying inputs)
    has_varying_inputs = false
    if haskey(experiments[1], :inputs) && !isempty(experiments[1][:inputs])
        # Check if different experiments have different input values
        input_signatures = []
        for exp in experiments
            if haskey(exp, :inputs)
                # Create a signature from input values
                sig = string(sort(collect(exp[:inputs])))
                push!(input_signatures, sig)
            end
        end
        unique_inputs = length(unique(input_signatures))
        has_varying_inputs = unique_inputs > 1
    end
    
    # Check 3: Trajectory data should be different
    # Compare the actual trajectories (handle different sizes gracefully)
    X_data = [exp[:X] for exp in experiments]
    all_identical = true
    try
        for i in 2:length(X_data)
            # Check if arrays are same size first
            if size(X_data[1]) != size(X_data[i])
                all_identical = false
                break
            end
            # Then check if values are different
            if !all(isapprox.(X_data[1], X_data[i], rtol=1e-10))
                all_identical = false
                break
            end
        end
    catch e
        # If comparison fails, assume they're different
        all_identical = false
    end
    
    # Trajectories are considered "different" if:
    # - They have different X0, OR
    # - They have different inputs (which makes trajectories different), OR  
    # - The actual data is different
    all_different = (unique_X0 > 1) || has_varying_inputs || !all_identical
    
    details = has_X0 ? "X0: $unique_X0 unique / $(length(experiments))" : "X0: not available"
    if has_varying_inputs
        details *= ", Inputs: VARYING"
    end
    details *= ", Trajectories: " * (all_identical ? "IDENTICAL" : "DIFFERENT")
    
    return all_different, unique_X0, details
end

# =============================================================================
# Trajectory Count Validation Tests
# =============================================================================

"""
    test_trajectory_counts()

Test that num_trajectories parameter correctly generates the expected number
of trajectories for each problem.
"""
function test_trajectory_counts()
    println("\n" * "="^80)
    println("Testing Trajectory Count Generation")
    println("="^80)
    
    # Get ALL problems to test
    all_problems_dict = BenchmarkSystems.list_problems()
    all_problems = sort(collect(keys(all_problems_dict)))
    
    println("Testing $(length(all_problems)) benchmark problems")
    println()
    
    # Test different trajectory counts
    trajectory_counts = [1, 3, 10]
    
    test_results = Dict()
    trajectories_not_different = []
    
    for problem_name in all_problems
        println("Testing problem: $problem_name")
        problem_results = Dict()
        
        for num_traj in trajectory_counts
            try
                # Load problem with specified number of trajectories
                experiments = BenchmarkSystems.load_problem(problem_name, num_trajectories=num_traj)
                
                # Count actual trajectories
                actual_count = length(experiments)
                
                # Check if it matches expected
                matches = actual_count == num_traj
                
                # Verify trajectories are actually different when num_traj > 1
                are_different = true
                uniqueness_details = ""
                if num_traj > 1
                    are_different, num_unique, details = verify_trajectories_different(experiments)
                    uniqueness_details = details
                    if !are_different
                        push!(trajectories_not_different, (problem_name, num_traj, details))
                    end
                end
                
                status = matches && are_different ? "✓" : "✗"
                suffix = num_traj > 1 && are_different ? " (unique)" : 
                         num_traj > 1 && !are_different ? " (⚠ DUPLICATES)" : ""
                
                println("  $status Requested: $num_traj, Got: $actual_count$suffix")
                
                problem_results[num_traj] = Dict(
                    "requested" => num_traj,
                    "actual" => actual_count,
                    "matches" => matches,
                    "are_different" => are_different,
                    "uniqueness_details" => uniqueness_details
                )
                
            catch e
                println("  ✗ Error with num_trajectories=$num_traj: ", sprint(showerror, e))
                problem_results[num_traj] = Dict(
                    "requested" => num_traj,
                    "actual" => 0,
                    "matches" => false,
                    "error" => string(e)
                )
            end
        end
        
        test_results[problem_name] = problem_results
    end
    
    # Print summary
    println("\n" * "="^80)
    println("Trajectory Count Test Summary")
    println("="^80)
    
    all_passed = true
    for problem_name in sort(collect(keys(test_results)))
        problem_results = test_results[problem_name]
        problem_passed = all(r["matches"] && r["are_different"] for r in values(problem_results) if haskey(r, "matches"))
        status = problem_passed ? "✓ PASS" : "✗ FAIL"
        println("$status : $problem_name")
        
        if !problem_passed
            all_passed = false
            for num_traj in sort(collect(keys(problem_results)))
                result = problem_results[num_traj]
                if !get(result, "matches", false)
                    println("    Failed count for num_trajectories=$num_traj: " *
                           "expected $(result["requested"]), got $(result["actual"])")
                    if haskey(result, "error")
                        println("      Error: $(result["error"])")
                    end
                elseif !get(result, "are_different", true)
                    println("    Failed uniqueness for num_trajectories=$num_traj: " *
                           "trajectories are not different")
                    println("      $(result["uniqueness_details"])")
                end
            end
        end
    end
    
    # Report on trajectory uniqueness issues
    if !isempty(trajectories_not_different)
        println("\n⚠️  Trajectory Uniqueness Issues:")
        for (prob, num, details) in trajectories_not_different
            println("  - $prob (n=$num): $details")
        end
    end
    
    println("="^80)
    
    return test_results, all_passed
end

# =============================================================================
# Run Tests
# =============================================================================

@testset "Trajectory Count Validation" begin
    println("\n🔍 Running trajectory count validation tests...")
    test_results, all_tests_passed = test_trajectory_counts()
    
    if all_tests_passed
        println("\n✅ All trajectory count tests PASSED")
    else
        println("\n⚠️  Some trajectory count tests FAILED - see summary above")
    end
    
    # Test assertions for each problem
    for (problem_name, problem_results) in test_results
        @testset "$problem_name" begin
            for (num_traj, result) in problem_results
                if !haskey(result, "error")
                    @test result["matches"] == true
                    @test result["actual"] == result["requested"]
                    # Only check uniqueness for multi-trajectory cases
                    if result["requested"] > 1
                        @test result["are_different"] == true
                    end
                else
                    @test_broken result["matches"] == true
                end
            end
        end
    end
    
    # Overall assertion
    @test all_tests_passed
end

println("\n" * "="^80)
println("Test suite complete!")
println("="^80)
