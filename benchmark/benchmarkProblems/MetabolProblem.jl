"""
MetabolProblem.jl

Refactored metabol benchmark using unified BenchmarkProblem interface.
Metabolic pathway with Michaelis-Menten kinetics.
"""

module MetabolProblemModule

using DifferentialEquations
using SymbolicRegression
using ..BaseProblemModule

export MetabolProblem, Metabol1, Metabol2, Metabol3

"""
    MetabolProblem

Metabolic pathway benchmark with Michaelis-Menten kinetics.

States: X3, X4, X5, X6, X7 (5 states)
Inputs: X1, X2 (2 inputs)

Equations (via reaction rates v1-v6):
    X3' = -v1 - v2 + v3 + v4
    X4' = v1 - v3
    X5' = v2 - v4
    X6' = v5 - v6
    X7' = -v5 + v6

where v1-v6 are Michaelis-Menten terms with inhibition.

Conservation laws: X3+X4+X5=const, X6+X7=const
"""
struct MetabolProblem <: BenchmarkProblem
    name::String
    n_states::Int
    n_inputs::Int
    tree_equations::Vector
    parameter_values::Dict{Symbol, Float64}
    default_ic::Vector{Float64}
    default_tspan::Tuple{Float64, Float64}
    default_n_points::Int
    default_noise::Float64
    experiment_configs::Vector{NamedTuple}
    variant::Int
    input_functions::Dict{Symbol, Function}
    
    function MetabolProblem(; problem_name="metabol1")
        variant = parse(Int, replace(problem_name, r"metabol" => ""))
        
        # Variant-specific parameters
        if variant == 1
            noise_std = 0.0
            n_points = 7
        elseif variant == 2
            noise_std = 0.1
            n_points = 21
        else  # variant == 3
            noise_std = 0.2
            n_points = 21
        end
        
        # Parameters (from Arkin & Ross 1995)
        params = Dict(
            :Vmax1 => 5.0, :Vmax2 => 5.0, :Vmax3 => 1.0, :Vmax4 => 1.0,
            :Vmax5 => 10.0, :Vmax6 => 1.0,
            :KD1 => 5.0, :KD2 => 5.0, :KD3 => 5.0,
            :KD4 => 5.0, :KD5 => 5.0, :KD6 => 5.0,
            :KI1 => 1.0, :KI2 => 1.0, :KI3 => 1.0
        )
        
        # For tree representation, we express the full expanded equations
        # Note: These are complex - using placeholder strings for now
        # In practice, you'd build the full Michaelis-Menten expressions
        var_names = ["x1", "x2", "x3", "x4", "x5", "x6", "x7"]
        binary_ops = [+, -, *, /]
        unary_ops = Function[]
        
        # Simplified tree equations (actual MM kinetics are complex)
        # X3' = -v1 - v2 + v3 + v4 (we'll evaluate numerically)
        trees = Vector{Any}(undef, 5)
        
        # For metabol, the equations are too complex for simple parse_expression
        # We'll use Nothing placeholders and rely on numerical evaluation
        for i in 1:5
            trees[i] = nothing
        end
        
        # 12 experiments with different input combinations
        experiment_configs = [
            (X0=[10.0, 0.1, 0.1, 1.0, 1.0], X1=0.5, X2=0.5),
            (X0=[10.0, 0.1, 0.1, 1.0, 1.0], X1=0.5, X2=1.0),
            (X0=[10.0, 0.1, 0.1, 1.0, 1.0], X1=0.5, X2=2.0),
            (X0=[10.0, 0.1, 0.1, 1.0, 1.0], X1=1.0, X2=0.5),
            (X0=[10.0, 0.1, 0.1, 1.0, 1.0], X1=1.0, X2=1.0),
            (X0=[10.0, 0.1, 0.1, 1.0, 1.0], X1=1.0, X2=2.0),
            (X0=[10.0, 0.1, 0.1, 1.0, 1.0], X1=2.0, X2=0.5),
            (X0=[10.0, 0.1, 0.1, 1.0, 1.0], X1=2.0, X2=1.0),
            (X0=[10.0, 0.1, 0.1, 1.0, 1.0], X1=2.0, X2=2.0),
            (X0=[10.0, 0.1, 0.1, 1.0, 1.0], X1=0.1, X2=0.1),
            (X0=[10.0, 0.1, 0.1, 1.0, 1.0], X1=5.0, X2=5.0),
            (X0=[10.0, 0.1, 0.1, 1.0, 1.0], X1=10.0, X2=10.0)
        ]
        
        # Input functions (constant inputs)
        input_funcs = Dict(
            :X1 => (t -> 1.0),  # Will be overridden by experiment configs
            :X2 => (t -> 1.0)
        )
        
        new(
            problem_name,
            5,  # n_states
            2,  # n_inputs
            trees,
            params,
            [10.0, 0.1, 0.1, 1.0, 1.0],  # default_ic [X3_0, X4_0, X5_0, X6_0, X7_0]
            (0.0, 150.0),  # default_tspan
            n_points,
            noise_std,
            experiment_configs,
            variant,
            input_funcs
        )
    end
end

# Evaluate the Michaelis-Menten system
function evaluate_system(problem::MetabolProblem, X, inputs, t)
    X3, X4, X5, X6, X7 = X
    
    # Get input values
    X1 = inputs[:X1](t)
    X2 = inputs[:X2](t)
    
    # Parameters
    p = problem.parameter_values
    Vmax1, Vmax2, Vmax3, Vmax4, Vmax5, Vmax6 = p[:Vmax1], p[:Vmax2], p[:Vmax3], p[:Vmax4], p[:Vmax5], p[:Vmax6]
    KD1, KD2, KD3, KD4, KD5, KD6 = p[:KD1], p[:KD2], p[:KD3], p[:KD4], p[:KD5], p[:KD6]
    KI1, KI2, KI3 = p[:KI1], p[:KI2], p[:KI3]
    
    # Michaelis-Menten reaction rates with inhibition
    v1 = X3 * Vmax1 / ((X3 + KD1) * (1 + X1 / KI1))
    v2 = X3 * Vmax2 / ((X3 + KD2) * (1 + X2 / KI2))
    v3 = X4 * Vmax3 / (X4 + KD3)
    v4 = X5 * Vmax4 / (X5 + KD4)
    v5 = X7 * Vmax5 / ((X7 + KD5) * (1 + X3 / KI3))
    v6 = X6 * Vmax6 / (X6 + KD6)
    
    # System equations
    dX3 = -v1 - v2 + v3 + v4
    dX4 = v1 - v3
    dX5 = v2 - v4
    dX6 = v5 - v6
    dX7 = -v5 + v6
    
    return [dX3, dX4, dX5, dX6, dX7]
end

function generate_varied_ic(problem::MetabolProblem, base_ic::Vector{Float64})
    return base_ic .* (1.0 .+ 0.1 .* randn(problem.n_states))
end

function BaseProblemModule.generate_data(
    problem::MetabolProblem;
    X0::Vector{Float64}=problem.default_ic,
    tspan::Tuple{Float64,Float64}=problem.default_tspan,
    n_points::Int=problem.default_n_points,
    noise_std::Float64=problem.default_noise,
    input_values::Dict=problem.input_functions
)
    # Create input functions (handle both constant and function inputs)
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
    X = collect(hcat(sol.u...)')  # Convert Adjoint to Matrix
    
    # Add noise
    BaseProblemModule.add_gaussian_noise!(X, noise_std)
    
    # Prepare input values at each time point
    input_vals = Dict(key => [inputs[key](ti) for ti in t] for key in keys(inputs))
    
    return t, X, input_vals
end

function BaseProblemModule.generate_experiments(
    problem::MetabolProblem;
    num_trajectories::Int=1,
    noise_std::Union{Float64,Nothing}=nothing,
    n_points::Union{Int,Nothing}=nothing
)
    noise = noise_std === nothing ? problem.default_noise : noise_std
    npts = n_points === nothing ? problem.default_n_points : n_points
    
    experiments = config IC for first trajectory, vary for others
            X0 = traj_idx == 1 ? exp_config.X0 : generate_varied_ic(problem, exp_config.X0)
            
            # Generate data with constant input values
            input_vals = Dict{Symbol,Function}(
                :X1 => (t -> exp_config.X1),
                :X2 => (t -> exp_config.X2)
            m.default_ic)))
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
                :ic => (X3_0=X0[1], X4_0=X0[2], X5_0=X0[3], X6_0=X0[4], X7_0=X0[5])
            ))
        end
    end
    
    return experiments
end

function BaseProblemModule.get_equation_strings(problem::MetabolProblem)
    return [
        "X3' = -v1 - v2 + v3 + v4  (Michaelis-Menten kinetics)",
        "X4' = v1 - v3",
        "X5' = v2 - v4",
        "X6' = v5 - v6",
        "X7' = -v5 + v6"
    ]
end

# Problem variants
Metabol1() = MetabolProblem(problem_name="metabol1")
Metabol2() = MetabolProblem(problem_name="metabol2")
Metabol3() = MetabolProblem(problem_name="metabol3")

end # module
