"""
ss_feedf.jl

S-system approximation of feed-forward pathway.
"""

module SsFeedfModule

include("SSystemBase.jl")
using .SSystemBase
using DifferentialEquations

export ss_feedf_system, generate_ss_feedf_data, generate_ss_feedf_experiments, get_equation_strings

# Approximate S-system parameters for feedf
const α = [1.0, 1.0, 1.5, 1.0, 1.0, 1.0]
const β = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
const g_mat = [0.0  0.0  0.0  0.0  1.0  0.0;
               0.0  0.0  0.0  0.0  0.0  1.0;
               0.5  0.5  0.0  0.0  0.0  0.0;
               0.0  0.0  0.5  0.0  0.0  0.0;
               0.0  0.0  0.0  0.0  0.0  0.0;
               0.0  0.0  0.0  0.0  0.0  0.0]
const h_mat = [0.5  0.0  0.0  0.0  0.0  0.0;
               0.0  0.5  0.0  0.0  0.0  0.0;
               0.0  0.0  0.5  0.0  0.0  0.0;
               0.0  0.0  0.0  0.5  0.0  0.0;
               0.0  0.0  0.0  0.0  0.0  0.0;
               0.0  0.0  0.0  0.0  0.0  0.0]

function ss_feedf_system(X, inputs, t)
    return SSystemBase.ssystem_ode(X[1:4], α[1:4], β[1:4], g_mat[1:4, :], h_mat[1:4, :], inputs, t)
end

function generate_ss_feedf_data(;
    In1_const=1.0,
    In2_const=1.0,
    X0=[0.5, 0.5, 1.5, 0.8],
    tspan=(0.0, 5.0),
    n_points=51,
    noise_std=0.0
)
    inputs = Dict(:X5 => t -> In1_const, :X6 => t -> In2_const)
    
    t, X, input_values = SSystemBase.generate_ssystem_data(
        α[1:4], β[1:4], g_mat[1:4, :], h_mat[1:4, :];
        X0=X0,
        tspan=tspan,
        n_points=n_points,
        noise_std=noise_std,
        inputs=inputs
    )
    
    return t, X, input_values
end

function generate_ss_feedf_experiments(; problem="ss_feedf1")
    noise_std = problem == "ss_feedf1" ? 0.0 : 0.05
    experiments = []
    
    for exp in 1:16
        X0 = [0.5, 0.4, 1.5, 0.8] .* (1.0 .+ 0.75 * (2.0 * rand(4) .- 1.0))
        X0 = max.(X0, 0.01)
        
        t, X, input_values = generate_ss_feedf_data(
            In1_const=1.0,
            In2_const=1.0,
            X0=X0,
            tspan=(0.0, 5.0),
            n_points=51,
            noise_std=noise_std
        )
        
        push!(experiments, Dict(
            :experiment => exp,
            :t => t,
            :X => X,
            :inputs => input_values,
            :X0 => X0
        ))
    end
    
    return experiments
end

"""
    get_equation_strings(problem::String)

Return the ground truth equations for ss_feedf problems as strings.
S-system approximation of feed-forward pathway.
"""
function get_equation_strings(problem::String)
    if !startswith(problem, "ss_feedf")
        error("Problem $problem is not a ss_feedf problem")
    end
    
    return SSystemBase.format_ssystem_equations(α[1:4], β[1:4], g_mat[1:4, :], h_mat[1:4, :], 4, Dict(5 => "X5", 6 => "X6"))
end

end # module
