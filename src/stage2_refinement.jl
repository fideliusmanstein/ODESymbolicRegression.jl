"""
stage2_refinement.jl

Stage 2: Integration-based refinement.
Tests combinations of candidate equations and refines them using real measured data
with integration loss for candidate selection.
"""

# =============================================================================
# Helper Functions
# =============================================================================

"""
    filter_candidates_by_complexity(derivative_candidates, ode_options) -> (filtered_candidates, sr_options)

Filter candidate equations by maximum allowed complexity.
"""
function filter_candidates_by_complexity(derivative_candidates::Vector{Vector}, ode_options::ODERegressionOptions)
    n_states = length(derivative_candidates)
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
    
    return filtered_candidates, sr_options
end

"""
    find_best_initial_combination(filtered_candidates, loss_config, verbose) -> (best_trees, best_loss, best_indices)

Search through all combinations of candidate equations to find the one with lowest integration loss.
"""
function find_best_initial_combination(
    filtered_candidates::Vector{Vector},
    loss_config::IntegrationLoss,
    verbose::Bool
)
    n_states = length(filtered_candidates)
    best_loss = Inf
    best_trees = nothing
    best_indices = nothing
    
    total_combinations = prod([length(fc) for fc in filtered_candidates])
    combinations_tested = 0
    
    # Recursive function to test all combinations
    function test_combinations(state_idx::Int, current_trees::Vector, current_indices::Vector{Int})
        if state_idx > n_states
            combinations_tested += 1
            
            # Progress indicator (every 10%)
            if verbose && combinations_tested % max(1, div(total_combinations, 10)) == 0
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
    
    test_combinations(1, [], Int[])
    
    return best_trees, best_loss, best_indices
end

"""
    iteratively_refine_equations(initial_trees, experiments, ode_options, loss_config, verbose) -> (best_trees, best_loss)

Refine each equation iteratively using real measured data and integration loss evaluation.
"""
function iteratively_refine_equations(
    initial_trees::Vector,
    experiments::Vector,
    ode_options::ODERegressionOptions,
    loss_config::IntegrationLoss,
    verbose::Bool
)
    best_trees = copy(initial_trees)
    best_loss = evaluate_ode_system(best_trees, loss_config)
    n_states = length(best_trees)
    
    for state_idx in 1:n_states
        new_tree, improved_loss = refine_single_equation(
            best_trees, state_idx, experiments, ode_options, loss_config
        )
        
        if new_tree !== nothing && improved_loss < best_loss
            best_trees = copy(best_trees)
            best_trees[state_idx] = new_tree
            best_loss = improved_loss
            
            if verbose
                println("  ✓ State $state_idx improved: loss = $(round(best_loss, sigdigits=4))")
            end
        end
    end
    
    return best_trees, best_loss
end

# =============================================================================
# Main Function
# =============================================================================

"""
    refine_with_integration(derivative_candidates, experiments, ode_options)

Stage 2: Refine equations by testing combinations with integration-based loss,
then iteratively improving them using symbolic regression on real measured data.

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
    verbose = ode_options.verbose
    
    if verbose
        println("\n" * "="^80)
        println("Stage 2: Integration-Based Refinement")
        println("="^80)
    end
    
    # Filter candidates and create symbolic regression options
    filtered_candidates, sr_options = filter_candidates_by_complexity(derivative_candidates, ode_options)
    loss_config = IntegrationLoss(experiments)
    
    # Find best initial combination from candidates
    if verbose
        println("Finding best initial combination...")
    end
    
    initial_trees, initial_loss, best_indices = find_best_initial_combination(
        filtered_candidates, loss_config, verbose
    )
    
    if verbose
        println("  Initial loss: ", round(initial_loss, sigdigits=4))
    end
    
    # Iteratively refine equations if requested
    if ode_options.niterations_integration > 0
        if verbose
            println("\nRefining equations with real measured data...")
        end
        
        best_trees, best_loss = iteratively_refine_equations(
            initial_trees, experiments, ode_options, loss_config, verbose
        )
        
        if verbose
            improvement = round((initial_loss - best_loss) / initial_loss * 100, digits=1)
            println("  Final loss: $(round(best_loss, sigdigits=4)) ($improvement% improvement)")
        end
    else
        best_trees = initial_trees
        best_loss = initial_loss
    end
    
    if verbose
        println("\n" * "="^80)
        println("Best ODE System:")
        for (i, tree) in enumerate(best_trees)
            println("  dx$i/dt = ", normalize_equation_internal(tree, sr_options))
        end
        println("Integration loss: ", round(best_loss, sigdigits=4))
        println("="^80)
    end
    
    return best_trees, best_loss, best_indices, initial_trees, initial_loss
end


# =============================================================================
# Equation Refinement Functions
# =============================================================================

"""
    extract_training_data_from_experiments(experiments, state_idx, ode_options) -> (features, targets)

Extract feature matrix and target vector from real experimental observations.
Features are observed states, targets are numerical derivatives.
"""
function extract_training_data_from_experiments(
    experiments::Vector,
    state_idx::Int,
    ode_options::ODERegressionOptions
)
    all_features = []
    all_targets = []
    
    for exp in experiments
        t = exp[:t]
        X_obs = exp[:X]
        inputs = get(exp, :inputs, Dict())
        
        try
            input_interps = setup_input_interpolations(t, inputs)
            dX_obs = compute_numerical_derivatives(t, X_obs; 
                method=ode_options.differentiation_method)
            
            for i in 1:length(t)
                # Build feature vector: states + inputs
                feature_vec = X_obs[i, :]
                if !isempty(input_interps)
                    for key in sort(collect(keys(input_interps)))
                        push!(feature_vec, input_interps[key](t[i]))
                    end
                end
                
                push!(all_features, feature_vec)
                push!(all_targets, dX_obs[i, state_idx])
            end
        catch
            continue  # Skip trajectory if computation fails
        end
    end
    
    if isempty(all_features)
        return nothing, nothing
    end
    
    # Convert to format expected by equation_search
    features = hcat(all_features...)'  # (n_samples × n_features)
    features = features'  # Transpose to (n_features × n_samples)
    targets = Vector{Float64}(all_targets)
    
    return features, targets
end

"""
    run_symbolic_regression(features, targets, ode_options, state_idx) -> pareto_frontier

Run symbolic regression search and return Pareto frontier of candidate equations.
"""
function run_symbolic_regression(
    features::AbstractMatrix,
    targets::Vector,
    ode_options::ODERegressionOptions,
    state_idx::Int
)
    search_options = SymbolicRegression.Options(;
        binary_operators=ode_options.binary_operators,
        unary_operators=ode_options.unary_operators,
        maxsize=ode_options.complexity_integration,
        seed=ode_options.seed + state_idx
    )
    
    hof = with_logger(NullLogger()) do
        equation_search(
            features, targets;
            options=search_options,
            niterations=ode_options.niterations_integration,
            parallelism=ode_options.parallelism
        )
    end
    
    return calculate_pareto_frontier(hof)
end

"""
    select_best_candidate_by_integration_loss(pareto_frontier, trees, state_idx, loss_config) -> (best_tree, best_loss)

Evaluate all Pareto frontier candidates by integration loss and return the best one.
"""
function select_best_candidate_by_integration_loss(
    pareto_frontier::Vector,
    trees::Vector,
    state_idx::Int,
    loss_config::IntegrationLoss
)
    best_tree = nothing
    best_loss = Inf
    
    for candidate in pareto_frontier
        test_trees = copy(trees)
        test_trees[state_idx] = candidate.tree
        test_loss = evaluate_ode_system(test_trees, loss_config)
        
        if test_loss < best_loss
            best_loss = test_loss
            best_tree = candidate.tree
        end
    end
    
    return best_tree, best_loss
end

"""
    refine_single_equation(trees, state_idx, experiments, ode_options, loss_config) -> (best_tree, best_loss)

Refine a single equation using real measured data and integration loss evaluation.
Returns the best refined tree and its integration loss, or (nothing, Inf) if refinement fails.
"""
function refine_single_equation(
    trees::Vector,
    state_idx::Int,
    experiments::Vector,
    ode_options::ODERegressionOptions,
    loss_config::IntegrationLoss
)
    # Extract training data from real observations
    features, targets = extract_training_data_from_experiments(experiments, state_idx, ode_options)
    
    if features === nothing || targets === nothing
        return nothing, Inf
    end
    
    # Run symbolic regression on real data
    pareto_frontier = run_symbolic_regression(features, targets, ode_options, state_idx)
    
    # Select best candidate by integration loss
    return select_best_candidate_by_integration_loss(pareto_frontier, trees, state_idx, loss_config)
end
