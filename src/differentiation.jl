"""
differentiation.jl

Numerical differentiation and feature matrix construction.
"""

"""
    compute_numerical_derivatives(t::Vector, X::Matrix; method=:finite_difference, 
                                 window=11, poly_order=2)

Compute numerical derivatives of state variables.

# Arguments
- `t`: Time vector (length n_time)
- `X`: State matrix (n_time × n_states)
- `method`: Derivative computation method (:finite_difference or :savitzky_golay)
- `window`: Window size for Savitzky-Golay filter (must be odd, default: 11)
- `poly_order`: Polynomial order for Savitzky-Golay filter (default: 2)

# Returns
- `dX`: Derivative matrix (n_time × n_states)
"""
function compute_numerical_derivatives(t::Vector, X::Matrix; 
                                      method=:finite_difference,
                                      window=11, 
                                      poly_order=2)
    n_time, n_states = size(X)
    dX = zeros(n_time, n_states)
    
    for i in 1:n_states
        if method == :finite_difference
            # Central difference for interior points
            for j in 2:n_time-1
                dX[j, i] = (X[j+1, i] - X[j-1, i]) / (t[j+1] - t[j-1])
            end
            # Forward/backward difference for endpoints
            dX[1, i] = (X[2, i] - X[1, i]) / (t[2] - t[1])
            dX[end, i] = (X[end, i] - X[end-1, i]) / (t[end] - t[end-1])
        elseif method == :savitzky_golay
            # Savitzky-Golay filter for smoothed derivatives
            h = Float64(t[2] - t[1])  # Assume uniform spacing
            deriv_raw = savitzky_golay(X[:, i], window, poly_order, deriv=1)
            dX[:, i] = deriv_raw.y ./ h
        else
            error("Unknown differentiation method: $method. Use :finite_difference or :savitzky_golay")
        end
    end
    
    return dX
end

"""
    create_feature_matrix(t::Vector, X::Matrix, inputs::Dict=Dict())

Create feature matrix for symbolic regression: [x1, x2, ..., u1, u2, ...]

# Arguments
- `t`: Time vector (not included in features - time is implicit in ODEs)
- `X`: State matrix (n_time × n_states)
- `inputs`: Dictionary of input vectors or functions (optional)

# Returns
- Feature matrix (n_features × n_time) where features are [states; inputs]
"""
function create_feature_matrix(t::Vector, X::Matrix, inputs::Dict=Dict())
    n_time, n_states = size(X)
    
    # Start with states only (no time - it's implicit in the ODE)
    features = X'  # Shape: n_states × n_time
    
    # Add inputs if provided
    if !isempty(inputs)
        input_keys = sort(collect(keys(inputs)))
        for key in input_keys
            input_data = inputs[key]
            # Handle both vectors and functions
            if input_data isa AbstractVector
                input_values = input_data
            else
                # Assume it's a function
                input_values = [input_data(ti) for ti in t]
            end
            features = vcat(features, input_values')
        end
    end
    
    return features
end

"""
    aggregate_features_and_derivatives(experiments, ode_options)

Combine features and derivatives from all trajectories.

# Arguments
- `experiments`: Vector of experiment dicts with keys :t, :X, :inputs
- `ode_options`: ODERegressionOptions

# Returns
- Tuple of (combined_features, combined_derivatives) for symbolic regression
"""
function aggregate_features_and_derivatives(experiments::Vector, ode_options::ODERegressionOptions)
    n_experiments = length(experiments)
    n_states = size(experiments[1][:X], 2)
    
    # Collect all features and derivatives
    all_features_list = []
    all_derivatives_list = []
    
    for exp in experiments
        t = exp[:t]
        X_raw = exp[:X]
        # Ensure X is a Matrix (not Adjoint or other type)
        X = X_raw isa Matrix ? X_raw : Matrix(X_raw)
        inputs = get(exp, :inputs, Dict())
        
        # Compute numerical derivatives for this trajectory
        dX = compute_numerical_derivatives(t, X;
            method=ode_options.differentiation_method,
            window=ode_options.savitzky_golay_window,
            poly_order=ode_options.savitzky_golay_order
        )
        
        # Create feature matrix for this trajectory
        # Returns matrix where rows are features, columns are time points
        features = create_feature_matrix(t, X, inputs)
        
        push!(all_features_list, features)
        push!(all_derivatives_list, dX)
    end
    
    # Concatenate horizontally (along time axis)
    # Result: more columns = more time points from all trajectories
    combined_features = hcat(all_features_list...)  # (n_features × total_time_points)
    combined_derivatives = vcat(all_derivatives_list...)  # (total_time_points × n_states)
    
    return combined_features, combined_derivatives
end
