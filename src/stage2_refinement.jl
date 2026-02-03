"""
stage2_refinement.jl

Stage 2: Integration-based refinement.
Tests combinations of candidate equations and refines them using integration residuals.
"""

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
- Tuple of (best_trees, best_loss, best_indices, initial_trees, initial_loss)
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
