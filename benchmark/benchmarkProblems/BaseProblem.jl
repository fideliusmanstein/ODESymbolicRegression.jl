"""
BaseProblem.jl

Abstract base class for all benchmark ODE problems. 
Provides a unified interface for data generation, tree representation, and display.
"""

module BaseProblemModule

using DifferentialEquations
using SymbolicRegression: Node

export BenchmarkProblem, generate_data, generate_experiments, get_tree_equations, 
       get_equation_strings, problem_info

"""
    BenchmarkProblem

Abstract base type for all benchmark ODE problems.

All benchmark problems should define:
- `name::String`: Problem identifier
- `n_states::Int`: Number of state variables
- `n_inputs::Int`: Number of input variables
- `tree_equations::Vector`: Expression trees for each ODE (dx/dt = tree_equations[x])
- `parameter_values::Dict`: Parameter values used in the system
- `default_ic::Vector{Float64}`: Default initial conditions
- `default_tspan::Tuple{Float64,Float64}`: Default time span
- `default_n_points::Int`: Default number of time points
-  default_noise::Float64`: Default noise level

Methods that must be implemented:
- `evaluate_system(problem, X, inputs, t)`: Evaluate ODE system at a point
- `generate_varied_ic(problem, base_ic)`: Generate varied initial conditions
"""
abstract type BenchmarkProblem end

"""
    generate_data(problem::BenchmarkProblem; kwargs...)

Generate time series data for a single trajectory.

# Arguments
- `problem`: BenchmarkProblem instance
- `X0`: Initial conditions (default: problem.default_ic)
- `tspan`: Time span (default: problem.default_tspan)
- `n_points`: Number of time points (default: problem.default_n_points)
- `noise_std`: Noise standard deviation (default: problem.default_noise)
- `input_values`: Dict of input values/functions (default: problem default)

# Returns
- `t`: Time vector
- `X`: State matrix (n_points × n_states)
- `inputs`: Dictionary with input values at each time point
"""
function generate_data end

"""
    generate_experiments(problem::BenchmarkProblem; kwargs...)

Generate multiple experiments for a benchmark problem.

# Arguments
- `problem`: BenchmarkProblem instance
- `num_trajectories`: Number of trajectories per experiment (default: 1)
- `noise_std`: Noise standard deviation (default: problem.default_noise)
- `n_points`: Number of time points (default: problem.default_n_points)
- `experiment_configs`: Vector of experiment-specific configurations (optional)

# Returns
Vector of experiment dictionaries with keys:
- `:experiment`: Experiment index
- `:trajectory`: Trajectory index within experiment
- `:t`: Time vector
- `:X`: State matrix
- `:inputs`: Input values
- `:params`: Experiment parameters
- `:ic`: Initial conditions
"""
function generate_experiments end

"""
    get_tree_equations(problem::BenchmarkProblem)

Get the expression trees representing the ODE system.

# Returns
Vector of expression trees (one per state variable)
"""
function get_tree_equations(problem::BenchmarkProblem)
    return problem.tree_equations
end

"""
    get_equation_strings(problem::BenchmarkProblem; format::Symbol=:latex)

Get string representations of the equations.

# Arguments
- `problem`: BenchmarkProblem instance
- `format`: Output format (:latex, :text, or :julia)

# Returns
Vector of equation strings
"""
function get_equation_strings end

"""
    problem_info(problem::BenchmarkProblem)

Display comprehensive information about a problem.

# Returns
Dictionary with problem metadata
"""
function problem_info(problem::BenchmarkProblem)
    return Dict(
        :name => problem.name,
        :n_states => problem.n_states,
        :n_inputs => problem.n_inputs,
        :n_parameters => length(problem.parameter_values),
        :default_ic => problem.default_ic,
        :default_tspan => problem.default_tspan,
        :default_n_points => problem.default_n_points,
        :default_noise => problem.default_noise
    )
end

"""
    Helper function to generate random initial conditions respecting constraints.
"""
function generate_random_ic_unit_sum(n::Int; epsilon=0.01)
    """
    Generate random initial conditions that sum to 1.0
    Uses Dirichlet-like sampling on simplex.
    Adds small epsilon to avoid zeros.
    """
    # Generate n random exponential variables
    raw = -log.(rand(n))
    # Normalize to sum to 1
    normalized = raw ./ sum(raw)
    # Add small epsilon and re-normalize to avoid exact zeros
    with_epsilon = normalized .+ epsilon
    return with_epsilon ./ sum(with_epsilon)
end

"""
    Helper function to add noise to data.
"""
function add_gaussian_noise!(X::Matrix{Float64}, noise_std::Float64)
    """
    Add Gaussian noise proportional to value magnitude.
    noise = noise_std * abs(value) * randn()
    """
    if noise_std > 0.0
        for i in 1:size(X, 1)
            for j in 1:size(X, 2)
                noise = noise_std * abs(X[i, j]) * randn()
                X[i, j] += noise
            end
        end
    end
end

end # module
