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

include("../benchmark/benchmarkProblems/BenchmarkSystems.jl")
using .BenchmarkSystems
using Test

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
                status = matches ? "✓" : "✗"
                
                println("  $status Requested: $num_traj, Got: $actual_count")
                
                problem_results[num_traj] = Dict(
                    "requested" => num_traj,
                    "actual" => actual_count,
                    "matches" => matches
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
        problem_passed = all(r["matches"] for r in values(problem_results) if haskey(r, "matches"))
        status = problem_passed ? "✓ PASS" : "✗ FAIL"
        println("$status : $problem_name")
        
        if !problem_passed
            all_passed = false
            for num_traj in sort(collect(keys(problem_results)))
                result = problem_results[num_traj]
                if !get(result, "matches", false)
                    println("    Failed for num_trajectories=$num_traj: " *
                           "expected $(result["requested"]), got $(result["actual"])")
                    if haskey(result, "error")
                        println("      Error: $(result["error"])")
                    end
                end
            end
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
