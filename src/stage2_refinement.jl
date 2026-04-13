"""
stage2_refinement.jl

Stage 2: Integration-based refinement.
Tests combinations of candidate equations and refines them using real measured data
with integration loss for candidate selection.
"""

# =============================================================================
# Helper Functions
# =============================================================================

using Distributed

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
    select_knee_point(candidates, sr_options) -> index

Select the knee-point candidate from a Pareto frontier using maximum perpendicular distance
from the line connecting the lowest-complexity and lowest-loss endpoints.

Normalises both complexity and loss to [0, 1] before computing distances so that
the two axes are on a comparable scale.  Falls back to the median-complexity
candidate when the frontier is too small to have a meaningful knee.
"""
function select_knee_point(candidates::Vector, sr_options)
    n = length(candidates)
    if n == 1
        return 1
    end
    if n == 2
        return 1   # prefer simpler when only two options
    end

    complexities = Float64[compute_complexity(c, sr_options) for c in candidates]
    losses       = Float64[c.loss for c in candidates]

    # Normalise to [0, 1]; guard against constant axes
    c_min, c_max = extrema(complexities)
    l_min, l_max = extrema(losses)
    c_range = c_max - c_min
    l_range = l_max - l_min

    if c_range == 0 && l_range == 0
        return 1
    end

    nc = c_range == 0 ? zeros(n) : (complexities .- c_min) ./ c_range
    nl = l_range == 0 ? zeros(n) : (losses       .- l_min) ./ l_range

    # Line from point[1] to point[n] in normalised space
    x1, y1 = nc[1], nl[1]
    x2, y2 = nc[n], nl[n]
    dx, dy  = x2 - x1, y2 - y1
    line_len = sqrt(dx^2 + dy^2)

    if line_len == 0
        return 1
    end

    # Perpendicular distance of each point from the line
    best_idx  = 1
    best_dist = -Inf
    for i in 1:n
        dist = abs(dy * nc[i] - dx * nl[i] + x2 * y1 - y2 * x1) / line_len
        if dist > best_dist
            best_dist = dist
            best_idx  = i
        end
    end
    return best_idx
end

"""
    find_initial_by_knee_point(filtered_candidates, sr_options, loss_config, verbose) -> (best_trees, best_loss, best_indices)

Select one candidate per state independently using knee-point detection on each
state's Pareto frontier, then evaluate the resulting single combination via
integration loss.  Runs in O(n_states) ODE solves instead of the full
combinatorial product.
"""
function find_initial_by_knee_point(
    filtered_candidates::Vector{Vector},
    sr_options,
    loss_config::IntegrationLoss,
    verbose::Bool
)
    if any(length(fc) == 0 for fc in filtered_candidates)
        return nothing, Inf, nothing
    end

    n_states  = length(filtered_candidates)
    indices   = Vector{Int}(undef, n_states)
    trees     = Vector{Any}(undef, n_states)

    for s in 1:n_states
        idx        = select_knee_point(filtered_candidates[s], sr_options)
        indices[s] = idx
        trees[s]   = filtered_candidates[s][idx].tree
        if verbose
            c = compute_complexity(filtered_candidates[s][idx], sr_options)
            l = round(filtered_candidates[s][idx].loss, sigdigits=4)
            println("  State $s knee-point: candidate $idx/$(length(filtered_candidates[s])) (complexity=$c, derivative_loss=$l)")
        end
    end

    loss = try
        evaluate_ode_system(trees, loss_config)
    catch
        Inf
    end

    return trees, loss, indices
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
    
    # Handle edge cases up front
    if any(length(fc) == 0 for fc in filtered_candidates)
        return nothing, Inf, nothing
    end

    # Helper: convert linear index -> mixed-radix indices (1-based)
    function linear_to_indices!(lin::Int, lengths::Vector{Int}, out::Vector{Int})
        rem = lin - 1
        for s in 1:length(out)
            base = lengths[s]
            out[s] = (rem % base) + 1
            rem ÷= base
        end
        return out
    end

    # Helper: build trees vector from indices
    function build_trees_from_indices!(filtered, indices::Vector{Int}, out::Vector{Any})
        for s in 1:length(indices)
            out[s] = filtered[s][indices[s]].tree
        end
        return out
    end

    # Threaded low-memory scan: each thread keeps a local best
    function threaded_scan(filtered, loss_cfg, total_combinations, verbose)
        nstates = length(filtered)
        lengths = [length(fc) for fc in filtered]
        nthreads = Base.Threads.nthreads()

        local_best_loss = fill(Inf, nthreads)
        local_best_indices = Vector{Vector{Int}}(undef, nthreads)
        local_best_trees = Vector{Vector{Any}}(undef, nthreads)

        comb_counter = Base.Threads.Atomic{Int}(0)
        progress_step = max(1, div(total_combinations, 10))
        global_best_loss = Base.Threads.Atomic{Float64}(Inf)

        Base.Threads.@threads for lin in 1:total_combinations
            try
                tid = Base.Threads.threadid()
                idx_buf = Vector{Int}(undef, nstates)
                tree_buf = Vector{Any}(undef, nstates)
                linear_to_indices!(lin, lengths, idx_buf)
                build_trees_from_indices!(filtered, idx_buf, tree_buf)

                loss = try
                    evaluate_ode_system(tree_buf, loss_cfg)
                catch e
                    if verbose
                        @warn "evaluate_ode_system failed in threaded scan" thread=tid lin=lin error=string(e)
                    end
                    Inf
                end

                if loss < local_best_loss[tid]
                    local_best_loss[tid] = loss
                    local_best_indices[tid] = copy(idx_buf)
                    local_best_trees[tid] = copy(tree_buf)
                    # update global best atomically (compare-and-swap loop)
                    old = global_best_loss[]
                    while loss < old
                        prev = Base.Threads.atomic_cas!(global_best_loss, old, loss)
                        prev == old && break  # swap succeeded
                        old = prev            # retry with updated value
                    end
                end

                if verbose
                    curr = Base.Threads.atomic_add!(comb_counter, 1) + 1
                    if curr % progress_step == 0
                        progress_pct = round(100 * curr / total_combinations, digits=1)
                        current_best = global_best_loss[]
                        best_str = isfinite(current_best) ? string(round(current_best, sigdigits=4)) : "Inf"
                        println("  Progress: $curr/$total_combinations ($progress_pct%) | best loss so far: $best_str")
                    end
                end
            catch e
                # Catch any unexpected error in thread iteration to avoid Task failure
                if verbose
                    @warn "Unexpected error in threaded_scan iteration" lin=lin error=string(e)
                end
                # treat as failed evaluation
            end
        end

        # Reduce to global best
        gbest_loss = Inf
        gbest_indices = nothing
        gbest_trees = nothing
        for tid in 1:nthreads
            l = local_best_loss[tid]
            if l < gbest_loss
                gbest_loss = l
                gbest_indices = local_best_indices[tid]
                gbest_trees = local_best_trees[tid]
            end
        end
        return gbest_trees, gbest_loss, gbest_indices
    end

    # Single-threaded odometer scan (keeps previous semantics)
    function singlethread_scan(filtered, loss_cfg, verbose)
        nstates = length(filtered)
        indices = ones(Int, nstates)
        tested = 0
        best_l = Inf
        best_t = nothing
        best_idx = nothing

        while true
            tested += 1
            if verbose && tested % max(1, div(total_combinations, 10)) == 0
                progress_pct = round(100 * tested / total_combinations, digits=1)
                best_str = isfinite(best_l) ? string(round(best_l, sigdigits=4)) : "Inf"
                println("  Progress: $tested/$total_combinations ($progress_pct%) | best loss so far: $best_str")
            end

            cur_trees = Vector{Any}(undef, nstates)
            build_trees_from_indices!(filtered, indices, cur_trees)

            loss = evaluate_ode_system(cur_trees, loss_cfg)
            if loss < best_l
                best_l = loss
                best_t = copy(cur_trees)
                best_idx = copy(indices)
            end

            # increment
            carry = 1
            for s in 1:nstates
                if carry == 0
                    break
                end
                indices[s] += 1
                if indices[s] > length(filtered[s])
                    indices[s] = 1
                    carry = 1
                else
                    carry = 0
                end
            end
            if carry == 1 && all(indices .== 1)
                break
            end
        end
        return best_t, best_l, best_idx
    end

    # Choose threaded or single-threaded implementation
    if Base.Threads.nthreads() > 1 && total_combinations > 1
        return threaded_scan(filtered_candidates, loss_config, total_combinations, verbose)
    else
        return singlethread_scan(filtered_candidates, loss_config, verbose)
    end
end

"""
    iteratively_refine_equations(initial_trees, experiments, ode_options, loss_config, verbose) -> (best_trees, best_loss)

Refine each equation iteratively using real measured data and integration loss evaluation.
"""
function iteratively_refine_equations(
    initial_trees::Union{Vector, Nothing},
    experiments::Vector,
    ode_options::ODERegressionOptions,
    loss_config::IntegrationLoss,
    verbose::Bool
)
    if initial_trees === nothing
        return nothing, Inf
    end
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
        counts = [length(fc) for fc in filtered_candidates]
        println("Candidates per state: ", join(counts, ", "))
        println("Combination method: $(ode_options.combination_method)")
        if ode_options.combination_method == :combination_search
            total_combos = prod(counts)
            println("Total combinations to evaluate: $total_combos")
        end
        println("Finding best initial combination...")
    end

    if ode_options.combination_method == :knee_point
        initial_trees, initial_loss, best_indices = find_initial_by_knee_point(
            filtered_candidates, sr_options, loss_config, verbose
        )
    else
        initial_trees, initial_loss, best_indices = find_best_initial_combination(
            filtered_candidates, loss_config, verbose
        )
    end
    
    if verbose
        println("  Initial loss: ", round(initial_loss, sigdigits=4))
    end
    
    # Iteratively refine equations if requested
    if ode_options.niterations_integration > 0 && initial_trees !== nothing
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
        if best_trees !== nothing
            for (i, tree) in enumerate(best_trees)
                println("  dx$i/dt = ", normalize_equation_internal(tree, sr_options))
            end
        else
            println("  ⚠ No valid equations found (all combinations had infinite integration loss)")
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
                method=ode_options.differentiation_method,
                window=ode_options.savitzky_golay_window,
                poly_order=ode_options.savitzky_golay_order,
                tikhonov_lambda=ode_options.tikhonov_lambda)
            
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
    loss_config::IntegrationLoss,
    ode_options::ODERegressionOptions
)
    best_tree = nothing
    best_loss = Inf

    n_candidates = length(pareto_frontier)
    if n_candidates == 0
        return nothing, Inf
    end

    # Delegate to specialized implementations depending on requested parallelism
    if ode_options.parallelism == :multithreading && Threads.nthreads() > 1
        return select_best_candidate_multithread(pareto_frontier, trees, state_idx, loss_config)
    elseif ode_options.parallelism == :multiprocessing && nprocs() > 1
        try
            return select_best_candidate_multiprocess(pareto_frontier, trees, state_idx, loss_config)
        catch _
            # If multiprocessing fails (e.g. non-serializable trees), fall back to serial
        end
    end

    # Default: serial evaluation
    return select_best_candidate_serial(pareto_frontier, trees, state_idx, loss_config)
end


# -------------------------
# Specialized implementations
# -------------------------
function select_best_candidate_multithread(
    pareto_frontier::Vector,
    trees::Vector,
    state_idx::Int,
    loss_config::IntegrationLoss
)
    n = length(pareto_frontier)
    if n == 0
        return nothing, Inf
    end

    losses = fill(Inf, n)
    Base.Threads.@threads for j in 1:n
        try
            cand = pareto_frontier[j]
            test_trees = copy(trees)
            test_trees[state_idx] = cand.tree
            losses[j] = try
                evaluate_ode_system(test_trees, loss_config)
            catch e
                if Threads.nthreads() > 1
                    @warn "evaluate_ode_system failed in select_best_candidate_multithread" thread=Threads.threadid() idx=j error=string(e)
                end
                Inf
            end
        catch e
            if Threads.nthreads() > 1
                @warn "Unexpected error in multithread candidate loop" thread=Threads.threadid() idx=j error=string(e)
            end
            losses[j] = Inf
        end
    end

    idx = findmin(losses)[2]
    return pareto_frontier[idx].tree, losses[idx]
end

function select_best_candidate_multiprocess(
    pareto_frontier::Vector,
    trees::Vector,
    state_idx::Int,
    loss_config::IntegrationLoss
)
    n = length(pareto_frontier)
    if n == 0
        return nothing, Inf
    end

    # pmap will throw if closure or data are not serializable; let caller handle fallback
    losses = pmap(cand -> begin
        test_trees = copy(trees)
        test_trees[state_idx] = cand.tree
        evaluate_ode_system(test_trees, loss_config)
    end, pareto_frontier)

    idx = findmin(losses)[2]
    return pareto_frontier[idx].tree, losses[idx]
end

function select_best_candidate_serial(
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
    return select_best_candidate_by_integration_loss(pareto_frontier, trees, state_idx, loss_config, ode_options)
end
