"""
differentiation.jl

Numerical differentiation and feature matrix construction.
"""

"""
    compute_numerical_derivatives(t::Vector, X::Matrix; method=:finite_difference,
                                 window=11, poly_order=2, tikhonov_lambda=1e-2)

Compute numerical derivatives of state variables.

# Arguments
- `t`: Time vector (length n_time)
- `X`: State matrix (n_time × n_states)
- `method`: Derivative computation method (:finite_difference, :savitzky_golay, :tikhonov,
            :tikhonov_regularizationtools, or :tikhonov_datainterpolations)
- `window`: Window size for Savitzky-Golay filter (must be odd, default: 11)
- `poly_order`: Polynomial order for Savitzky-Golay filter (default: 2)
- `tikhonov_lambda`: Smoothing strength for Tikhonov regularization (default: 1e-2)

# Returns
- `dX`: Derivative matrix (n_time × n_states)
"""
function compute_numerical_derivatives(t::Vector, X::Matrix; 
                                      method=:finite_difference,
                                      window=11, 
                                      poly_order=2,
                                      tikhonov_lambda=1e-2)
    n_time, n_states = size(X)
    dX = zeros(n_time, n_states)

    function finite_difference_1d(t::Vector, x::AbstractVector)
        n = length(t)
        dx = zeros(Float64, n)
        for j in 2:n-1
            dx[j] = (x[j+1] - x[j-1]) / (t[j+1] - t[j-1])
        end
        dx[1] = (x[2] - x[1]) / (t[2] - t[1])
        dx[end] = (x[end] - x[end-1]) / (t[end] - t[end-1])
        return dx
    end

    function tikhonov_smooth_regularizationtools_1d(x::AbstractVector, λ::Float64)
        n = length(x)
        if n < 3 || λ <= 0
            return Float64.(x)
        end

        Aop = zeros(Float64, n, n)
        for j in 1:n
            Aop[j, j] = 1.0
        end
        Ψ = RegularizationTools.setupRegularizationProblem(Aop, 2)
        b = Float64.(x)
        b̄ = RegularizationTools.to_standard_form(Ψ, b)
        x̄ = RegularizationTools.solve(Ψ, b̄, λ)
        return RegularizationTools.to_general_form(Ψ, b, x̄)
    end

    function tikhonov_datainterpolations_derivative_1d(t::Vector, x::AbstractVector, λ::Float64)
        n = length(t)
        if n < 3 || λ <= 0
            return finite_difference_1d(t, x)
        end

        t_vec = Float64.(t)
        x_vec = Float64.(x)
        reg = DataInterpolations.RegularizationSmooth(x_vec, t_vec, 2; λ=λ)
        return [DataInterpolations.derivative(reg, ti) for ti in t_vec]
    end
    
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
        elseif method == :tikhonov_regularizationtools
            x_smooth = tikhonov_smooth_regularizationtools_1d(X[:, i], Float64(tikhonov_lambda))
            dX[:, i] = finite_difference_1d(t, x_smooth)
        elseif method == :tikhonov_datainterpolations
            dX[:, i] = tikhonov_datainterpolations_derivative_1d(t, X[:, i], Float64(tikhonov_lambda))
        else
            error("Unknown differentiation method: $method. Use :finite_difference, :savitzky_golay, :tikhonov, :tikhonov_regularizationtools, or :tikhonov_datainterpolations")
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

        # ── Drop any time-point rows that contain NaN (ODE early-termination fill) ──
        valid_rows = findall(i -> !any(isnan, X[i, :]), 1:size(X, 1))
        if length(valid_rows) < size(X, 1)
            X = X[valid_rows, :]
            t = t[valid_rows]
            # Also slice input vectors if they are stored as vectors
            inputs = Dict(k => (v isa AbstractVector ? v[valid_rows] : v) for (k, v) in inputs)
        end

        # Need at least 3 points to compute derivatives
        if length(t) < 3
            continue
        end
        
        # Compute numerical derivatives for this trajectory
        dX = compute_numerical_derivatives(t, X;
            method=ode_options.differentiation_method,
            window=ode_options.savitzky_golay_window,
            poly_order=ode_options.savitzky_golay_order,
            tikhonov_lambda=ode_options.tikhonov_lambda
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
