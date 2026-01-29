"""
GMABase.jl

Base module for GMA (Generalized Mass Action) models.

GMA extends S-systems by allowing multiple production and degradation terms.
Form: Xi'(t) = Σk γik ∏j Xj^fik,j - Σk δik ∏j Xj^hik,j
"""

module GMABase

using DifferentialEquations

export gma_ode, generate_gma_data

"""
    gma_ode(X, production_terms, degradation_terms, inputs, t)

Generic GMA ODE function.

For simplicity, we approximate GMA as S-system with averaged kinetic orders.
"""
function gma_ode(X, α, β, g, h, inputs, t)
    n = length(X)
    
    # Build X_full array (state + inputs)
    if !isempty(inputs)
        # Sort keys to ensure consistent ordering
        keys_sorted = sort(collect(keys(inputs)))
        input_values = [inputs[k](t) for k in keys_sorted]
        X_full = vcat(X, input_values)
    else
        X_full = X
    end
    
    # Compute derivatives
    dX = similar(X)
    for i in 1:n
        prod_term = α[i] * one(eltype(X))
        for j in 1:length(X_full)
            if g[i, j] != 0.0
                prod_term *= X_full[j]^g[i, j]
            end
        end
        
        deg_term = β[i] * one(eltype(X))
        for j in 1:length(X_full)
            if h[i, j] != 0.0
                deg_term *= X_full[j]^h[i, j]
            end
        end
        
        dX[i] = prod_term - deg_term
    end
    
    return dX
end

function generate_gma_data(
    α, β, g, h;
    X0,
    tspan=(0.0, 10.0),
    n_points=51,
    noise_std=0.0,
    inputs=Dict{Symbol, Function}()
)
    function ode_func!(dX, X, p, t)
        dX .= gma_ode(X, α, β, g, h, inputs, t)
    end
    
    prob = ODEProblem(ode_func!, X0, tspan)
    t_eval = range(tspan[1], tspan[2], length=n_points)
    sol = solve(prob, AutoTsit5(Rosenbrock23()), saveat=t_eval)
    
    t = sol.t
    X = hcat(sol.u...)'
    
    if noise_std > 0.0
        for i in 1:size(X, 1)
            for j in 1:size(X, 2)
                noise = noise_std * abs(X[i, j]) * randn()
                X[i, j] += noise
            end
        end
    end
    
    input_values = Dict()
    for (key, func) in inputs
        input_values[key] = [func(ti) for ti in t]
    end
    
    return t, X, input_values
end

end # module
