"""
SSystemBase.jl

Base module for S-system models.

S-system formalism (Savageau 1976, Voit 2000) approximates kinetic laws with 
multivariate power-law functions.

Generic form: Xi'(t) = αi ∏j Xj^gij - βi ∏j Xj^hij

where:
- X: vector of variables
- α, β: vectors of non-negative rate constants
- g, h: matrices of kinetic orders (can be negative or positive)
"""

module SSystemBase

using DifferentialEquations

export ssystem_ode, generate_ssystem_data, format_ssystem_equations

"""
    ssystem_ode(X, α, β, g, h, inputs, t)

Generic S-system ODE function.

Arguments:
- X: State vector
- α: Production rate constants (vector, length n)
- β: Degradation rate constants (vector, length n)
- g: Production kinetic orders (matrix, n×n)
- h: Degradation kinetic orders (matrix, n×n)
- inputs: Dictionary of input functions
- t: Time

Returns:
- dX: Time derivatives
"""
function ssystem_ode(X, α, β, g, h, inputs, t)
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
        # Production term: αi ∏j Xj^gij
        prod_term = α[i] * one(eltype(X))
        for j in 1:length(X_full)
            if g[i, j] != 0.0
                prod_term *= X_full[j]^g[i, j]
            end
        end
        
        # Degradation term: βi ∏j Xj^hij
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

"""
    generate_ssystem_data(α, β, g, h; X0, tspan, n_points, noise_std, inputs)

Generate data from an S-system model.

Arguments:
- α: Production rate constants
- β: Degradation rate constants
- g: Production kinetic orders matrix
- h: Degradation kinetic orders matrix
- X0: Initial conditions
- tspan: Time span tuple
- n_points: Number of time points
- noise_std: Noise level (as fraction)
- inputs: Dictionary of input functions (optional)

Returns:
- t: Time points
- X: State matrix
- input_values: Dictionary of input values
"""
function generate_ssystem_data(
    α, β, g, h;
    X0,
    tspan=(0.0, 10.0),
    n_points=51,
    noise_std=0.0,
    inputs=Dict{Symbol, Function}()
)
    # Define ODE problem
    function ode_func!(dX, X, p, t)
        dX .= ssystem_ode(X, α, β, g, h, inputs, t)
    end
    
    prob = ODEProblem(ode_func!, X0, tspan)
    
    # Solve ODE
    t_eval = range(tspan[1], tspan[2], length=n_points)
    sol = solve(prob, AutoTsit5(Rosenbrock23()), saveat=t_eval)
    
    # Extract solution
    t = sol.t
    X = hcat(sol.u...)'
    
    # Add noise if requested
    if noise_std > 0.0
        for i in 1:size(X, 1)
            for j in 1:size(X, 2)
                noise = noise_std * abs(X[i, j]) * randn()
                X[i, j] += noise
            end
        end
    end
    
    # Prepare input values
    input_values = Dict()
    for (key, func) in inputs
        input_values[key] = [func(ti) for ti in t]
    end
    
    return t, X, input_values
end

"""
    format_ssystem_equations(α, β, g, h, n_vars, input_indices=nothing)

Format S-system equations as strings given parameters.

S-system form: Xi'(t) = αi ∏j Xj^gij - βi ∏j Xj^hij

Arguments:
- α: Production rate constants
- β: Degradation rate constants  
- g: Production kinetic orders matrix
- h: Degradation kinetic orders matrix
- n_vars: Number of state variables
- input_indices: Optional dict mapping input variable indices to names (e.g., Dict(4 => "X4"))

Returns:
- Vector of equation strings
"""
function format_ssystem_equations(α, β, g, h, n_vars, input_indices=nothing)
    equations = String[]
    
    for i in 1:n_vars
        # Production term: αi ∏j Xj^gij
        prod_terms = String[]
        if α[i] != 1.0
            push!(prod_terms, string(α[i]))
        end
        
        for j in 1:size(g, 2)
            if g[i, j] != 0.0
                var_name = (input_indices !== nothing && j in keys(input_indices)) ? input_indices[j] : "X$j"
                if g[i, j] == 1.0
                    push!(prod_terms, var_name)
                elseif g[i, j] == -1.0
                    push!(prod_terms, "$(var_name)^(-1)")
                else
                    push!(prod_terms, "$(var_name)^$(g[i, j])")
                end
            end
        end
        prod_str = isempty(prod_terms) ? string(α[i]) : join(prod_terms, "*")
        
        # Degradation term: βi ∏j Xj^hij
        deg_terms = String[]
        if β[i] != 1.0
            push!(deg_terms, string(β[i]))
        end
        
        for j in 1:size(h, 2)
            if h[i, j] != 0.0
                var_name = (input_indices !== nothing && j in keys(input_indices)) ? input_indices[j] : "X$j"
                if h[i, j] == 1.0
                    push!(deg_terms, var_name)
                elseif h[i, j] == -1.0
                    push!(deg_terms, "$(var_name)^(-1)")
                else
                    push!(deg_terms, "$(var_name)^$(h[i, j])")
                end
            end
        end
        deg_str = isempty(deg_terms) ? string(β[i]) : join(deg_terms, "*")
        
        # Combine into equation
        push!(equations, "X$(i)' = $prod_str - $deg_str")
    end
    
    return equations
end

end # module

