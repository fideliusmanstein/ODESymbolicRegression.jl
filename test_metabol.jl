"""
Test script for Metabol problems with unified architecture
"""

using Pkg
Pkg.activate(".")

push!(LOAD_PATH, joinpath(@__DIR__, "benchmark/benchmarkProblems"))

using UnifiedBenchmarkSystems
using .UnifiedBenchmarkSystems: Metabol1, Metabol2, Metabol3, BaseProblemModule

println("="^60)
println("Testing Metabol Problems")
println("="^60)

# Test Metabol1
println("\n1. Testing Metabol1...")
try
    prob1 = Metabol1()
    println("   ✓ Metabol1() constructor works")
    println("   - States: $(prob1.n_states)")
    println("   - Inputs: $(prob1.n_inputs)")
    println("   - Variant: $(prob1.variant)")
    println("   - Default IC: $(prob1.default_ic)")
    println("   - Noise: $(prob1.default_noise)")
    println("   - N points: $(prob1.default_n_points)")
    println("   - N experiments: $(length(prob1.experiment_configs))")
    
    # Generate data for one experiment
    exp_config = prob1.experiment_configs[1]
    input_vals = Dict{Symbol,Function}(
        :X1 => (t -> exp_config.X1),
        :X2 => (t -> exp_config.X2)
    )
    t, X, inputs = BaseProblemModule.generate_data(
        prob1;
        X0=exp_config.X0,
        input_values=input_vals
    )
    println("   ✓ Generated data")
    println("   - Time points: $(length(t))")
    println("   - Data shape: $(size(X))")
    println("   - Input keys: $(keys(inputs))")
    
    # Generate experiments
    experiments = BaseProblemModule.generate_experiments(prob1; num_trajectories=2)
    println("   ✓ Generated $(length(experiments)) experiment(s)")
    
    # Get equations
    eqs = BaseProblemModule.get_equation_strings(prob1)
    println("   ✓ Equations:")
    for (i, eq) in enumerate(eqs)
        println("      $eq")
    end
    
    println("   ✅ Metabol1 PASSED")
catch e
    println("   ❌ Metabol1 FAILED: $e")
    rethrow(e)
end

# Test Metabol2
println("\n2. Testing Metabol2...")
try
    prob2 = Metabol2()
    println("   ✓ Metabol2() constructor works")
    println("   - Variant: $(prob2.variant)")
    println("   - Noise: $(prob2.default_noise)")
    println("   - N points: $(prob2.default_n_points)")
    
    experiments = BaseProblemModule.generate_experiments(prob2; num_trajectories=1)
    println("   ✓ Generated $(length(experiments)) experiment(s)")
    println("   ✅ Metabol2 PASSED")
catch e
    println("   ❌ Metabol2 FAILED: $e")
    rethrow(e)
end

# Test Metabol3
println("\n3. Testing Metabol3...")
try
    prob3 = Metabol3()
    println("   ✓ Metabol3() constructor works")
    println("   - Variant: $(prob3.variant)")
    println("   - Noise: $(prob3.default_noise)")
    println("   - N points: $(prob3.default_n_points)")
    
    experiments = BaseProblemModule.generate_experiments(prob3; num_trajectories=1)
    println("   ✓ Generated $(length(experiments)) experiment(s)")
    println("   ✅ Metabol3 PASSED")
catch e
    println("   ❌ Metabol3 FAILED: $e")
    rethrow(e)
end

# Test loading via unified interface
println("\n4. Testing load_problem_unified...")
try
    for name in ["metabol1", "metabol2", "metabol3"]
        experiments = load_problem_unified(name; num_trajectories=1)
        println("   ✓ Loaded $name: $(length(experiments)) experiment(s)")
    end
    println("   ✅ Unified loading PASSED")
catch e
    println("   ❌ Unified loading FAILED: $e")
    rethrow(e)
end

println("\n" * "="^60)
println("All Metabol tests PASSED! ✅")
println("="^60)
