"""
Test all refactored problems with the unified architecture
"""

using Pkg
Pkg.activate(".")

include("benchmark/benchmarkProblems/UnifiedBenchmarkSystems.jl")
using .UnifiedBenchmarkSystems

println("="^80)
println("Testing Unified Problem Architecture - All Implementations")
println("="^80)

test_results = Dict()

# Test SimpleLin problems
println("\n[Test 1] SimpleLin Problems")
println("-"^80)
for problem_name in ["simpleLin1", "simpleLin2"]
    try
        println("\nTesting $problem_name...")
        
        # Test single trajectory
        experiments_single = load_problem_unified(problem_name, num_trajectories=1)
        println("  ✓ Single trajectory: $(length(experiments_single)) experiments")
        
        # Test multiple trajectories
        experiments_multi = load_problem_unified(problem_name, num_trajectories=3)
        println("  ✓ Multiple trajectories: $(length(experiments_multi)) experiments (expected: 24)")
        
        if length(experiments_multi) != 24
            error("Expected 24 experiments, got $(length(experiments_multi))")
        end
        
        # Test tree access
        trees = get_problem_trees(problem_name)
        println("  ✓ Expression trees: $(length(trees)) equations")
        
        # Verify conservation law
        exp1_trajs = filter(e -> e[:experiment] == 1, experiments_multi)
        all_valid = true
        for traj in exp1_trajs
            ic_sum = traj[:ic].X3_0 + traj[:ic].X4_0 + traj[:ic].X5_0
            if abs(ic_sum - 1.0) > 1e-10
                all_valid = false
                break
            end
        end
        
        if all_valid
            println("  ✓ Conservation law verified (X3+X4+X5=1.0)")
        else
            error("Conservation law violated!")
        end
        
        test_results[problem_name] = "PASS"
        
    catch e
        println("  ✗ FAILED: $e")
        test_results[problem_name] = "FAIL: $e"
        # Continue testing other problems
    end
end

# Test SimpleFb problems
println("\n[Test 2] SimpleFb Problems")
println("-"^80)
for problem_name in ["simpleFb1", "simpleFb2", "simpleFb3", "simpleFb4"]
    try
        println("\nTesting $problem_name...")
        
        # Get expected number of experiments
        expected = startswith(problem_name, "simpleFb3") || startswith(problem_name, "simpleFb4") ? 1 : 4
        
        experiments_single = load_problem_unified(problem_name, num_trajectories=1)
        println("  ✓ Single trajectory: $(length(experiments_single)) experiments (expected: $expected)")
        
        if length(experiments_single) != expected
            error("Expected $expected experiments, got $(length(experiments_single))")
        end
        
        # Test multiple trajectories
        experiments_multi = load_problem_unified(problem_name, num_trajectories=2)
        println("  ✓ Multiple trajectories: $(length(experiments_multi)) experiments (expected: $(expected*2))")
        
        if length(experiments_multi) != expected * 2
            error("Expected $(expected*2) experiments, got $(length(experiments_multi))")
        end
        
        # Test tree access
        trees = get_problem_trees(problem_name)
        println("  ✓ Expression trees: $(length(trees)) equations")
        
        test_results[problem_name] = "PASS"
        
    catch e
        println("  ✗ FAILED: $e")
        test_results[problem_name] = "FAIL: $e"
    end
end

# Test Osc problems
println("\n[Test 3] Osc Problems")
println("-"^80)
for problem_name in ["osc1", "osc2"]
    try
        println("\nTesting $problem_name...")
        
        experiments_single = load_problem_unified(problem_name, num_trajectories=1)
        println("  ✓ Single trajectory: $(length(experiments_single)) experiment")
        
        if length(experiments_single) != 1
            error("Expected 1 experiment, got $(length(experiments_single))")
        end
        
        # Test multiple trajectories
        experiments_multi = load_problem_unified(problem_name, num_trajectories=5)
        println("  ✓ Multiple trajectories: $(length(experiments_multi)) experiments (expected: 5)")
        
        if length(experiments_multi) != 5
            error("Expected 5 experiments, got $(length(experiments_multi))")
        end
        
        # Test tree access
        trees = get_problem_trees(problem_name)
        println("  ✓ Expression trees: $(length(trees)) equations")
        
        # Check data shape
        exp = experiments_single[1]
        if size(exp[:X], 2) != 3
            error("Expected 3 states, got $(size(exp[:X], 2))")
        end
        println("  ✓ Data shape: $(size(exp[:X]))")
        
        test_results[problem_name] = "PASS"
        
    catch e
        println("  ✗ FAILED: $e")
        test_results[problem_name] = "FAIL: $e"
    end
end

# Test list_problems
println("\n[Test 4] Problem Listing")
println("-"^80)
try
    problems = list_problems_unified()
    println("Available problems:")
    for name in sort(collect(keys(problems)))
        info = problems[name]
        println("  $name: $(info[:states]) states, $(info[:inputs]) inputs - $(info[:status])")
    end
    test_results["list_problems"] = "PASS"
catch e
    println("  ✗ FAILED: $e")
    test_results["list_problems"] = "FAIL: $e"
end

# Summary
println("\n" * "="^80)
println("TEST SUMMARY")
println("="^80)

passed = count(v -> v == "PASS", values(test_results))
total = length(test_results)

for (name, result) in sort(collect(test_results))
    status = result == "PASS" ? "✓" : "✗"
    println("  $status $name: $result")
end

println("\n" * "="^80)
if passed == total
    println("ALL TESTS PASSED! ($passed/$total)")
    println("="^80)
    println("\n✅ Unified architecture working correctly for all implemented problems")
    println("✅ num_trajectories support verified")
    println("✅ Tree representation working")
    println("✅ Conservation laws enforced")
else
    println("SOME TESTS FAILED ($passed/$total passed)")
    println("="^80)
end
