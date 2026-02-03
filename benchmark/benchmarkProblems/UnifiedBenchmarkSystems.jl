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

# Re-export for convenience
using .BaseProblemModule
using .SimpleLinProblemModule
using .SimpleFbProblemModule
using .OscProblemModule

export load_problem_unified, list_problems_unified, get_problem_trees
export SimpleLin1, SimpleLin2, SimpleFb1, SimpleFb2, SimpleFb3, SimpleFb4
export Osc1, Osc2

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
    else
        error("Unknown problem: $problem_name. Implemented: simpleLin1/2, simpleFb1-4, osc1/2")
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
