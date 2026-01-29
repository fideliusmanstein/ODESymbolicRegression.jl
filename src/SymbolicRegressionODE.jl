"""
SymbolicRegressionODE.jl

Symbolic regression for discovering differential equations from time-series data.

This module implements a two-stage approach:
1. Derivative Estimation: Use symbolic regression to find dx/dt from numerical derivatives
2. Integration Refinement: Refine equations by solving ODEs and comparing integrated solutions

Compatible with benchmark problems from benchmarkProblems/BenchmarkSystems.jl
"""

module SymbolicRegressionODE

using DifferentialEquations
using SymbolicRegression
using Interpolations
using Logging
using SavitzkyGolay
using SymbolicUtils
using Symbolics

export ODERegressionOptions, discover_ode_system, IntegrationLoss, create_feature_matrix

# Internal normalization function for printing equations
# Uses the same simplification logic as benchmark normalization for consistency
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
    ODERegressionOptions

Configuration for ODE discovery through symbolic regression.

# Fields
- `binary_operators`: Binary operators for symbolic expressions (default: +, *, -, /)
- `unary_operators`: Unary operators for symbolic expressions (default: cos, sin, exp)
- `maxsize`: Maximum complexity of expressions (default: 20)
- `niterations_derivative`: Iterations for derivative search (default: 10)
- `niterations_integration`: Iterations for integration refinement (default: 5)
- `complexity_derivative`: Max complexity for derivative search (default: 15)
- `complexity_integration`: Max complexity for integration search (default: 10)
- `parallelism`: Parallelism mode (:serial, :multithreading, :multiprocessing)
- `differentiation_method`: Method for numerical derivatives (:finite_difference or :savitzky_golay)
- `savitzky_golay_window`: Window size for Savitzky-Golay filter (default: 11)
- `savitzky_golay_order`: Polynomial order for Savitzky-Golay filter (default: 2)
- `seed`: Random seed for reproducibility
- `verbose`: Enable verbose output
"""
struct ODERegressionOptions
    binary_operators::Tuple
    unary_operators::Tuple
    maxsize::Int
    niterations_derivative::Int
    niterations_integration::Int
    complexity_derivative::Int
    complexity_integration::Int
    parallelism::Symbol
    differentiation_method::Symbol
    savitzky_golay_window::Int
    savitzky_golay_order::Int
    seed::Int
    verbose::Bool
    
    function ODERegressionOptions(;
        binary_operators=(+, *, -, /),
        unary_operators=(cos, sin, exp),
        maxsize=20,
        niterations_derivative=10,
        niterations_integration=5,
        complexity_derivative=15,
        complexity_integration=10,
        parallelism=:multithreading,
        differentiation_method=:finite_difference,
        savitzky_golay_window=11,
        savitzky_golay_order=2,
        seed=42,
        verbose=true
    )
        @assert differentiation_method in [:finite_difference, :savitzky_golay] "differentiation_method must be :finite_difference or :savitzky_golay"
        @assert isodd(savitzky_golay_window) && savitzky_golay_window >= 3 "savitzky_golay_window must be odd and >= 3"
        @assert savitzky_golay_order >= 1 "savitzky_golay_order must be >= 1"
        new(binary_operators, unary_operators, maxsize, 
            niterations_derivative, niterations_integration,
            complexity_derivative, complexity_integration,
            parallelism, differentiation_method, savitzky_golay_window, 
            savitzky_golay_order, seed, verbose)
    end
end

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

"""
    discover_derivatives(experiments, ode_options)

Stage 1: Discover derivative equations using symbolic regression on numerical derivatives.
Now supports multiple trajectories for more robust derivative estimation.

# Arguments
- `experiments`: Vector of experiment dicts with keys :t, :X, :inputs
- `ode_options`: ODERegressionOptions

# Returns
- Vector of PopMember vectors (one per state), each containing candidate equations
"""
function discover_derivatives(experiments::Vector, ode_options::ODERegressionOptions)
    n_states = size(experiments[1][:X], 2)
    
    # Get combined data from all trajectories
    features, dX_all = aggregate_features_and_derivatives(experiments, ode_options)
    
    if ode_options.verbose
        println("="^80)
        println("Stage 1: Discovering Derivative Equations")
        println("="^80)
        println("Number of trajectories: ", length(experiments))
        println("Number of states: ", n_states)
        println("Combined feature dimensions: ", size(features))
        println()
    end
    
    # Configure SymbolicRegression options for derivative search
    sr_options = SymbolicRegression.Options(;
        binary_operators=ode_options.binary_operators,
        unary_operators=ode_options.unary_operators,
        maxsize=ode_options.complexity_derivative,
        seed=ode_options.seed
    )
    
    # Discover equations for each state
    derivative_candidates = Vector{Vector}(undef, n_states)
    
    for i in 1:n_states
        if ode_options.verbose
            println("\nSearching for dx$(i)/dt...")
        end
        
        # Target is derivative of state i (from ALL trajectories combined)
        target = dX_all[:, i]
        
        # Run symbolic regression on combined data
        if ode_options.verbose
            hall_of_fame = equation_search(
                features, target;
                options=sr_options,
                niterations=ode_options.niterations_derivative,
                parallelism=ode_options.parallelism
            )
        else
            hall_of_fame = with_logger(NullLogger()) do
                equation_search(
                    features, target;
                    options=sr_options,
                    niterations=ode_options.niterations_derivative,
                    parallelism=ode_options.parallelism
                )
            end
        end
        
        # Extract Pareto frontier
        pareto_frontier = calculate_pareto_frontier(hall_of_fame)
        derivative_candidates[i] = pareto_frontier
        
        if ode_options.verbose
            println("  Found ", length(pareto_frontier), " candidate equations")
        end
    end
    
    return derivative_candidates
end

"""
    IntegrationLoss

Loss function that evaluates candidate ODE systems by integrating them
and comparing to observed trajectories.

Can hold either a single trajectory or multiple trajectories for robust evaluation.
"""
struct IntegrationLoss
    trajectories::Vector{Dict}  # Each entry: Dict(:t, :X_observed, :inputs)
    
    # Constructor for multiple trajectories
    function IntegrationLoss(trajectories::Vector)
        # Convert to Vector{Dict} and normalize keys
        dict_trajectories = Dict[]
        for traj in trajectories
            if traj isa Dict
                # Normalize: ensure we have :t, :X_observed, :inputs
                normalized = Dict{Symbol,Any}()
                
                # Time vector
                normalized[:t] = traj[:t]
                
                # State matrix (handle :X or :X_observed)
                if haskey(traj, :X_observed)
                    X_raw = traj[:X_observed]
                elseif haskey(traj, :X)
                    X_raw = traj[:X]
                else
                    error("Trajectory must have :X or :X_observed key")
                end
                # Ensure it's a Matrix
                normalized[:X_observed] = X_raw isa Matrix ? X_raw : Matrix(X_raw)
                
                # Inputs (optional)
                normalized[:inputs] = get(traj, :inputs, Dict())
                
                push!(dict_trajectories, normalized)
            else
                error("Each trajectory must be a Dict with keys :t, :X (or :X_observed), :inputs")
            end
        end
        new(dict_trajectories)
    end
    
    # Convenience constructor for single trajectory (backward compatible)
    function IntegrationLoss(t::Vector, X_observed::AbstractMatrix, inputs::Dict=Dict())
        # Ensure X_observed is a Matrix (not Adjoint or other type)
        X_mat = X_observed isa Matrix ? X_observed : Matrix(X_observed)
        trajectories = [Dict(:t => t, :X_observed => X_mat, :inputs => inputs)]
        new(trajectories)
    end
end

"""
    evaluate_ode_system(trees, loss_config)

Evaluate a candidate ODE system by integrating and comparing to data.
Now supports multiple trajectories for robust evaluation.

# Arguments
- `trees`: Vector of expression trees, one per state (dx_i/dt = trees[i])
- `loss_config`: IntegrationLoss configuration (can contain multiple trajectories)

# Returns
- Loss value (mean squared error averaged across all trajectories)
"""
function evaluate_ode_system(trees::Vector, loss_config::IntegrationLoss)
    n_states = length(trees)
    n_trajectories = length(loss_config.trajectories)
    
    total_loss = 0.0
    valid_trajectories = 0
    
    # Evaluate on each trajectory
    for trajectory in loss_config.trajectories
        t = trajectory[:t]
        X_observed = trajectory[:X_observed]
        inputs = get(trajectory, :inputs, Dict())
        n_time = length(t)
        
        # Initial conditions for THIS trajectory
        x0 = X_observed[1, :]
        tspan = (t[1], t[end])
        
        # Create input interpolators for THIS trajectory
        input_interps = setup_input_interpolations(t, inputs)
        
        # Define ODE system dynamics using shared helper
        ode_dynamics! = create_ode_function(trees, input_interps)
        
        # Solve ODE system for this trajectory
        try
            prob = ODEProblem(ode_dynamics!, x0, tspan)
            sol = solve(
                prob,
                AutoTsit5(Rosenbrock23()),
                saveat=t,
                maxiters=5000,
                abstol=1e-3,
                reltol=1e-3
            )
            
            # Check if solution succeeded and has correct length
            if SciMLBase.successful_retcode(sol) && length(sol.u) == n_time
                # Convert solution to matrix
                X_predicted = hcat([sol.u[i] for i in 1:length(sol.u)]...)'
                
                # Check all predictions are finite
                if all(isfinite, X_predicted)
                    # Mean squared error for this trajectory
                    loss_traj = sum((X_predicted .- X_observed).^2) / length(X_predicted)
                    total_loss += loss_traj
                    valid_trajectories += 1
                end
            end
        catch e
            # Integration failed for this trajectory - continue to next
        end
    end
    
    # Return average loss over all valid trajectories
    if valid_trajectories > 0
        return total_loss / valid_trajectories
    else
        return Inf  # All trajectories failed
    end
end

"""
    refine_with_integration(derivative_candidates, experiments, ode_options)

Stage 2: Refine equations by testing combinations with integration-based loss,
then iteratively improving them together using symbolic regression.
Now supports multiple trajectories for robust evaluation.

# Arguments
- `derivative_candidates`: Vector of candidate equations per state
- `experiments`: Vector of experiment dicts with keys :t, :X, :inputs
- `ode_options`: ODERegressionOptions

# Returns
- Tuple of (best_trees, best_loss, best_indices)
"""
function refine_with_integration(
    derivative_candidates::Vector{Vector},
    experiments::Vector,
    ode_options::ODERegressionOptions
)
    n_states = length(derivative_candidates)
    
    if ode_options.verbose
        println("\n" * "="^80)
        println("Stage 2: Integration-Based Refinement")
        println("="^80)
        println("Number of trajectories to evaluate: ", length(experiments))
    end
    
    # Filter candidates by complexity
    filtered_candidates = Vector{Vector}(undef, n_states)
    sr_options = SymbolicRegression.Options(;
        binary_operators=ode_options.binary_operators,
        unary_operators=ode_options.unary_operators,
        maxsize=ode_options.complexity_integration
    )
    
    for i in 1:n_states
        filtered = filter(derivative_candidates[i]) do member
            compute_complexity(member, sr_options) <= ode_options.complexity_integration
        end
        filtered_candidates[i] = filtered
    end
    
    candidates_per_state = [length(fc) for fc in filtered_candidates]
    total_combinations = prod(candidates_per_state)
    
    if ode_options.verbose
        println("Candidates per state (complexity ≤ $(ode_options.complexity_integration)): ", candidates_per_state)
        println("Total combinations to test: ", total_combinations)
        println()
    end
    
    # Create loss configuration from ALL trajectories
    loss_config = IntegrationLoss(experiments)
    
    # =========================================================================
    # Step 1: Find best initial combination from candidates
    # =========================================================================
    if ode_options.verbose
        println("Step 1: Finding best initial combination...")
    end
    
    best_loss = Inf
    best_trees = nothing
    best_indices = nothing
    combinations_tested = 0
    
    # Recursive combination search
    function test_combinations(state_idx::Int, current_trees::Vector, current_indices::Vector{Int})
        if state_idx > n_states
            # Evaluate this combination
            combinations_tested += 1
            
            # Progress indicator
            if ode_options.verbose && combinations_tested % max(1, div(total_combinations, 10)) == 0
                progress_pct = round(100 * combinations_tested / total_combinations, digits=1)
                println("  Progress: $combinations_tested/$total_combinations ($progress_pct%)")
            end
            
            loss = evaluate_ode_system(current_trees, loss_config)
            
            if loss < best_loss
                best_loss = loss
                best_trees = copy(current_trees)
                best_indices = copy(current_indices)
            end
            return
        end
        
        # Try each candidate for current state
        for (i, candidate) in enumerate(filtered_candidates[state_idx])
            test_combinations(
                state_idx + 1,
                [current_trees; candidate.tree],
                [current_indices; i]
            )
        end
    end
    
    # Start search
    test_combinations(1, [], Int[])
    
    initial_loss = best_loss
    initial_trees = copy(best_trees)
    
    if ode_options.verbose
        println("  Initial best loss: ", round(initial_loss, sigdigits=4))
        println("\n  Initial equations (before refinement):")
        for (i, tree) in enumerate(initial_trees)
            println("    X$i' = ", normalize_equation_internal(tree, sr_options))
        end
    end
    
    # =========================================================================
    # Step 2: Iteratively refine equations together
    # =========================================================================
    if ode_options.niterations_integration > 0
        if ode_options.verbose
            println("\nStep 2: Integration-based refinement ($(ode_options.niterations_integration) iterations per equation)...")
            println("  Each equation will be refined using integration residuals")
        end
        
        # Refine each equation using integration residuals
        for state_idx in 1:n_states
            if ode_options.verbose
                println("\n  Refining equation $state_idx...")
            end
            
            # Get features and synthetic targets from current system's residuals
            features, synthetic_target = compute_integration_residuals(
                best_trees, state_idx, experiments, ode_options
            )
            
            if features === nothing || synthetic_target === nothing
                if ode_options.verbose
                    println("    Skipped (could not compute residuals)")
                end
                continue  # Skip if residuals can't be computed
            end
            
            # Run symbolic regression to improve this equation
            search_options = SymbolicRegression.Options(;
                binary_operators=ode_options.binary_operators,
                unary_operators=ode_options.unary_operators,
                maxsize=ode_options.complexity_integration,
                seed=ode_options.seed + state_idx
            )
            
            hof = with_logger(NullLogger()) do
                equation_search(
                    features, synthetic_target;
                    options=search_options,
                    niterations=ode_options.niterations_integration,
                    parallelism=ode_options.parallelism
                )
            end
            
            # Get best candidate and test if it improves the system
            pareto = calculate_pareto_frontier(hof)
            
            improved = false
            for candidate in pareto
                # Test with this candidate replacing current equation
                test_trees = copy(best_trees)
                test_trees[state_idx] = candidate.tree
                
                test_loss = evaluate_ode_system(test_trees, loss_config)
                
                if test_loss < best_loss
                    best_loss = test_loss
                    best_trees = test_trees
                    improved = true
                    if ode_options.verbose
                        improvement = round((initial_loss - best_loss) / initial_loss * 100, digits=1)
                        println("    ✓ Improved! Loss: $(round(best_loss, sigdigits=4)) ($improvement% better than initial)")
                    end
                    break  # Take first improvement
                end
            end
            
            if !improved && ode_options.verbose
                println("    No improvement found")
            end
        end
        
        if ode_options.verbose
            final_improvement = round((initial_loss - best_loss) / initial_loss * 100, digits=1)
            println("\n  Refinement complete!")
            println("    Initial loss: ", round(initial_loss, sigdigits=4))
            println("    Final loss: ", round(best_loss, sigdigits=4))
            println("    Improvement: $final_improvement%")
        end
    end
    
    # =========================================================================
    # Display final results
    # =========================================================================
    if ode_options.verbose
        println("\n" * "="^80)
        println("Best ODE System Found")
        println("="^80)
        
        for (i, tree) in enumerate(best_trees)
            println("\nState $i:")
            println("  dx$i/dt = ", normalize_equation_internal(tree, sr_options))
        end
        
        println("\n" * "="^80)
        println("Integration loss: ", round(best_loss, sigdigits=4))
        println("="^80)
    end
    
    return best_trees, best_loss, best_indices, initial_trees, initial_loss
end

"""
    compute_integration_residuals(trees, state_idx, experiments, ode_options)

Compute synthetic training targets for refining a specific equation.
This creates targets based on how well the current ODE system integrates.

# Arguments
- `trees`: Current equation trees for all states
- `state_idx`: Which state to compute residuals for
- `experiments`: Vector of experiment dictionaries
- `ode_options`: ODERegressionOptions

# Returns
- `(features, targets)`: Feature matrix and target vector for symbolic regression
"""
function compute_integration_residuals(
    trees::Vector,
    state_idx::Int,
    experiments::Vector,
    ode_options::ODERegressionOptions
)
    n_states = length(trees)
    
    # Collect data from all trajectories
    all_features = []
    all_targets = []
    
    for exp in experiments
        t = exp[:t]
        X_obs = exp[:X]
        inputs = get(exp, :inputs, Dict())
        
        # Integrate current system
        try
            # Setup input interpolations
            input_interps = setup_input_interpolations(t, inputs)
            
            # Create ODE problem
            x0 = X_obs[1, :]
            tspan = (t[1], t[end])
            
            ode_function = create_ode_function(trees, input_interps)
            prob = ODEProblem(ode_function, x0, tspan)
            
            # Solve ODE
            sol = solve(prob, Tsit5(); saveat=t, abstol=1e-6, reltol=1e-6)
            
            if sol.retcode != :Success
                continue
            end
            
            X_pred = hcat(sol.u...)'
            
            # Compute residuals for this state
            residuals = X_obs[:, state_idx] - X_pred[:, state_idx]
            
            # Compute numerical derivative of residuals
            # This tells us how to adjust dx/dt
            dResiduals = compute_numerical_derivatives(t, reshape(residuals, :, 1);
                method=ode_options.differentiation_method)[:, 1]
            
            # Create features at each time point
            for i in 1:length(t)
                # Features are just states (no time)
                feature_vec = X_pred[i, :]
                
                # Add inputs
                if !isempty(input_interps)
                    for key in sort(collect(keys(input_interps)))
                        push!(feature_vec, input_interps[key](t[i]))
                    end
                end
                
                push!(all_features, feature_vec)
                
                # Target: current dx/dt prediction + correction from residuals
                current_dxdt = trees[state_idx](reshape(feature_vec, :, 1))[1]
                push!(all_targets, current_dxdt + dResiduals[i])
            end
            
        catch e
            # Skip this trajectory if integration fails
            continue
        end
    end
    
    if isempty(all_features)
        return nothing, nothing
    end
    
    # Convert to matrices
    features = hcat(all_features...)'  # (n_samples × n_features)
    features = features'  # Transpose to (n_features × n_samples) for equation_search
    targets = Vector{Float64}(all_targets)
    
    return features, targets
end

"""
    create_ode_function(trees, input_interps)

Create an ODE function from equation trees and input interpolations.
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

"""
    setup_input_interpolations(t, inputs)

Create interpolation functions for time-varying inputs.
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
    discover_ode_system(experiments; ode_options=ODERegressionOptions())

Main function: Discover ODE system from experimental time-series data.
Now supports multiple trajectories for robust ODE discovery.

# Arguments
- `experiments`: Vector of experiment dictionaries from benchmark problems.
                 Each experiment should have keys: `:t`, `:X`, `:inputs`
- `ode_options`: Configuration options (default: ODERegressionOptions())

# Returns
- Named tuple with:
  - `derivative_candidates`: All candidates from Stage 1
  - `best_trees`: Best equation trees from Stage 2
  - `integration_loss`: Integration-based loss (averaged across all trajectories)
  - `best_indices`: Indices of selected candidates

# Example
```julia
include("benchmarkProblems/BenchmarkSystems.jl")
using .BenchmarkSystems

# Load a benchmark problem (single trajectory)
experiments = BenchmarkSystems.load_problem("simpleLin1")

# Or load with multiple trajectories for better results
# experiments = BenchmarkSystems.load_problem("simpleLin1", num_trajectories=3)

# Discover ODE system
result = discover_ode_system(experiments)

# Access results
println("Best equations: ", result.best_trees)
println("Integration loss: ", result.integration_loss)
```
"""
function discover_ode_system(
    experiments::Vector;
    ode_options::ODERegressionOptions = ODERegressionOptions()
)
    # Validate experiments
    if isempty(experiments)
        error("Must provide at least one experiment")
    end
    
    # Validate all have same state dimensions
    n_states_first = size(experiments[1][:X], 2)
    for i in 2:length(experiments)
        n_states_i = size(experiments[i][:X], 2)
        if n_states_i != n_states_first
            error("All experiments must have same number of states. " *
                  "Experiment 1 has $n_states_first states, experiment $i has $n_states_i states.")
        end
    end
    
    if ode_options.verbose
        println("\n" * "="^80)
        println("Symbolic Regression for Differential Equations")
        println("="^80)
        println("Number of experiments/trajectories: ", length(experiments))
        println("States per experiment: ", n_states_first)
        for (i, exp) in enumerate(experiments)
            println("  Experiment $i: $(length(exp[:t])) time points, " *
                   "$(length(get(exp, :inputs, Dict()))) inputs")
        end
        println()
    end
    
    # Stage 1: Discover derivatives using ALL trajectories
    derivative_candidates = discover_derivatives(experiments, ode_options)
    
    # Stage 2: Refine with integration-based loss using ALL trajectories
    best_trees, integration_loss, best_indices, initial_trees, initial_loss = refine_with_integration(
        derivative_candidates, experiments, ode_options
    )
    
    return (
        derivative_candidates = derivative_candidates,
        best_trees = best_trees,
        integration_loss = integration_loss,
        best_indices = best_indices,
        initial_trees = initial_trees,
        initial_loss = initial_loss
    )
end

end # module
