"""
ss_inhosc.jl

S-system approximation of inhibitory oscillator.
"""

module SsInhoscModule

include("SSystemBase.jl")
using .SSystemBase
using DifferentialEquations

export ss_inhosc_system, generate_ss_inhosc_data, generate_ss_inhosc_experiments, get_equation_strings

const α = [1.0, 1.0, 1.0, 1.0]
const β = [1.0, 1.0, 1.0, 1.0]
const g_mat = [0.0  -0.5  0.0  0.0  1.0  0.0;
               0.5   0.0  0.0  0.0  0.0  0.0;
               0.0   0.5  0.0 -0.5  0.0  0.0;
               0.0   0.0  0.5  0.0  0.0  0.0]
const h_mat = [0.0  0.0  0.0  0.0  0.0  0.0;
               0.0  0.0  0.5  0.0  0.0  0.0;
               0.0  0.0  0.0  0.0  0.0  0.0;
               0.0  0.0  0.0  0.0  0.0  1.0]

function ss_inhosc_system(X, inputs, t)
    return SSystemBase.ssystem_ode(X, α, β, g_mat, h_mat, inputs, t)
end

function generate_ss_inhosc_data(;
    In_const=1.0,
    Out_const=1.0,
    X0=ones(4),
    tspan=(0.0, 10.0),
    n_points=51,
    noise_std=0.0
)
    inputs = Dict(:In => t -> In_const, :Out => t -> Out_const)
    
    t, X, input_values = SSystemBase.generate_ssystem_data(
        α, β, g_mat, h_mat;
        X0=X0,
        tspan=tspan,
        n_points=n_points,
        noise_std=noise_std,
        inputs=inputs
    )
    
    return t, X, input_values
end

function generate_ss_inhosc_experiments(; problem="ss_inhosc1")
    noise_std = problem == "ss_inhosc1" ? 0.0 : 0.05
    experiments = []
    
    input_combinations = [
        (In=0.8, Out=0.8),
        (In=1.0, Out=1.0),
        (In=1.2, Out=1.0),
        (In=1.0, Out=1.2)
    ]
    
    for (exp, combo) in enumerate(input_combinations)
        t, X, input_values = generate_ss_inhosc_data(
            In_const=combo.In,
            Out_const=combo.Out,
            X0=ones(4),
            tspan=(0.0, 10.0),
            n_points=51,
            noise_std=noise_std
        )
        
        push!(experiments, Dict(
            :experiment => exp,
            :t => t,
            :X => X,
            :inputs => input_values,
            :X0 => ones(4)
        ))
    end
    
    return experiments
end

"""
    get_equation_strings(problem::String)

Return the ground truth equations for ss_inhosc problems as strings.
S-system approximation of inhibitory oscillator.
"""
function get_equation_strings(problem::String)
    if !startswith(problem, "ss_inhosc")
        error("Problem $problem is not a ss_inhosc problem")
    end
    
    return SSystemBase.format_ssystem_equations(α, β, g_mat, h_mat, 4, Dict(5 => "In", 6 => "Out"))
end

end # module
