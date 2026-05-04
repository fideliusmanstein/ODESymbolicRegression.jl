"""
integration_loss.jl

Integration-based loss evaluation for ODE systems.
Evaluates candidate equations by integrating and comparing to observations.
"""

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
                X_mat = X_raw isa Matrix ? X_raw : Matrix(X_raw)

                # ── Strip NaN rows from early-terminated ODE trajectories ──
                t_vec = normalized[:t]
                valid = findall(i -> !any(isnan, X_mat[i, :]), 1:size(X_mat, 1))
                if length(valid) < size(X_mat, 1)
                    X_mat  = X_mat[valid, :]
                    t_vec  = t_vec[valid]
                    # Also trim stored inputs
                    inputs_raw = get(traj, :inputs, Dict())
                    trimmed_inputs = Dict(k => (v isa AbstractVector ? v[valid] : v)
                                         for (k, v) in inputs_raw)
                    normalized[:t]      = t_vec
                    normalized[:inputs] = trimmed_inputs
                end
                normalized[:X_observed] = X_mat
                
                # Inputs (optional) — only set if not already set by NaN-strip block above
                if !haskey(normalized, :inputs)
                    normalized[:inputs] = get(traj, :inputs, Dict())
                end
                
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
                AutoTsit5(Rosenbrock23()),  # explicit solver — no Jacobian, thread-safe with DynamicExpressions
                saveat=t,
                maxiters=10^6,
                abstol=1e-3,
                reltol=1e-3,
                verbose=false
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

# =============================================================================
# Stage 2 Integration-Loss SR
# =============================================================================

"""
    _short_integration_loss(trees, loss_config, short_frac) -> Float64

Evaluate integration loss on a truncated prefix of each trajectory using a
cheap explicit solver (Tsit5, loose tolerances). Used as a fast screening gate
before the full accurate solve.
"""
function _short_integration_loss(trees, loss_config::IntegrationLoss, short_frac::Float64)
    total = 0.0
    valid = 0
    for trajectory in loss_config.trajectories
        t_full  = trajectory[:t]
        X_obs   = trajectory[:X_observed]
        inputs  = get(trajectory, :inputs, Dict())
        n_cut   = max(2, round(Int, short_frac * length(t_full)))
        t_short = t_full[1:n_cut]
        X_short = X_obs[1:n_cut, :]
        x0      = X_obs[1, :]
        tspan   = (t_short[1], t_short[end])
        input_interps = setup_input_interpolations(t_full, inputs)
        ode_fn  = create_ode_function(trees, input_interps)
        try
            prob = ODEProblem(ode_fn, x0, tspan)
            sol  = solve(prob, Tsit5();
                         saveat   = t_short,
                         maxiters = 10^5,
                         abstol   = 1e-2,
                         reltol   = 1e-2,
                         verbose  = false)
            if SciMLBase.successful_retcode(sol) && length(sol.u) == n_cut
                X_pred = hcat([sol.u[i] for i in 1:n_cut]...)'
                if all(isfinite, X_pred)
                    total += sum((X_pred .- X_short).^2) / length(X_pred)
                    valid += 1
                end
            end
        catch
            return Inf
        end
    end
    return valid > 0 ? total / valid : Inf
end

"""
    make_integration_loss_fn(fixed_trees, state_idx, loss_config, ode_options) -> Function

Return a SymbolicRegression.jl-compatible loss closure that evaluates each
candidate expression via ODE integration rather than derivative MSE.

The closure uses a three-phase evaluation strategy:
  Phase 0 — complexity gate: reject trees above `complexity_threshold` immediately.
  Phase 1 — short cheap solve: Tsit5 on the first `stage2_short_window_fraction`
             of the trajectory with loose tolerances; reject if MSE exceeds
             `stage2_short_loss_threshold`.
  Phase 2 — full accurate solve: AutoTsit5(Rosenbrock23) on the full trajectory.

# Arguments
- `fixed_trees`: current best expression trees for all states
- `state_idx`: which state's tree is being replaced by the candidate
- `loss_config`: IntegrationLoss holding the measurement trajectories
- `ode_options`: ODERegressionOptions (reads complexity_threshold,
  stage2_short_window_fraction, stage2_short_loss_threshold)
"""
function make_integration_loss_fn(
    fixed_trees::Vector,
    state_idx::Int,
    loss_config::IntegrationLoss,
    ode_options::ODERegressionOptions
)
    return function(tree, dataset, options)

        # Phase 0: complexity gate
        if compute_complexity(tree, options) > ode_options.complexity_threshold
            return Inf32
        end

        # Wrap tree: SymbolicRegression.jl passes its internal node type during
        # search; create_ode_function needs a callable Expression.
        wrapped = if tree isa SymbolicRegression.Expression
            tree
        else
            SymbolicRegression.Expression(tree;
                operators      = options.operators,
                variable_names = dataset.variable_names)
        end

        test_trees = copy(fixed_trees)
        test_trees[state_idx] = wrapped

        # Phase 1: short cheap solve
        short_loss = _short_integration_loss(
            test_trees, loss_config, ode_options.stage2_short_window_fraction
        )
        if short_loss >= ode_options.stage2_short_loss_threshold
            return Inf32
        end

        # Phase 2: full accurate solve
        full_loss = try
            evaluate_ode_system(test_trees, loss_config)
        catch
            Inf
        end

        return isfinite(full_loss) ? Float32(full_loss) : Inf32
    end
end
