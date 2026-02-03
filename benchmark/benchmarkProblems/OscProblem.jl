"""
OscProblem.jl

Oscillator benchmark using unified BenchmarkProblem interface.
"""

module OscProblemModule

using DifferentialEquations
using SymbolicRegression
using ..BaseProblemModule

export OscProblem, Osc1, Osc2

"""
    OscProblem

Oscillator benchmark system.

States: X1, X2, X3 (3 states)
Inputs: none

Equations:
    X1' = k1·X2
    X2' = -k2·X1 + k3·X2 - k4·X2·X3
    X3' = k5·X1² - k6·X3

Parameters: k = [0.9, 0.9, 1.0, 1.0, 0.6, 0.6]
"""
struct OscProblem <: BenchmarkProblem
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
    
    function OscProblem(; problem_name="osc1")
        params = Dict(
            :k1 => 0.9, :k2 => 0.9, :k3 => 1.0,
            :k4 => 1.0, :k5 => 0.6, :k6 => 0.6
        )
        
        # Variable mapping: x1=X1, x2=X2, x3=X3
        var_names = ["x1", "x2", "x3"]
        binary_ops = [+, -, *, /, ^]
        unary_ops = Function[]
        
        # X1' = 0.9*x2
        eq1_str = "0.9*x2"
        eq1 = parse_expression(eq1_str; binary_operators=binary_ops, unary_operators=unary_ops, variable_names=var_names)
        
        # X2' = -0.9*x1 + 1.0*x2 - 1.0*x2*x3
        eq2_str = "-0.9*x1 + 1.0*x2 - 1.0*x2*x3"
        eq2 = parse_expression(eq2_str; binary_operators=binary_ops, unary_operators=unary_ops, variable_names=var_names)
        
        # X3' = 0.6*x1^2 - 0.6*x3
        eq3_str = "0.6*x1^2 - 0.6*x3"
        eq3 = parse_expression(eq3_str; binary_operators=binary_ops, unary_operators=unary_ops, variable_names=var_names)
        
        trees = [eq1, eq2, eq3]
        
        noise = problem_name == "osc1" ? 0.0 : 0.03
        exp_configs = [(X0=[1.0, 0.0, 0.0],)]
        
        new(
            problem_name,
            3,  # n_states
            0,  # n_inputs
            trees,
            params,
            [1.0, 0.0, 0.0],
            (0.0, 20.0),
            41,
            noise,
            exp_configs
        )
    end
end

Osc1() = OscProblem(problem_name="osc1")
Osc2() = OscProblem(problem_name="osc2")

function evaluate_system(problem::OscProblem, X, inputs, t)
    X1, X2, X3 = X
    k1, k2, k3, k4, k5, k6 = 0.9, 0.9, 1.0, 1.0, 0.6, 0.6
    
    dX1 = k1 * X2
    dX2 = -k2 * X1 + k3 * X2 - k4 * X2 * X3
    dX3 = k5 * X1^2 - k6 * X3
    
    return [dX1, dX2, dX3]
end

function generate_varied_ic(problem::OscProblem, base_ic::Vector{Float64})
    return rand(3)
end

function BaseProblemModule.generate_data(
    problem::OscProblem;
    X0::Vector{Float64}=problem.default_ic,
    tspan::Tuple{Float64,Float64}=problem.default_tspan,
    n_points::Int=problem.default_n_points,
    noise_std::Float64=problem.default_noise,
    input_values::Dict=Dict()
)
    function ode_func!(dX, X, p, t)
        dX .= evaluate_system(problem, X, input_values, t)
    end
    
    prob = ODEProblem(ode_func!, X0, tspan)
    t_eval = range(tspan[1], tspan[2], length=n_points)
    sol = solve(prob, AutoTsit5(Rosenbrock23()), saveat=t_eval)
    
    t = sol.t
    X = collect(hcat(sol.u...)')  # Convert Adjoint to Matrix
    
    BaseProblemModule.add_gaussian_noise!(X, noise_std)
    
    return t, X, Dict()
end

function BaseProblemModule.generate_experiments(
    problem::OscProblem;
    num_trajectories::Int=1,
    noise_std::Union{Float64,Nothing}=nothing,
    n_points::Union{Int,Nothing}=nothing
)
    noise = noise_std === nothing ? problem.default_noise : noise_std
    npts = n_points === nothing ? problem.default_n_points : n_points
    
    experiments = []
    
    for (exp_idx, exp_config) in enumerate(problem.experiment_configs)
        for traj_idx in 1:num_trajectories
            X0 = traj_idx == 1 ? exp_config.X0 : generate_varied_ic(problem, exp_config.X0)
            
            t, X, inputs = BaseProblemModule.generate_data(
                problem;
                X0=X0,
                tspan=problem.default_tspan,
                n_points=npts,
                noise_std=noise
            )
            
            push!(experiments, Dict(
                :experiment => exp_idx,
                :trajectory => traj_idx,
                :t => t,
                :X => X,
                :inputs => inputs,
                :params => exp_config,
                :ic => (X1_0=X0[1], X2_0=X0[2], X3_0=X0[3])
            ))
        end
    end
    
    return experiments
end

function BaseProblemModule.get_equation_strings(problem::OscProblem; format::Symbol=:text)
    if format == :text || format == :julia
        return [
            "X1' = 0.9·X2",
            "X2' = -0.9·X1 + 1.0·X2 - 1.0·X2·X3",
            "X3' = 0.6·X1² - 0.6·X3"
        ]
    elseif format == :latex
        return [
            raw"\frac{dX_1}{dt} = k_1 X_2",
            raw"\frac{dX_2}{dt} = -k_2 X_1 + k_3 X_2 - k_4 X_2 X_3",
            raw"\frac{dX_3}{dt} = k_5 X_1^2 - k_6 X_3"
        ]
    else
        error("Unknown format: $format")
    end
end

end # module
