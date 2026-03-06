"""
ss_5genes.jl

S-system genetic network with 5 dependent variables.
Based on: Hlavacek et al. (1996), Kikuchi et al. (2003)
"""

module Ss5genesModule

include("SSystemBase.jl")
using .SSystemBase
using DifferentialEquations

export ss_5genes_system, generate_ss_5genes_data, generate_ss_5genes_experiments, get_equation_strings

# System parameters (5 variables)
const α = [5.0, 10.0, 10.0, 8.0, 10.0]
const β = [10.0, 10.0, 10.0, 10.0, 10.0]
const g = [0.0   0.0   1.0  0.0  -1.0;
           2.0   0.0   0.0  0.0   0.0;
           0.0  -1.0   0.0  0.0   0.0;
           0.0   0.0   2.0  0.0  -1.0;
           0.0   0.0   0.0  2.0   0.0]
const h = [2.0  0.0   0.0  0.0  0.0;
           0.0  2.0   0.0  0.0  0.0;
           0.0  -1.0  2.0  0.0  0.0;
           0.0  0.0   0.0  2.0  0.0;
           0.0  0.0   0.0  0.0  2.0]

"""
    ss_5genes_system(X, inputs, t)

Genetic network S-system with 5 dependent variables.

Equations:
    X1'(t) = 5·X3·X5^(-1) - 10·X1^2
    X2'(t) = 10·X1^2 - 10·X2^2
    X3'(t) = 10·X2^(-1) - 10·X2^(-1)·X3^2
    X4'(t) = 8·X3^2·X5^(-1) - 10·X4^2
    X5'(t) = 10·X4^2 - 10·X5^2
"""
function ss_5genes_system(X, inputs, t)
    return SSystemBase.ssystem_ode(X, α, β, g, h, inputs, t)
end

function generate_ss_5genes_data(;
    X0=[1.0, 1.0, 1.0, 1.0, 1.0],
    tspan=(0.0, 10.0),
    n_points=11,
    noise_std=0.0
)
    inputs = Dict{Symbol, Function}()
    
    t, X, input_values = SSystemBase.generate_ssystem_data(
        α, β, g, h;
        X0=X0,
        tspan=tspan,
        n_points=n_points,
        noise_std=noise_std,
        inputs=inputs
    )
    
    return t, X, input_values
end

function generate_ss_5genes_experiments(; problem="ss_5genes1", noise_std::Union{Float64,Nothing}=nothing, n_points::Union{Int,Nothing}=nothing)
    # Problem-specific parameters
    params = Dict(
        "ss_5genes1" => (n_exp=10, n_points=11, noise_std=0.0),
        "ss_5genes2" => (n_exp=10, n_points=9, noise_std=0.0),
        "ss_5genes3" => (n_exp=10, n_points=3, noise_std=0.0),
        "ss_5genes4" => (n_exp=15, n_points=11, noise_std=0.0),
        "ss_5genes5" => (n_exp=10, n_points=11, noise_std=0.0),
        "ss_5genes6" => (n_exp=1, n_points=16, noise_std=0.0),
        "ss_5genes7" => (n_exp=10, n_points=20, noise_std=0.0),
        "ss_5genes8" => (n_exp=8, n_points=41, noise_std=0.0)
    )
    
    if !haskey(params, problem)
        error("Unknown problem: $problem. Choose from ss_5genes1-8")
    end
    
    p = params[problem]
    _noise = noise_std !== nothing ? noise_std : p.noise_std
    _n_points = n_points !== nothing ? n_points : p.n_points
    experiments = []
    
    for exp in 1:p.n_exp
        X0 = 1.0 .+ 0.5 * randn(5)
        X0 = max.(X0, 0.1)
        
        t, X, input_values = generate_ss_5genes_data(
            X0=X0,
            tspan=(0.0, 10.0),
            n_points=_n_points,
            noise_std=_noise
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

Return the ground truth equations for ss_5genes problems as strings.

Equations:
    X1' = 5·X3·X5^(-1) - 10·X1^2
    X2' = 10·X1^2 - 10·X2^2
    X3' = 10·X2^(-1) - 10·X2^(-1)·X3^2
    X4' = 8·X3^2·X5^(-1) - 10·X4^2
    X5' = 10·X4^2 - 10·X5^2
"""
function get_equation_strings(problem::String)
    if !startswith(problem, "ss_5genes")
        error("Problem $problem is not a ss_5genes problem")
    end
    
    return SSystemBase.format_ssystem_equations(α, β, g, h, 5, nothing)
end

end # module

