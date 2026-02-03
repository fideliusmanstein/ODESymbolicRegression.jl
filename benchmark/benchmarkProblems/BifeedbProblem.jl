"""
Bi-feedback problem (bifeedb) using unified architecture.

Based on: https://www.cse.chalmers.se/~dag/identification/Benchmarks/bifeedb.html
Bi-molecular reactions with feedback, using 4 or 5 dependent variables.
"""

module BifeedbProblemModule

using DifferentialEquations
using ..BaseProblemModule

export BifeedbProblem, Bifeedb1, Bifeedb2

"""
    BifeedbProblem

Bi-feedback benchmark problem with Michaelis-Menten type reactions.

System equations (variant 1, 4 states):
    X1' = 1.0/(X3+0.1) - 1.0*X1^2
    X2' = 1.0*X1^2 - 1.0*X2/(X2+0.1)
    X3' = 1.0*X2/(X2+0.1) - 1.0*X3/(X3+0.1)
    X4' = 1.0*X3/(X3+0.1) - 1.0*X4/(X4+0.1)

Variant 2 (5 states) adds:
    X5' = 1.0*X4/(X4+0.1) - 1.0*X5/(X5+0.1)
"""
struct BifeedbProblem <: BaseProblemModule.BenchmarkProblem
    name::String
    n_states::Int
    n_inputs::Int
    tree_equations::Vector  # Empty for now - complex equations
    parameter_values::Dict{Symbol, Float64}
    default_ic::Vector{Float64}
    default_tspan::Tuple{Float64, Float64}
    default_n_points::Int
    default_noise::Float64
    experiment_configs::Vector{NamedTuple}
    variant::Int
    
    function BifeedbProblem(; problem_name="bifeedb1")
        variant = parse(Int, replace(problem_name, r"(bifeedb|gma_bifeedb|ss_bifeedb)" => ""))
        num_states = variant == 1 ? 4 : 5
        
        params = Dict{Symbol, Float64}()
        
        # No tree equations for complex Michaelis-Menten kinetics
        trees = []
        
        noise = variant == 1 ? 0.0 : 0.0
        exp_configs = [(X0=ones(num_states),)]
        
        new(
            problem_name,
            num_states,
            0,  # n_inputs
            trees,
            params,
            ones(num_states),
            (0.0, 5.0),
            51,
            noise,
            exp_configs,
            variant
        )
    end
end

# Convenience constructors
Bifeedb1() = BifeedbProblem(problem_name="bifeedb1")
Bifeedb2() = BifeedbProblem(problem_name="bifeedb2")

Bifeedb1() = BifeedbProblem(problem_name="bifeedb1")
Bifeedb2() = BifeedbProblem(problem_name="bifeedb2")

function evaluate_system(problem::BifeedbProblem, X, inputs, t)
    if problem.variant == 1
        X1, X2, X3, X4 = X
        
        dX1 = 1.0 / (X3 + 0.1) - 1.0 * X1^2
        dX2 = 1.0 * X1^2 - 1.0 * X2 / (X2 + 0.1)
        dX3 = 1.0 * X2 / (X2 + 0.1) - 1.0 * X3 / (X3 + 0.1)
        dX4 = 1.0 * X3 / (X3 + 0.1) - 1.0 * X4 / (X4 + 0.1)
        
        return [dX1, dX2, dX3, dX4]
    else # variant == 2
        X1, X2, X3, X4, X5 = X
        
        dX1 = 1.0 / (X3 + 0.1) - 1.0 * X1^2
        dX2 = 1.0 * X1^2 - 1.0 * X2 / (X2 + 0.1)
        dX3 = 1.0 * X2 / (X2 + 0.1) - 1.0 * X3 / (X3 + 0.1)
        dX4 = 1.0 * X3 / (X3 + 0.1) - 1.0 * X4 / (X4 + 0.1)
        dX5 = 1.0 * X4 / (X4 + 0.1) - 1.0 * X5 / (X5 + 0.1)
        
        return [dX1, dX2, dX3, dX4, dX5]
    end
end

function generate_varied_ic(problem::BifeedbProblem, base_ic::Vector{Float64})
    return rand(problem.n_states)
end

function BaseProblemModule.generate_data(
    problem::BifeedbProblem;
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
    X = collect(hcat(sol.u...)')
    
    BaseProblemModule.add_gaussian_noise!(X, noise_std)
    
    return t, X, Dict()
end

function BaseProblemModule.generate_experiments(
    problem::BifeedbProblem;
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
            
            exp_dict = Dict(
                :experiment => exp_idx,
                :trajectory => traj_idx,
                :t => t,
                :X => X,
                :inputs => inputs,
                :params => exp_config
            )
            
            # Add IC fields based on number of states
            if problem.n_states == 4
                exp_dict[:ic] = (X1_0=X0[1], X2_0=X0[2], X3_0=X0[3], X4_0=X0[4])
            else
                exp_dict[:ic] = (X1_0=X0[1], X2_0=X0[2], X3_0=X0[3], X4_0=X0[4], X5_0=X0[5])
            end
            
            push!(experiments, exp_dict)
        end
    end
    
    return experiments
end

function BaseProblemModule.get_equation_strings(problem::BifeedbProblem; format::Symbol=:text)
    if problem.variant == 1
        return [
            "X1' = 1.0/(X3+0.1) - 1.0*X1^2",
            "X2' = 1.0*X1^2 - 1.0*X2/(X2+0.1)",
            "X3' = 1.0*X2/(X2+0.1) - 1.0*X3/(X3+0.1)",
            "X4' = 1.0*X3/(X3+0.1) - 1.0*X4/(X4+0.1)"
        ]
    else
        return [
            "X1' = 1.0/(X3+0.1) - 1.0*X1^2",
            "X2' = 1.0*X1^2 - 1.0*X2/(X2+0.1)",
            "X3' = 1.0*X2/(X2+0.1) - 1.0*X3/(X3+0.1)",
            "X4' = 1.0*X3/(X3+0.1) - 1.0*X4/(X4+0.1)",
            "X5' = 1.0*X4/(X4+0.1) - 1.0*X5/(X5+0.1)"
        ]
    end
end

end # module
