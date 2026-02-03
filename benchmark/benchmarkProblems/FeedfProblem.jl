"""
Feed-forward problem (feedf) using unified architecture.

Based on: https://www.cse.chalmers.se/~dag/identification/Benchmarks/feedf.html
Two Michaelis-Menten reactions affecting production of a single variable.
"""

module FeedfProblemModule

using DifferentialEquations
using ..BaseProblemModule

export FeedfProblem, Feedf1, Feedf2

"""
    FeedfProblem

Feed-forward pathway with Michaelis-Menten kinetics.

System equations (4 states, 2 inputs):
    X1' = In1 - 1.0*X1/(X1+0.5)
    X2' = In2 - 1.0*X2/(X2+0.4)
    X3' = 1.0*X1/(X1+0.5) + 1.0*X2/(X2+0.4) - 1.0*X3/(X3+0.3)
    X4' = 1.0*X3/(X3+0.3) - 1.0*X4/(X4+0.3)
"""
struct FeedfProblem <: BaseProblemModule.BenchmarkProblem
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
    
    function FeedfProblem(; problem_name="feedf1")
        variant = parse(Int, replace(problem_name, r"(feedf|gma_feedf|ss_feedf)" => ""))
        
        params = Dict{Symbol, Float64}()
        trees = []
        
        # Input constants vary by variant
        if variant == 1
            In1_const, In2_const = 1.0, 1.0
        else
            In1_const, In2_const = 2.0, 1.5
        end
        
        input_funcs = Dict(
            :In1 => (t -> In1_const),
            :In2 => (t -> In2_const)
        )
        
        noise = 0.0
        exp_configs = [(X0=[0.5, 0.5, 0.5, 0.5], In1=In1_const, In2=In2_const)]
        
        new(
            problem_name,
            4,  # n_states
            2,  # n_inputs
            trees,
            params,
            [0.5, 0.5, 0.5, 0.5],
            (0.0, 5.0),
            51,
            noise,
            exp_configs,
            variant,
            input_funcs
        )
    end
end

Feedf1() = FeedfProblem(problem_name="feedf1")
Feedf2() = FeedfProblem(problem_name="feedf2")

function evaluate_system(problem::FeedfProblem, X, inputs, t)
    X1, X2, X3, X4 = X
    
    # Get inputs
    In1 = inputs[:In1](t)
    In2 = inputs[:In2](t)
    
    # System equations
    dX1 = In1 - 1.0 * X1 / (X1 + 0.5)
    dX2 = In2 - 1.0 * X2 / (X2 + 0.4)
    dX3 = 1.0 * X1 / (X1 + 0.5) + 1.0 * X2 / (X2 + 0.4) - 1.0 * X3 / (X3 + 0.3)
    dX4 = 1.0 * X3 / (X3 + 0.3) - 1.0 * X4 / (X4 + 0.3)
    
    return [dX1, dX2, dX3, dX4]
end

function generate_varied_ic(problem::FeedfProblem, base_ic::Vector{Float64})
    return rand(problem.n_states) .* 0.5 .+ 0.25  # Random ICs in [0.25, 0.75]
end

function BaseProblemModule.generate_data(
    problem::FeedfProblem;
    X0::Vector{Float64}=problem.default_ic,
    tspan::Tuple{Float64,Float64}=problem.default_tspan,
    n_points::Int=problem.default_n_points,
    noise_std::Float64=problem.default_noise,
    input_values::Dict=problem.input_functions
)
    function ode_func!(dX, X, p, t)
        dX .= evaluate_system(problem, X, input_values, t)
    end
    
    prob = ODEProblem(ode_func!, X0, tspan)
    t_eval = range(tspan[1], tspan[2], length=n_points)
    sol = solve(prob, AutoTsit5(Rosenbrock23()), saveat=t_eval)
    
    t = sol.t
    X = collect(hcat(sol.u...)')
    
    BaseProblemModule.add_gaussian_noise!(X, noise_std)
    
    # Create input value arrays
    inputs_out = Dict(
        :In1 => [input_values[:In1](ti) for ti in t],
        :In2 => [input_values[:In2](ti) for ti in t]
    )
    
    return t, X, inputs_out
end

function BaseProblemModule.generate_experiments(
    problem::FeedfProblem;
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
                noise_std=noise,
                input_values=problem.input_functions
            )
            
            push!(experiments, Dict(
                :experiment => exp_idx,
                :trajectory => traj_idx,
                :t => t,
                :X => X,
                :inputs => inputs,
                :params => exp_config,
                :ic => (X1_0=X0[1], X2_0=X0[2], X3_0=X0[3], X4_0=X0[4])
            ))
        end
    end
    
    return experiments
end

function BaseProblemModule.get_equation_strings(problem::FeedfProblem; format::Symbol=:text)
    return [
        "X1' = In1 - 1.0*X1/(X1+0.5)",
        "X2' = In2 - 1.0*X2/(X2+0.4)",
        "X3' = 1.0*X1/(X1+0.5) + 1.0*X2/(X2+0.4) - 1.0*X3/(X3+0.3)",
        "X4' = 1.0*X3/(X3+0.3) - 1.0*X4/(X4+0.3)"
    ]
end

end # module
