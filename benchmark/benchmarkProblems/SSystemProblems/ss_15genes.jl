"""
ss_15genes.jl

S-system genetic network with 15 dependent variables.
Larger version of the 5-gene network.
"""

module Ss15genesModule

include("SSystemBase.jl")
using .SSystemBase
using DifferentialEquations

export ss_15genes_system, generate_ss_15genes_data, generate_ss_15genes_experiments, get_equation_strings

# System parameters (15 variables) - Extended pattern from 5-gene network
function get_parameters()
    n = 15
    α = zeros(n)
    β = fill(10.0, n)
    g = zeros(n, n)
    h = zeros(n, n)
    
    # Pattern: similar to 5-gene but extended
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
        else # i % 5 == 0
            α[i] = 10.0
            g[i, i-1] = 2.0
            h[i, i] = 2.0
        end
    end
    
    return α, β, g, h
end

function ss_15genes_system(X, inputs, t)
    α, β, g, h = get_parameters()
    return SSystemBase.ssystem_ode(X, α, β, g, h, inputs, t)
end

function generate_ss_15genes_data(;
    X0=ones(15),
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

function generate_ss_15genes_experiments(; problem="ss_15genes1", noise_std::Union{Float64,Nothing}=nothing)
    params = Dict(
        "ss_15genes1" => (n_exp=10, n_points=11, noise_std=0.0),
        "ss_15genes2" => (n_exp=20, n_points=11, noise_std=0.10)
    )
    
    if !haskey(params, problem)
        error("Unknown problem: $problem. Choose from ss_15genes1, ss_15genes2")
    end
    
    p = params[problem]
    _noise = noise_std !== nothing ? noise_std : p.noise_std
    experiments = []
    
    for exp in 1:p.n_exp
        X0 = 1.0 .+ 0.5 * randn(15)
        X0 = max.(X0, 0.1)
        
        t, X, input_values = generate_ss_15genes_data(
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

Return the ground truth equations for ss_15genes problems as strings.
Uses S-system format with extended 5-gene pattern.
"""
function get_equation_strings(problem::String)
    if !startswith(problem, "ss_15genes")
        error("Problem $problem is not a ss_15genes problem")
    end
    
    α, β, g, h = get_parameters()
    return SSystemBase.format_ssystem_equations(α, β, g, h, 15, nothing)
end

end # module
