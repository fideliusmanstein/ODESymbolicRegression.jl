"""
SimpleLinProblem.jl

Refactored simpleLin benchmark using unified BenchmarkProblem interface.
Represents equations as expression trees for better programmatic access.
"""

module SimpleLinProblemModule

using DifferentialEquations
using SymbolicRegression: Node
using ..BaseProblemModule
using ..TreeBuilderModule

export SimpleLinProblem, SimpleLin1, SimpleLin2

"""
    SimpleLinProblem

Simple linear metabolic pathway benchmark.

States: X3, X4, X5 (3 states)
Inputs: X1, X2 (2 inputs)

Equations:
    X3' = -k1·X3 + k2·X1·X4
    X4' = k1·X3 - k2·X1·X4 + k3·X5 - k4·X2·X4
    X5' = -k3·X5 + k4·X2·X4

Parameters: k1 = k2 = k3 = k4 = 1.0
Conservation law: X3 + X4 + X5 = 1.0
"""
struct SimpleLinProblem <: BenchmarkProblem
    name::String
    n_states::Int
    n_inputs::Int
    tree_equations::Vector{Node}
    parameter_values::Dict{Symbol, Float64}
    default_ic::Vector{Float64}
    default_tspan::Tuple{Float64, Float64}
    default_n_points::Int
    default_noise::Float64
    experiment_configs::Vector{NamedTuple}
    
    function SimpleLinProblem(; noise_std=0.0)
        # Parameters
        params = Dict(
            :k1 => 1.0,
            :k2 => 1.0,
            :k3 => 1.0,
            :k4 => 1.0
        )
        
        # Build expression trees for the ODEs
        # Variable indices: X3=1, X4=2, X5=3 (state vars)
        # Inputs will be provided separately: X1=input 1, X2=input 2
        
        x3 = var(1)  # State 1 = X3
        x4 = var(2)  # State 2 = X4
        x5 = var(3)  # State 3 = X5
        
        # Note: Inputs X1 and X2 will be added as features 4 and 5
        x1_input = var(4)  # Input 1 = X1
        x2_input = var(5)  # Input 2 = X2
        
        k1, k2, k3, k4 = 1.0, 1.0, 1.0, 1.0
        
        # X3' = -k1·X3 + k2·X1·X4
        eq1 = -k1 * x3 + k2 * x1_input * x4
        
        # X4' = k1·X3 - k2·X1·X4 + k3·X5 - k4·X2·X4
        eq2 = k1 * x3 - k2 * x1_input * x4 + k3 * x5 - k4 * x2_input * x4
        
        # X5' = -k3·X5 + k4·X2·X4
        eq3 = -k3 * x5 + k4 * x2_input * x4
        
        trees = [eq1, eq2, eq3]
        
        # Experiment configurations (8 different input combinations)
        exp_configs = [
            (X1=3.0, X2=2.0),
            (X1=4.0, X2=5.0),
            (X1=1.0, X2=3.0),
            (X1=3.0, X2=1.0),
            (X1=0.5, X2=1.0),
            (X1=1.0, X2=0.5),
            (X1=0.5, X2=5.0),
            (X1=5.0, X2=0.5),
        ]
        
        new(
            noise_std == 0.0 ? "simpleLin1" : "simpleLin2",
            3,  # n_states
            2,  # n_inputs
            trees,
            params,
            [1.0, 0.0, 0.0],  # default IC: [X3_0, X4_0, X5_0]
            (0.0, 3.0),  # default tspan
            13,  # default n_points
            noise_std,
            exp_configs
        )
    end
end

# Convenience constructors
SimpleLin1() = SimpleLinProblem(noise_std=0.0)
SimpleLin2() = SimpleLinProblem(noise_std=0.1)

"""
    evaluate_system(problem::SimpleLinProblem, X, inputs, t)

Evaluate the ODE system at a given state.
"""
function evaluate_system(problem::SimpleLinProblem, X, inputs, t)
    X3, X4, X5 = X
    X1 = inputs[:X1](t)
    X2 = inputs[:X2](t)
    
    k1, k2, k3, k4 = 1.0, 1.0, 1.0, 1.0
    
    dX3 = -k1 * X3 + k2 * X1 * X4
    dX4 = k1 * X3 - k2 * X1 * X4 + k3 * X5 - k4 * X2 * X4
    dX5 = -k3 * X5 + k4 * X2 * X4
    
    return [dX3, dX4, dX5]
end

"""
    generate_varied_ic(problem::SimpleLinProblem, base_ic::Vector{Float64})

Generate a random initial condition respecting the conservation law.
"""
function generate_varied_ic(problem::SimpleLinProblem, base_ic::Vector{Float64})
    # Generate random IC satisfying X3 + X4 + X5 = 1.0
    return collect(BaseProblemModule.generate_random_ic_unit_sum(3))
end

"""
    generate_data(problem::SimpleLinProblem; kwargs...)

Generate a single trajectory.
"""
function BaseProblemModule.generate_data(
    problem::SimpleLinProblem;
    X0::Vector{Float64}=problem.default_ic,
    tspan::Tuple{Float64,Float64}=problem.default_tspan,
    n_points::Int=problem.default_n_points,
    noise_std::Float64=problem.default_noise,
    input_values::Dict{Symbol,Union{Float64,Function}}=Dict(:X1 => 3.0, :X2 => 2.0)
)
    # Create input functions
    inputs = Dict{Symbol,Function}()
    for (key, val) in input_values
        if val isa Function
            inputs[key] = val
        else
            inputs[key] = t -> val
        end
    end
    
    # Define ODE problem
    function ode_func!(dX, X, p, t)
        dX .= evaluate_system(problem, X, inputs, t)
    end
    
    prob = ODEProblem(ode_func!, X0, tspan)
    
    # Solve
    t_eval = range(tspan[1], tspan[2], length=n_points)
    sol = solve(prob, AutoTsit5(Rosenbrock23()), saveat=t_eval)
    
    t = sol.t
    X = hcat(sol.u...)'
    
    # Add noise
    BaseProblemModule.add_gaussian_noise!(X, noise_std)
    
    # Prepare input values at each time point
    input_vals = Dict(key => [inputs[key](ti) for ti in t] for key in keys(inputs))
    
    return t, X, input_vals
end

"""
    generate_experiments(problem::SimpleLinProblem; kwargs...)

Generate multiple experiments with multiple trajectories.
"""
function BaseProblemModule.generate_experiments(
    problem::SimpleLinProblem;
    num_trajectories::Int=1,
    noise_std::Union{Float64,Nothing}=nothing,
    n_points::Union{Int,Nothing}=nothing
)
    # Use problem defaults if not specified
    noise = noise_std === nothing ? problem.default_noise : noise_std
    npts = n_points === nothing ? problem.default_n_points : n_points
    
    experiments = []
    
    for (exp_idx, exp_config) in enumerate(problem.experiment_configs)
        # Generate num_trajectories for this experiment
        for traj_idx in 1:num_trajectories
            # First trajectory uses default IC, others are varied
            if traj_idx == 1
                X0 = problem.default_ic
            else
                X0 = generate_varied_ic(problem, problem.default_ic)
            end
            
            # Generate data
            input_vals = Dict(:X1 => exp_config.X1, :X2 => exp_config.X2)
            t, X, inputs = BaseProblemModule.generate_data(
                problem;
                X0=X0,
                tspan=problem.default_tspan,
                n_points=npts,
                noise_std=noise,
                input_values=input_vals
            )
            
            push!(experiments, Dict(
                :experiment => exp_idx,
                :trajectory => traj_idx,
                :t => t,
                :X => X,
                :inputs => inputs,
                :params => exp_config,
                :ic => (X3_0=X0[1], X4_0=X0[2], X5_0=X0[3])
            ))
        end
    end
    
    return experiments
end

"""
    get_equation_strings(problem::SimpleLinProblem; format::Symbol=:text)

Get equation strings in various formats.
"""
function BaseProblemModule.get_equation_strings(problem::SimpleLinProblem; format::Symbol=:text)
    if format == :text || format == :julia
        return [
            "X3' = -1.0·X3 + 1.0·X1·X4",
            "X4' = 1.0·X3 - 1.0·X1·X4 + 1.0·X5 - 1.0·X2·X4",
            "X5' = -1.0·X5 + 1.0·X2·X4"
        ]
    elseif format == :latex
        return [
            raw"\frac{dX_3}{dt} = -k_1 X_3 + k_2 X_1 X_4",
            raw"\frac{dX_4}{dt} = k_1 X_3 - k_2 X_1 X_4 + k_3 X_5 - k_4 X_2 X_4",
            raw"\frac{dX_5}{dt} = -k_3 X_5 + k_4 X_2 X_4"
        ]
    else
        error("Unknown format: $format. Use :text, :julia, or :latex")
    end
end

end # module
