"""
ss_bifeedb.jl

S-system approximation of bi-molecular feedback.
"""

module SsBifeedbModule

include("SSystemBase.jl")
using .SSystemBase
using DifferentialEquations

export ss_bifeedb_system, generate_ss_bifeedb_data, generate_ss_bifeedb_experiments, get_equation_strings

const α = [1.0, 1.0, 1.0, 1.0, 1.0]
const β = [1.0, 1.0, 1.0, 1.0, 1.0]
const g_mat = [0.0  0.0  -0.5  0.0  0.0;
               2.0  0.0   0.0  0.0  0.0;
               0.0  0.5   0.0  0.0  0.0;
               0.0  0.0   0.5  0.0  0.0;
               0.0  0.0   0.0  0.5  0.0]
const h_mat = [2.0  0.0  0.0  0.0  0.0;
               0.0  0.5  0.0  0.0  0.0;
               0.0  0.0  0.5  0.0  0.0;
               0.0  0.0  0.0  0.5  0.0;
               0.0  0.0  0.0  0.0  0.5]

function ss_bifeedb_system(X, inputs, t)
    return SSystemBase.ssystem_ode(X, α, β, g_mat, h_mat, inputs, t)
end

function generate_ss_bifeedb_data(;
    X0=ones(5),
    tspan=(0.0, 5.0),
    n_points=51,
    noise_std=0.0
)
    inputs = Dict{Symbol, Function}()
    
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

function generate_ss_bifeedb_experiments(; problem="ss_bifeedb1", noise_std::Union{Float64,Nothing}=nothing)
    noise_std = noise_std !== nothing ? noise_std : 0.0
    experiments = []
    
    X_ss = [0.5, 1.0, 1.5, 2.0, 2.5]
    
    for exp in 1:16
        X0 = X_ss .* (1.0 .+ 0.75 * (2.0 * rand(5) .- 1.0))
        X0 = max.(X0, 0.01)
        
        t, X, _ = generate_ss_bifeedb_data(
            X0=X0,
            tspan=(0.0, 5.0),
            n_points=51,
            noise_std=noise_std
        )
        
        push!(experiments, Dict(
            :experiment => exp,
            :t => t,
            :X => X,
            :inputs => Dict(),
            :X0 => X0
        ))
    end
    
    return experiments
end

"""
    get_equation_strings(problem::String)

Return the ground truth equations for ss_bifeedb problems as strings.
S-system approximation of bi-molecular feedback.
"""
function get_equation_strings(problem::String)
    if !startswith(problem, "ss_bifeedb")
        error("Problem $problem is not a ss_bifeedb problem")
    end
    
    return SSystemBase.format_ssystem_equations(α, β, g_mat, h_mat, 5, nothing)
end

end # module
