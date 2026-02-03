"""
generate_unified_problems.jl

Automated generator for creating unified problem files from legacy implementations.
This script reads the legacy problem definitions and creates unified architecture versions.
"""

using Pkg
Pkg.activate(".")

include("benchmark/benchmarkProblems/BenchmarkSystems.jl")
using .BenchmarkSystems

"""
Generate a unified problem file from a legacy problem name.
"""
function generate_unified_problem_file(legacy_name::String, output_dir::String)
    # Load a sample from the legacy system to extract metadata
    try
        experiments = BenchmarkSystems.load_problem(legacy_name, num_trajectories=1)
        
        if isempty(experiments)
            println("  ⚠ No experiments found for $legacy_name")
            return false
        end
        
        exp = experiments[1]
        n_states = size(exp[:X], 2)
        n_inputs = length(exp[:inputs])
        n_experiments = length(unique([e[:experiment] for e in experiments]))
        
        # Determine problem family and create appropriate structure
        problem_family, base_name, variant = parse_problem_name(legacy_name)
        
        println("  ✓ $legacy_name: $n_states states, $n_inputs inputs, $n_experiments experiments")
        
        # For now, just create a stub file
        # In a production version, we'd extract the actual equations
        create_stub_problem_file(legacy_name, problem_family, base_name, variant, 
                                 n_states, n_inputs, n_experiments, output_dir)
        
        return true
        
    catch e
        println("  ✗ Error processing $legacy_name: $e")
        return false
    end
end

function parse_problem_name(name::String)
    # Parse names like "metabol1", "ss_feedf2", "gma_inhosc1"
    if startswith(name, "ss_")
        parts = split(name, "_")
        base = join(parts[2:end-1], "_")
        variant = name[end:end]
        return ("S-System", base, variant)
    elseif startswith(name, "gma_")
        parts = split(name[5:end], r"\d")
        base = parts[1]
        variant = name[end:end]
        return ("GMA", base, variant)
    else
        # Chemical rate or biological
        match_result = match(r"([a-zA-Z]+)(\d+)", name)
        if match_result !== nothing
            return ("ChemicalRate", match_result.captures[1], match_result.captures[2])
        end
    end
    return ("Unknown", name, "1")
end

function create_stub_problem_file(legacy_name, family, base_name, variant, 
                                   n_states, n_inputs, n_experiments, output_dir)
    # This creates a basic stub - in production, extract actual equations
    capitalized_name = uppercasefirst(base_name)
    module_name = "$(capitalized_name)ProblemModule"
    
    content = """
\"\"\"
$(capitalized_name)Problem.jl (AUTO-GENERATED STUB)

Unified architecture implementation for $legacy_name benchmark.
Family: $family
States: $n_states, Inputs: $n_inputs, Experiments: $n_experiments

TODO: Implement full equation extraction from legacy system.
\"\"\"

module $module_name

using DifferentialEquations
using SymbolicRegression
using ...BaseProblemModule

export $(capitalized_name)Problem

struct $(capitalized_name)Problem <: BenchmarkProblem
    # TODO: Add struct fields
    name::String
    n_states::Int
    n_inputs::Int
end

function $(capitalized_name)Problem(; variant="$variant")
    # TODO: Implement constructor
    $(capitalized_name)Problem("$base_name", $n_states, $n_inputs)
end

# TODO: Implement evaluate_system, generate_data, generate_experiments

end # module
"""
    
    filename = joinpath(output_dir, "$(capitalized_name)Problem.jl")
    open(filename, "w") do f
        write(f, content)
    end
    
    println("    Created stub: $filename")
end

# Main execution
println("="^80)
println("Automated Unified Problem Generator")
println("="^80)
println()

output_dir = "benchmark/benchmarkProblems/unified_stubs"
mkpath(output_dir)

# Get all legacy problems
all_problems = sort(collect(keys(BenchmarkSystems.list_problems())))

# Filter out already-implemented problems
already_done = ["simpleLin1", "simpleLin2", "simpleFb1", "simpleFb2", 
                "simpleFb3", "simpleFb4", "osc1", "osc2"]

remaining = filter(p -> !(p in already_done), all_problems)

println("Processing $(length(remaining)) remaining problems...")
println()

global success_count = 0
for problem_name in remaining
    global success_count
    if generate_unified_problem_file(problem_name, output_dir)
        success_count += 1
    end
end

println()
println("="^80)
println("Summary:")
println("  Total processed: $(length(remaining))")
println("  Successfully created: $success_count")
println("  Output directory: $output_dir")
println("="^80)
println()
println("Next steps:")
println("1. Review generated stub files")
println("2. Implement full equation extraction for each family")
println("3. Update UnifiedBenchmarkSystems.jl to include new problems")
println("4. Test each problem batch")
