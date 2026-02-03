"""
stage1_derivatives.jl

Stage 1: Derivative-based symbolic regression.
Discovers candidate equations by fitting symbolic expressions to numerical derivatives.
"""

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
