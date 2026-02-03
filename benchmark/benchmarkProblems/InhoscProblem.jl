"""
Inhibitory oscillator problem (inhosc) using unified architecture.

Based on: https://www.cse.chalmers.se/~dag/identification/Benchmarks/inhosc.html
Inhibitory oscillator with two or four dependent variables.
"""

module InhoscProblemModule

using DifferentialEquations
using ..BaseProblemModule

export InhoscProblem, Inhosc1, Inhosc2

"""
    InhoscProblem

Inhibitory oscillator benchmark problem.

System equations (variant 1, 2 states):
    X1' = In - 1.0/(X2+1.0)
    X2' = 1.0/(X1+1.0) - Out

Variant 2 (4 states):
    X1' = In - 1.0/(X4+1.0)
    X2' = 1.0/(X1+1.0) - 1.0/(X3+1.0)
    X3' = 1.0/(X2+1.0) - 1.0/(X4+1.0)
    X4' = 1.0/(X3+1.0) - Out
"""
struct InhoscProblem <: BaseProblemModule.BenchmarkProblem
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
    
    function InhoscProblem(; problem_name="inhosc1")
        variant = parse(Int, replace(problem_name, r"(inhosc|gma_inhosc|ss_inhosc)" => ""))
        
        params = Dict{Symbol, Float64}()
        trees = []
        
        # Input constants and state count vary by variant
        if variant == 1
            In_const, Out_const = 1.0, 1.0
            n_states = 2
            default_ic = [0.5, 0.5]
            exp_configs = [(X0=[0.5, 0.5], In=In_const, Out=Out_const)]
        else
            In_const, Out_const = 1.0, 1.0
            n_states = 4
            default_ic = [0.5, 0.5, 0.5, 0.5]
            exp_configs = [(X0=[0.5, 0.5, 0.5, 0.5], In=In_const, Out=Out_const)]
        end
        
        input_funcs = Dict(
            :In => (t -> In_const),
            :Out => (t -> Out_const)
        )
        
        noise = 0.0
        
        new(
            problem_name,
            n_states,
            2,  # n_inputs (In, Out)
            trees,
            params,
            default_ic,
            (0.0, 10.0),
            101,
            noise,
            exp_configs,
            variant,
            input_funcs
        )
    end
end

Inhosc1() = InhoscProblem(problem_name="inhosc1")
Inhosc2() = InhoscProblem(problem_name="inhosc2")

function evaluate_system(problem::InhoscProblem, X, inputs, t)
    # Get inputs
    In = inputs[:In](t)
    Out = inputs[:Out](t)
    
    if problem.variant == 1
        X1, X2 = X
        
        dX1 = In - 1.0 / (X2 + 1.0)
        dX2 = 1.0 / (X1 + 1.0) - Out
        
        return [dX1, dX2]
    else # variant == 2
        X1, X2, X3, X4 = X
        
        dX1 = In - 1.0 / (X4 + 1.0)
        dX2 = 1.0 / (X1 + 1.0) - 1.0 / (X3 + 1.0)
        dX3 = 1.0 / (X2 + 1.0) - 1.0 / (X4 + 1.0)
        dX4 = 1.0 / (X3 + 1.0) - Out
        
        return [dX1, dX2, dX3, dX4]
    end
end

function generate_varied_ic(problem::InhoscProblem, base_ic::Vector{Float64})
    return rand(problem.n_states) .* 0.5 .+ 0.25  # Random ICs in [0.25, 0.75]
end

function BaseProblemModule.generate_data(
    problem::InhoscProblem;
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
        :In => [input_values[:In](ti) for ti in t],
        :Out => [input_values[:Out](ti) for ti in t]
    )
    
    return t, X, inputs_out
end

function BaseProblemModule.generate_experiments(
    problem::InhoscProblem;
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
            
            if problem.variant == 1
                ic_tuple = (X1_0=X0[1], X2_0=X0[2])
            else
                ic_tuple = (X1_0=X0[1], X2_0=X0[2], X3_0=X0[3], X4_0=X0[4])
            end
            
            push!(experiments, Dict(
                :experiment => exp_idx,
                :trajectory => traj_idx,
                :t => t,
                :X => X,
                :inputs => inputs,
                :params => exp_config,
                :ic => ic_tuple
            ))
        end
    end
    
    return experiments
end

function BaseProblemModule.get_equation_strings(problem::InhoscProblem; format::Symbol=:text)
    if problem.variant == 1
        return [
            "X1' = In - 1.0/(X2+1.0)",
            "X2' = 1.0/(X1+1.0) - Out"
        ]
    else
        return [
            "X1' = In - 1.0/(X4+1.0)",
            "X2' = 1.0/(X1+1.0) - 1.0/(X3+1.0)",
            "X3' = 1.0/(X2+1.0) - 1.0/(X4+1.0)",
            "X4' = 1.0/(X3+1.0) - Out"
        ]
    end
end

end # module
