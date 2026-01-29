"""
test_benchmarks.jl

Test file for all benchmark differential equation systems.
Verifies that all systems can be loaded and generate expected results.
"""

include("BenchmarkSystems.jl")
using .BenchmarkSystems

println("="^80)
println("BENCHMARK SYSTEMS TEST SUITE")
println("="^80)

# Test counter
tests_passed = 0
tests_failed = 0

function test_problem(problem_name::String)
    println("\n" * "-"^80)
    println("Testing: $problem_name")
    println("-"^80)
    
    try
        # Get problem info
        info = BenchmarkSystems.problem_info(problem_name)
        
        # Load problem
        experiments = BenchmarkSystems.load_problem(problem_name)
        
        # Verify structure
        n_exp = length(experiments)
        println("  ✓ Loaded $n_exp experiments")
        
        if n_exp != info[:experiments]
            println("  ⚠ WARNING: Expected $(info[:experiments]) experiments, got $n_exp")
        end
        
        # Check first experiment
        exp1 = experiments[1]
        t = exp1[:t]
        X = exp1[:X]
        
        println("  ✓ Time points: $(length(t))")
        println("  ✓ State matrix shape: $(size(X))")
        println("  ✓ Number of states: $(size(X, 2))")
        
        # Verify expected dimensions
        if size(X, 1) != length(t)
            error("Mismatch: X has $(size(X, 1)) rows but t has $(length(t)) points")
        end
        
        if size(X, 2) != info[:states]
            error("Mismatch: X has $(size(X, 2)) states but expected $(info[:states])")
        end
        
        # Check for NaN or Inf
        if any(isnan, X) || any(isinf, X)
            error("Found NaN or Inf values in state matrix")
        end
        
        # Check initial conditions if available
        if haskey(exp1, :X0)
            X0 = exp1[:X0]
            println("  ✓ Initial conditions: $X0")
        end
        
        # Check inputs if available
        if haskey(exp1, :inputs)
            inputs = exp1[:inputs]
            println("  ✓ Inputs available: $(keys(inputs))")
        end
        
        # Display sample data
        println("\n  Sample data (first 3 time points):")
        println("  t = $(t[1:min(3, length(t))])")
        for i in 1:size(X, 2)
            println("  X$i = $(X[1:min(3, size(X, 1)), i])")
        end
        
        # Check conservation laws where applicable
        if problem_name in ["simpleLin1", "simpleLin2"]
            # X3 + X4 + X5 should be approximately constant
            total = sum(X, dims=2)
            conservation_error = maximum(abs.(total .- total[1]))
            println("\n  Conservation law check (X3+X4+X5):")
            println("    Max deviation: $conservation_error")
            if conservation_error > 1e-6
                println("    ⚠ WARNING: Conservation law violated (error > 1e-6)")
            else
                println("    ✓ Conservation law satisfied")
            end
        end
        
        if problem_name in ["metabol1", "metabol2", "metabol3"]
            # X3 + X4 + X5 should be approximately constant
            total1 = X[:, 1] + X[:, 2] + X[:, 3]
            conservation_error1 = maximum(abs.(total1 .- total1[1]))
            
            # X6 + X7 should be approximately constant
            total2 = X[:, 4] + X[:, 5]
            conservation_error2 = maximum(abs.(total2 .- total2[1]))
            
            println("\n  Conservation law checks:")
            println("    X3+X4+X5 max deviation: $conservation_error1")
            println("    X6+X7 max deviation: $conservation_error2")
            
            if conservation_error1 > 1e-4 || conservation_error2 > 1e-4
                println("    ⚠ WARNING: Conservation laws may be violated")
            else
                println("    ✓ Conservation laws satisfied")
            end
        end
        
        println("\n  ✅ PASSED: $problem_name")
        global tests_passed += 1
        return true
        
    catch e
        println("\n  ❌ FAILED: $problem_name")
        println("  Error: $e")
        global tests_failed += 1
        return false
    end
end

# Test all available problems
println("\n\nListing all available problems:")
println("="^80)
problems = BenchmarkSystems.list_problems()
problem_names = sort(collect(keys(problems)))
println("Found $(length(problem_names)) problems: $(join(problem_names, ", "))")

# Run tests
println("\n\nRunning tests...")
println("="^80)

for problem_name in problem_names
    test_problem(problem_name)
end

# Test individual modules
println("\n\n" * "="^80)
println("TESTING INDIVIDUAL MODULES")
println("="^80)

println("\n" * "-"^80)
println("Testing SimpleLinModule direct access")
println("-"^80)
try
    t, X, inputs = BenchmarkSystems.SimpleLinModule.generate_simplelin_data(
        X1_const=3.0,
        X2_const=2.0,
        noise_std=0.0
    )
    println("  ✓ Generated data: $(length(t)) time points, $(size(X, 2)) states")
    println("  ✓ Inputs: X1=$(inputs[:X1][1]), X2=$(inputs[:X2][1])")
    println("  ✅ PASSED: Direct SimpleLinModule access")
    global tests_passed += 1
catch e
    println("  ❌ FAILED: Direct SimpleLinModule access")
    println("  Error: $e")
    global tests_failed += 1
end

println("\n" * "-"^80)
println("Testing SimpleFbModule direct access")
println("-"^80)
try
    t, X = BenchmarkSystems.SimpleFbModule.generate_simplefb_data(
        X0=[1.0, 0.0, 0.0],
        noise_std=0.0
    )
    println("  ✓ Generated data: $(length(t)) time points, $(size(X, 2)) states")
    println("  ✅ PASSED: Direct SimpleFbModule access")
    global tests_passed += 1
catch e
    println("  ❌ FAILED: Direct SimpleFbModule access")
    println("  Error: $e")
    global tests_failed += 1
end

println("\n" * "-"^80)
println("Testing OscModule direct access")
println("-"^80)
try
    t, X = BenchmarkSystems.OscModule.generate_osc_data(
        X0=[1.0, 0.0, 0.0],
        noise_std=0.0
    )
    println("  ✓ Generated data: $(length(t)) time points, $(size(X, 2)) states")
    println("  ✅ PASSED: Direct OscModule access")
    global tests_passed += 1
catch e
    println("  ❌ FAILED: Direct OscModule access")
    println("  Error: $e")
    global tests_failed += 1
end

println("\n" * "-"^80)
println("Testing MetabolModule direct access")
println("-"^80)
try
    t, X, inputs = BenchmarkSystems.MetabolModule.generate_metabol_data(
        X1_const=1.0,
        X2_const=1.0,
        noise_std=0.0
    )
    println("  ✓ Generated data: $(length(t)) time points, $(size(X, 2)) states")
    println("  ✓ Inputs: X1=$(inputs[:X1][1]), X2=$(inputs[:X2][1])")
    println("  ✅ PASSED: Direct MetabolModule access")
    global tests_passed += 1
catch e
    println("  ❌ FAILED: Direct MetabolModule access")
    println("  Error: $e")
    global tests_failed += 1
end

println("\n" * "-"^80)
println("Testing ThreeGenesModule direct access")
println("-"^80)
try
    t, X = BenchmarkSystems.ThreeGenesModule.generate_threegenes_data(
        X0=[1.0, 1.0, 1.0, 0.1, 0.1, 0.1, 0.5, 0.5],
        noise_std=0.0
    )
    println("  ✓ Generated data: $(length(t)) time points, $(size(X, 2)) states")
    println("  ✅ PASSED: Direct ThreeGenesModule access")
    global tests_passed += 1
catch e
    println("  ❌ FAILED: Direct ThreeGenesModule access")
    println("  Error: $e")
    global tests_failed += 1
end

println("\n" * "-"^80)
println("Testing FeedfModule direct access")
println("-"^80)
try
    t, X, inputs = BenchmarkSystems.FeedfModule.generate_feedf_data(
        In1_const=1.0,
        In2_const=1.0,
        noise_std=0.0
    )
    println("  ✓ Generated data: $(length(t)) time points, $(size(X, 2)) states")
    println("  ✓ Inputs: In1=$(inputs[:In1][1]), In2=$(inputs[:In2][1])")
    println("  ✅ PASSED: Direct FeedfModule access")
    global tests_passed += 1
catch e
    println("  ❌ FAILED: Direct FeedfModule access")
    println("  Error: $e")
    global tests_failed += 1
end

println("\n" * "-"^80)
println("Testing InhoscModule direct access (2-state)")
println("-"^80)
try
    t, X, inputs = BenchmarkSystems.InhoscModule.generate_inhosc_data(
        In_const=1.0,
        Out_const=1.0,
        n_states=2,
        noise_std=0.0
    )
    println("  ✓ Generated data: $(length(t)) time points, $(size(X, 2)) states")
    println("  ✓ Inputs: In=$(inputs[:In][1]), Out=$(inputs[:Out][1])")
    println("  ✅ PASSED: Direct InhoscModule access (2-state)")
    global tests_passed += 1
catch e
    println("  ❌ FAILED: Direct InhoscModule access (2-state)")
    println("  Error: $e")
    global tests_failed += 1
end

println("\n" * "-"^80)
println("Testing InhoscModule direct access (4-state)")
println("-"^80)
try
    t, X, inputs = BenchmarkSystems.InhoscModule.generate_inhosc_data(
        In_const=1.0,
        Out_const=1.0,
        n_states=4,
        noise_std=0.0
    )
    println("  ✓ Generated data: $(length(t)) time points, $(size(X, 2)) states")
    println("  ✓ Inputs: In=$(inputs[:In][1]), Out=$(inputs[:Out][1])")
    println("  ✅ PASSED: Direct InhoscModule access (4-state)")
    global tests_passed += 1
catch e
    println("  ❌ FAILED: Direct InhoscModule access (4-state)")
    println("  Error: $e")
    global tests_failed += 1
end

println("\n" * "-"^80)
println("Testing BifeedbModule direct access (4-state)")
println("-"^80)
try
    t, X, _ = BenchmarkSystems.BifeedbModule.generate_bifeedb_data(
        X0=[1.0, 1.0, 1.0, 1.0],
        n_states=4,
        noise_std=0.0
    )
    println("  ✓ Generated data: $(length(t)) time points, $(size(X, 2)) states")
    println("  ✅ PASSED: Direct BifeedbModule access (4-state)")
    global tests_passed += 1
catch e
    println("  ❌ FAILED: Direct BifeedbModule access (4-state)")
    println("  Error: $e")
    global tests_failed += 1
end

println("\n" * "-"^80)
println("Testing BifeedbModule direct access (5-state)")
println("-"^80)
try
    t, X, _ = BenchmarkSystems.BifeedbModule.generate_bifeedb_data(
        X0=[1.0, 1.0, 1.0, 1.0, 1.0],
        n_states=5,
        noise_std=0.0
    )
    println("  ✓ Generated data: $(length(t)) time points, $(size(X, 2)) states")
    println("  ✅ PASSED: Direct BifeedbModule access (5-state)")
    global tests_passed += 1
catch e
    println("  ❌ FAILED: Direct BifeedbModule access (5-state)")
    println("  Error: $e")
    global tests_failed += 1
end

# Test with custom parameters
println("\n\n" * "="^80)
println("TESTING CUSTOM PARAMETERS")
println("="^80)

println("\n" * "-"^80)
println("Testing simpleLin with different noise levels")
println("-"^80)
try
    for noise in [0.0, 0.05, 0.1, 0.2]
        t, X, inputs = BenchmarkSystems.SimpleLinModule.generate_simplelin_data(
            X1_const=3.0,
            X2_const=2.0,
            noise_std=noise
        )
        println("  ✓ Noise level $noise: $(size(X)) data generated")
    end
    println("  ✅ PASSED: Noise level variation")
    global tests_passed += 1
catch e
    println("  ❌ FAILED: Noise level variation")
    println("  Error: $e")
    global tests_failed += 1
end

println("\n" * "-"^80)
println("Testing time-varying inputs")
println("-"^80)
try
    t, X, inputs = BenchmarkSystems.SimpleLinModule.generate_simplelin_data(
        X1_func = t -> 3.0 + sin(t),
        X2_func = t -> 2.0 + cos(t),
        noise_std=0.0
    )
    println("  ✓ Generated data with time-varying inputs")
    println("  ✓ X1 range: [$(minimum(inputs[:X1])), $(maximum(inputs[:X1]))]")
    println("  ✓ X2 range: [$(minimum(inputs[:X2])), $(maximum(inputs[:X2]))]")
    println("  ✅ PASSED: Time-varying inputs")
    global tests_passed += 1
catch e
    println("  ❌ FAILED: Time-varying inputs")
    println("  Error: $e")
    global tests_failed += 1
end

# Summary
println("\n\n" * "="^80)
println("TEST SUMMARY")
println("="^80)
println("Total tests: $(tests_passed + tests_failed)")
println("Passed: $tests_passed ✅")
println("Failed: $tests_failed ❌")

if tests_failed == 0
    println("\n🎉 ALL TESTS PASSED! 🎉")
else
    println("\n⚠️  SOME TESTS FAILED")
end
println("="^80)
