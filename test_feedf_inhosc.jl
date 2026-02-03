"""
Test script for Feedf and Inhosc problems with unified architecture
"""

using Pkg
Pkg.activate(".")

push!(LOAD_PATH, joinpath(@__DIR__, "benchmark/benchmarkProblems"))

using UnifiedBenchmarkSystems
using .UnifiedBenchmarkSystems: Feedf1, Feedf2, Inhosc1, Inhosc2, BaseProblemModule

println("="^60)
println("Testing Feedf and Inhosc Problems")
println("="^60)

# Test Feedf1
println("\n1. Testing Feedf1...")
try
    prob1 = Feedf1()
    println("   ✓ Feedf1() constructor works")
    println("   - States: $(prob1.n_states)")
    println("   - Inputs: $(prob1.n_inputs)")
    println("   - Default IC: $(prob1.default_ic)")
    
    # Generate data
    experiments = BaseProblemModule.generate_experiments(prob1; num_trajectories=1)
    println("   ✓ Generated $(length(experiments)) experiment(s)")
    
    exp = experiments[1]
    println("   - Time points: $(length(exp[:t]))")
    println("   - Data shape: $(size(exp[:X]))")
    println("   - Input keys: $(keys(exp[:inputs]))")
    
    # Get equations
    eqs = BaseProblemModule.get_equation_strings(prob1)
    println("   ✓ Equations:")
    for (i, eq) in enumerate(eqs)
        println("      $eq")
    end
    
    println("   ✅ Feedf1 PASSED")
catch e
    println("   ❌ Feedf1 FAILED: $e")
    rethrow(e)
end

# Test Feedf2
println("\n2. Testing Feedf2...")
try
    prob2 = Feedf2()
    println("   ✓ Feedf2() constructor works")
    println("   - Variant: $(prob2.variant)")
    
    experiments = BaseProblemModule.generate_experiments(prob2; num_trajectories=1)
    println("   ✓ Generated $(length(experiments)) experiment(s)")
    println("   ✅ Feedf2 PASSED")
catch e
    println("   ❌ Feedf2 FAILED: $e")
    rethrow(e)
end

# Test Inhosc1
println("\n3. Testing Inhosc1...")
try
    prob1 = Inhosc1()
    println("   ✓ Inhosc1() constructor works")
    println("   - States: $(prob1.n_states)")
    println("   - Inputs: $(prob1.n_inputs)")
    println("   - Default IC: $(prob1.default_ic)")
    
    # Generate data
    experiments = BaseProblemModule.generate_experiments(prob1; num_trajectories=1)
    println("   ✓ Generated $(length(experiments)) experiment(s)")
    
    exp = experiments[1]
    println("   - Time points: $(length(exp[:t]))")
    println("   - Data shape: $(size(exp[:X]))")
    
    # Get equations
    eqs = BaseProblemModule.get_equation_strings(prob1)
    println("   ✓ Equations:")
    for (i, eq) in enumerate(eqs)
        println("      $eq")
    end
    
    println("   ✅ Inhosc1 PASSED")
catch e
    println("   ❌ Inhosc1 FAILED: $e")
    rethrow(e)
end

# Test Inhosc2
println("\n4. Testing Inhosc2...")
try
    prob2 = Inhosc2()
    println("   ✓ Inhosc2() constructor works")
    println("   - States: $(prob2.n_states)")  # Should be 4 for variant 2
    println("   - Variant: $(prob2.variant)")
    
    experiments = BaseProblemModule.generate_experiments(prob2; num_trajectories=1)
    println("   ✓ Generated $(length(experiments)) experiment(s)")
    
    exp = experiments[1]
    println("   - Data shape: $(size(exp[:X]))")
    
    # Get equations
    eqs = BaseProblemModule.get_equation_strings(prob2)
    println("   ✓ Equations:")
    for (i, eq) in enumerate(eqs)
        println("      $eq")
    end
    
    println("   ✅ Inhosc2 PASSED")
catch e
    println("   ❌ Inhosc2 FAILED: $e")
    rethrow(e)
end

# Test loading via unified interface
println("\n5. Testing load_problem_unified...")
try
    for name in ["feedf1", "feedf2", "inhosc1", "inhosc2"]
        experiments = load_problem_unified(name; num_trajectories=1)
        println("   ✓ Loaded $name: $(length(experiments)) experiment(s)")
    end
    println("   ✅ Unified loading PASSED")
catch e
    println("   ❌ Unified loading FAILED: $e")
    rethrow(e)
end

println("\n" * "="^60)
println("All tests PASSED! ✅")
println("="^60)
