"""
discovery.jl

Main ODE discovery orchestration.
Coordinates the two-stage discovery process.
"""

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
  - `initial_trees`: Initial equation trees before refinement
  - `initial_loss`: Initial loss before refinement

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
    
    t_total_start = time()

    # Stage 1: Discover derivatives using ALL trajectories
    t_stage1_start = time()
    derivative_candidates = discover_derivatives(experiments, ode_options)
    time_stage1 = time() - t_stage1_start

    # Stage 2: Refine with integration-based loss using ALL trajectories
    best_trees, integration_loss, best_indices, initial_trees, initial_loss,
        time_combination_search, time_stage2_sr = refine_with_integration(
        derivative_candidates, experiments, ode_options
    )

    time_total = time() - t_total_start

    if ode_options.verbose
        println("\nTotal wall time: ", round(time_total, digits=2), "s",
                "  (stage 1: ", round(time_stage1, digits=2), "s",
                "  combination search: ", round(time_combination_search, digits=2), "s",
                "  stage 2 SR: ", round(time_stage2_sr, digits=2), "s)")
    end

    return (
        derivative_candidates    = derivative_candidates,
        best_trees               = best_trees,
        integration_loss         = integration_loss,
        best_indices             = best_indices,
        initial_trees            = initial_trees,
        initial_loss             = initial_loss,
        time_total               = time_total,
        time_stage1              = time_stage1,
        time_combination_search  = time_combination_search,
        time_stage2_sr           = time_stage2_sr,
    )
end
