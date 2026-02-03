"""
helpers.jl

Shared utility functions used across multiple modules.
"""

"""
    normalize_equation_internal(tree, sr_options)

Internal normalization function for printing equations.
Uses the same simplification logic as benchmark normalization for consistency.

# Arguments
- `tree`: Expression tree from symbolic regression
- `sr_options`: SymbolicRegression.Options for tree evaluation

# Returns
- Normalized equation string with simplified symbols and rounded constants
"""
function normalize_equation_internal(tree, sr_options)
    # Convert tree to string
    eq_str = string_tree(tree, sr_options)
    
    # Apply symbolic simplification (same as normalize_equation_unified)
    try
        # Define symbolic variables
        Symbolics.@variables x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20
        
        # Define square function
        square(x) = x * x
        
        # Parse and evaluate the equation string
        expr = Meta.parse(eq_str)
        symbolic_expr = eval(expr)
        
        # Simplification pipeline (same as unified normalization)
        simplified = SymbolicUtils.simplify(symbolic_expr)
        simplified = Symbolics.expand(simplified)
        simplified = SymbolicUtils.simplify(simplified)
        
        # Convert back to string
        eq_str = string(simplified)
    catch e
        # Continue with original string if simplification fails
    end
    
    # Round constants (same as normalize_equation_unified)
    pattern = r"(-?\d+\.?\d*(?:[eE][+-]?\d+)?)"
    eq_str = replace(eq_str, pattern => m -> begin
        num = parse(Float64, m)
        rounded = round(num, digits=2)
        formatted = string(rounded)
        if occursin('.', formatted)
            formatted = replace(formatted, r"\.?0+$" => "")
        end
        formatted
    end)
    
    return eq_str
end

"""
    setup_input_interpolations(t, inputs)

Create interpolation functions for time-varying inputs.

# Arguments
- `t`: Time vector
- `inputs`: Dictionary of input name => values pairs

# Returns
- Dictionary of interpolation functions for each input
"""
function setup_input_interpolations(t, inputs)
    input_interps = Dict()
    
    if !isempty(inputs)
        for (name, values) in inputs
            if length(values) == length(t)
                input_interps[name] = LinearInterpolation(t, values, extrapolation_bc=Line())
            end
        end
    end
    
    return input_interps
end

"""
    create_ode_function(trees, input_interps)

Create an ODE function from equation trees and input interpolations.

# Arguments
- `trees`: Vector of expression trees, one per state variable
- `input_interps`: Dictionary of input interpolation functions

# Returns
- ODE dynamics function with signature (dx, x, p, t)
"""
function create_ode_function(trees, input_interps)
    n_states = length(trees)
    
    function ode_dynamics!(dx, x, p, t_curr)
        if !all(isfinite, x) || !isfinite(t_curr)
            fill!(dx, Inf)
            return
        end
        
        # Features are just states (no time)
        features = copy(x)
        
        if !isempty(input_interps)
            for key in sort(collect(keys(input_interps)))
                push!(features, input_interps[key](t_curr))
            end
        end
        
        feature_matrix = reshape(features, :, 1)
        
        try
            for i in 1:n_states
                dx[i] = trees[i](feature_matrix)[1]
            end
            
            if !all(isfinite, dx)
                fill!(dx, Inf)
            end
        catch
            fill!(dx, Inf)
        end
    end
    
    return ode_dynamics!
end
