"""
ss_30genes.jl

S-system genetic network with 30 dependent variables.
Large-scale version of the gene network.
"""

module Ss30genesModule

include("SSystemBase.jl")
using .SSystemBase
using DifferentialEquations

export ss_30genes_system, generate_ss_30genes_data, generate_ss_30genes_experiments, get_equation_strings, get_equation_strings

function get_parameters()
    n = 30
    α = zeros(n)
    β = fill(10.0, n)
    g = zeros(n, n)
    h = zeros(n, n)
    
    # Extended pattern from 5-gene network
    for i in 1:n
        if i % 5 == 1
            α[i] = 5.0
            g[i, mod1(i+2, n)] = 1.0
            g[i, mod1(i+4, n)] = -1.0
            h[i, i] = 2.0
        elseif i % 5 == 2
            α[i] = 10.0
            g[i, i-1] = 2.0
            h[i, i] = 2.0
        elseif i % 5 == 3
            α[i] = 10.0
            g[i, i-1] = -1.0
            h[i, i-1] = -1.0
            h[i, i] = 2.0
        elseif i % 5 == 4
            α[i] = 8.0
            g[i, i-1] = 2.0
            g[i, mod1(i+1, n)] = -1.0
            h[i, i] = 2.0
        else
            α[i] = 10.0
            g[i, i-1] = 2.0
            h[i, i] = 2.0
        end
    end
    
    return α, β, g, h
end

function ss_30genes_system(X, inputs, t)
    α, β, g, h = get_parameters()
    return SSystemBase.ssystem_ode(X, α, β, g, h, inputs, t)
end

function generate_ss_30genes_data(;
    X0=ones(30),
    tspan=(0.0, 10.0),
    n_points=11,
    noise_std=0.0
)
    α, β, g, h = get_parameters()
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

function generate_ss_30genes_experiments(; problem="ss_30genes1", noise_std::Union{Float64,Nothing}=nothing)
    params = Dict(
        "ss_30genes1" => (n_exp=15, n_points=11, noise_std=0.0),
        "ss_30genes2" => (n_exp=20, n_points=11, noise_std=0.0),
        "ss_30genes3" => (n_exp=8, n_points=41, noise_std=0.0)
    )
    
    if !haskey(params, problem)
        error("Unknown problem: $problem. Choose from ss_30genes1-3")
    end
    
    p = params[problem]
    _noise = noise_std !== nothing ? noise_std : p.noise_std
    experiments = []
    
    for exp in 1:p.n_exp
        X0 = 1.0 .+ 0.5 * randn(30)
        X0 = max.(X0, 0.1)
        
        t, X, input_values = generate_ss_30genes_data(
            X0=X0,
            tspan=(0.0, 10.0),
            n_points=p.n_points,
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

Return the ground truth equations for ss_30genes problems as strings.
Uses S-system format with extended 5-gene pattern.
"""
function get_equation_strings(problem::String)
    if !startswith(problem, "ss_30genes")
        error("Problem $problem is not a ss_30genes problem")
    end
    
    α, β, g, h = get_parameters()
    return SSystemBase.format_ssystem_equations(α, β, g, h, 30, nothing)
end

end # module

