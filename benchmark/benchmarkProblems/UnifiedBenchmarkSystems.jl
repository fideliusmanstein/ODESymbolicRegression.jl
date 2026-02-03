"""
UnifiedBenchmarkSystems.jl

Unified interface supporting both old and new benchmark problem architectures.
Provides backward compatibility while enabling new features.
"""

module UnifiedBenchmarkSystems

# Include base architecture
include("BaseProblem.jl")
include("TreeBuilder.jl")

# Include new problem implementations
include("SimpleLinProblem.jl")
include("SimpleFbProblem.jl")
include("OscProblem.jl")
include("BifeedbProblem.jl")
include("FeedfProblem.jl")
include("InhoscProblem.jl")
include("MetabolProblem.jl")

# Re-export for convenience
using .BaseProblemModule
using .SimpleLinProblemModule: SimpleLin1, SimpleLin2
using .SimpleFbProblemModule: SimpleFb1, SimpleFb2, SimpleFb3, SimpleFb4
using .OscProblemModule: Osc1, Osc2
using .BifeedbProblemModule: Bifeedb1, Bifeedb2
using .FeedfProblemModule: Feedf1, Feedf2, FeedfProblem
using .InhoscProblemModule: Inhosc1, Inhosc2, InhoscProblem
using .MetabolProblemModule: Metabol1, Metabol2, Metabol3, MetabolProblem

export load_problem_unified, list_problems_unified, get_problem_trees
export SimpleLin1, SimpleLin2, SimpleFb1, SimpleFb2, SimpleFb3, SimpleFb4
export Osc1, Osc2
export Bifeedb1, Bifeedb2
export Feedf1, Feedf2
export Inhosc1, Inhosc2
export Metabol1, Metabol2, Metabol3
export BifeedbProblem, FeedfProblem, InhoscProblem, MetabolProblem

"""
    load_problem_unified(problem_name::String; num_trajectories::Int=1, kwargs...)

Load a benchmark problem using the unified architecture.

Returns a problem instance that can be used to generate data.

# Arguments
- `problem_name`: Name of the problem (e.g., "simpleLin1", "simpleFb1", "osc1")
- `num_trajectories`: Number of trajectories per experiment (default: 1)
- Additional kwargs passed to generate_experiments()

# Returns
- experiments: Vector of experiment dictionaries

# Example
```julia
experiments = load_problem_unified("simpleLin1", num_trajectories=3)
```
"""
function load_problem_unified(problem_name::String; num_trajectories::Int=1, kwargs...)
    # Map problem names to constructors
    problem = if problem_name == "simpleLin1"
        SimpleLin1()
    elseif problem_name == "simpleLin2"
        SimpleLin2()
    elseif problem_name == "simpleFb1"
        SimpleFb1()
    elseif problem_name == "simpleFb2"
        SimpleFb2()
    elseif problem_name == "simpleFb3"
        SimpleFb3()
    elseif problem_name == "simpleFb4"
        SimpleFb4()
    elseif problem_name == "osc1"
        Osc1()
    elseif problem_name == "osc2"
        Osc2()
    elseif problem_name == "bifeedb1" || problem_name == "gma_bifeedb1" || problem_name == "ss_bifeedb1"
        Bifeedb1()
    elseif problem_name == "bifeedb2" || problem_name == "gma_bifeedb2" || problem_name == "ss_bifeedb2"
        Bifeedb2()
    elseif problem_name == "feedf1" || problem_name == "gma_feedf1" || problem_name == "ss_feedf1"
        Feedf1()
    elseif problem_name == "feedf2" || problem_name == "gma_feedf2" || problem_name == "ss_feedf2"
        Feedf2()
    elseif problem_name == "inhosc1" || problem_name == "gma_inhosc1" || problem_name == "ss_inhosc1"
        Inhosc1()
    elseif problem_name == "inhosc2" || problem_name == "gma_inhosc2" || problem_name == "ss_inhosc2"
        Inhosc2()
    elseif problem_name == "metabol1"
        Metabol1()
    elseif problem_name == "metabol2"
        Metabol2()
    elseif problem_name == "metabol3"
        Metabol3()
    else
        error("Unknown problem: $problem_name. Check list_problems_unified() for available problems.")
    end
    
    # Generate experiments using the unified API
    return BaseProblemModule.generate_experiments(problem; num_trajectories=num_trajectories, kwargs...)
end

"""
    list_problems_unified()

List all available problems in the unified architecture.

Returns a dictionary with problem metadata.
"""
function list_problems_unified()
    problems = Dict(
        "simpleLin1" => Dict(
            :states => 3,
            :inputs => 2,
            :variants => 1,
            :status => "✅ Implemented"
        ),
        "simpleLin2" => Dict(
            :states => 3,
            :inputs => 2,
            :variants => 1,
            :status => "✅ Implemented"
        ),
        "simpleFb1" => Dict(
            :states => 3,
            :inputs => 0,
            :variants => 1,
            :status => "✅ Implemented"
        ),
        "simpleFb2" => Dict(
            :states => 3,
            :inputs => 0,
            :variants => 1,
            :status => "✅ Implemented"
        ),
        "simpleFb3" => Dict(
            :states => 3,
            :inputs => 0,
            :variants => 1,
            :status => "✅ Implemented"
        ),
        "simpleFb4" => Dict(
            :states => 3,
            :inputs => 0,
            :variants => 1,
            :status => "✅ Implemented"
        ),
        "osc1" => Dict(
            :states => 3,
            :inputs => 0,
            :variants => 1,
            :status => "✅ Implemented"
        ),
        "osc2" => Dict(
            :states => 3,
            :inputs => 0,
            :variants => 1,
            :status => "✅ Implemented"
        ),
        "bifeedb1" => Dict(
            :states => 4,
            :inputs => 0,
            :variants => 1,
            :status => "✅ Implemented"
        ),
        "bifeedb2" => Dict(
            :states => 5,
            :inputs => 0,
            :variants => 1,
            :status => "✅ Implemented"
        ),
        "feedf1" => Dict(
            :states => 4,
            :inputs => 2,
            :variants => 1,
            :status => "✅ Implemented"
        ),
        "feedf2" => Dict(
            :states => 4,
            :inputs => 2,
            :variants => 1,
            :status => "✅ Implemented"
        ),
        "inhosc1" => Dict(
            :states => 2,
            :inputs => 2,
            :variants => 1,
            :status => "✅ Implemented"
        ),
        "inhosc2" => Dict(
            :states => 4,
            :inputs => 2,
            :variants => 1,
            :status => "✅ Implemented"
        ),
    )
    
    return problems
end

"""
    get_problem_trees(problem_name::String)

Get the expression trees for a problem.

# Example
```julia
trees = get_problem_trees("simpleLin1")
```
"""
function get_problem_trees(problem_name::String)
    problem = if problem_name == "simpleLin1"
        SimpleLin1()
    elseif problem_name == "simpleLin2"
        SimpleLin2()
    elseif problem_name == "simpleFb1"
        SimpleFb1()
    elseif problem_name == "simpleFb2"
        SimpleFb2()
    elseif problem_name == "simpleFb3"
        SimpleFb3()
    elseif problem_name == "simpleFb4"
        SimpleFb4()
    elseif problem_name == "osc1"
        Osc1()
    elseif problem_name == "osc2"
        Osc2()
    else
        error("Unknown problem: $problem_name")
    end
    
    return BaseProblemModule.get_tree_equations(problem)
end

end # module
