# Symbolic Regression for ODE Discovery

This module implements a two-stage approach for discovering differential equations from time-series data using symbolic regression.

## Overview

The method combines:
1. **Derivative Estimation**: Symbolic regression on numerical derivatives to find candidate dx/dt equations
2. **Integration Refinement**: Testing candidate combinations by solving ODEs and comparing integrated trajectories

## Files

- `SymbolicRegressionODE.jl` - Main module implementing the ODE discovery algorithm
- `example_ode_discovery.jl` - Example scripts showing usage with benchmark problems
- `example_savitzky_golay.jl` - Example comparing differentiation methods
- `benchmark_ode_discovery.jl` - Comprehensive benchmarking framework
- `run_benchmark.jl` - Script to run benchmarks
- `benchmarkProblems/BenchmarkSystems.jl` - 63 benchmark ODE systems for testing

## Quick Start

```julia
include("SymbolicRegressionODE.jl")
include("benchmarkProblems/BenchmarkSystems.jl")

using .SymbolicRegressionODE
using .BenchmarkSystems
using SymbolicRegression

# Load a benchmark problem
experiments = BenchmarkSystems.load_problem("simpleLin1")

# Configure options
options = ODERegressionOptions(
    niterations_derivative=20,   # Iterations for Stage 1
    niterations_integration=10,  # Iterations for Stage 2
    complexity_derivative=15,    # Max complexity in Stage 1
    complexity_integration=10,   # Max complexity in Stage 2
    parallelism=:multithreading,
    verbose=true
)

# Discover ODE system
result = discover_ode_system(experiments; ode_options=options)

# Display results
println("Integration loss: ", result.integration_loss)

# Create SR Options for string_tree (needs binary/unary operators)
sr_opts = SymbolicRegression.Options(
    binary_operators=options.binary_operators,
    unary_operators=options.unary_operators
)
for (i, tree) in enumerate(result.best_trees)
    println("dx$i/dt = ", string_tree(tree, sr_opts))
end
```

## Two-Stage Algorithm

### Stage 1: Derivative Estimation

1. Compute numerical derivatives using finite differences
2. Create feature matrix: `[t, x1, x2, ..., u1, u2, ...]`
3. For each state variable `xi`:
   - Run symbolic regression: `dxi/dt ≈ f(t, x1, x2, ..., u1, u2, ...)`
   - Extract Pareto frontier of candidate equations
4. Output: Multiple candidate equations per state variable

### Stage 2: Integration Refinement

1. Filter candidates by complexity threshold
2. Test all combinations of candidates across states
3. For each combination:
   - Construct ODE system: `dx/dt = [f1(t,x,u), f2(t,x,u), ...]`
   - Integrate from initial conditions
   - Compare integrated trajectory to observed data
4. Select combination with best integration loss
5. Output: Final ODE system

## Configuration Options

```julia
ODERegressionOptions(
    binary_operators=(+, *, -, /),     # Binary operators
    unary_operators=(cos, sin, exp),   # Unary operators
    maxsize=20,                        # Overall max complexity
    niterations_derivative=10,         # Stage 1 iterations
    niterations_integration=5,         # Stage 2 iterations
    complexity_derivative=15,          # Stage 1 max complexity
    complexity_integration=10,         # Stage 2 max complexity
    parallelism=:multithreading,       # Parallelism mode
    differentiation_method=:finite_difference,  # :finite_difference or :savitzky_golay
    savitzky_golay_window=11,          # Window size for S-G filter (must be odd)
    savitzky_golay_order=2,            # Polynomial order for S-G filter
    seed=42,                           # Random seed
    verbose=true                       # Verbose output
)
```

### Differentiation Methods

- **`:finite_difference`** (default): Simple central/forward/backward differences
  - Fast and works well for clean data
  - May be sensitive to noise
  
- **`:savitzky_golay`**: Savitzky-Golay filter
  - Smooths derivatives, better for noisy data
  - Requires uniform time spacing
  - Configure with `savitzky_golay_window` (must be odd, ≥3) and `savitzky_golay_order` (≥1)

## Benchmark Problems

The system includes 63 benchmark ODE systems from the Chalmers database:

### Chemical Rate Equations (19 problems)
- `simpleLin1/2`: Linear system with inputs
- `simpleFb1-8`: Feedback systems
- `osc1-3`: Oscillator systems
- `metabol1/2`: Metabolic pathways
- `threeGenes1-3`: Gene regulatory networks
- `feedf1/2`, `inhosc1/2`, `bifeedb1/2`: Various chemical kinetics

### S-System Problems (28 problems)
- `ss_cascade1-3`: Cascade networks (3 states)
- `ss_branch1-6`: Branch networks (4 states)
- `ss_5genes1-8`: 5-gene regulatory networks
- `ss_15genes1-2`: 15-gene networks
- `ss_30genes1-3`: 30-gene large-scale networks
- `ss_feedf1-2`, `ss_inhosc1-2`, `ss_bifeedb1-2`: S-system versions

### GMA Problems (6 problems)
- `gma_feedf1-2`: Generalized Mass Action - feedforward
- `gma_inhosc1-2`: GMA - inhibitory oscillator
- `gma_bifeedb1-2`: GMA - bifurcation feedback

### Real Biological Problems (10 problems)
- `cytokine1-2`: Cytokine signaling pathway
- `ss_ethanolferm1-2`: Ethanol fermentation
- `ss_sosrepair1-2`: SOS DNA repair
- `ss_cadBA1-2`: Cadmium stress response
- `ss_clock1-2`: Circadian clock

## Data Format

Experiments returned by benchmark problems have this structure:

```julia
experiment = Dict(
    :t => [0.0, 0.1, 0.2, ...],           # Time vector
    :X => [x1_vals x2_vals ...],          # State matrix (n_time × n_states)
    :inputs => Dict(                       # Input vectors or functions (optional)
        :X1 => [3.0, 3.0, 3.0, ...],      # Constant input (as vector)
        :X2 => [2.0, 2.0, 2.0, ...]       # Another input
        # OR as functions: :u1 => t -> sin(t)
    ),
    :params => (param1=val1, ...)         # Parameters used to generate data
)
```

**Note**: The `inputs` dictionary can contain either:
- **Vectors**: Pre-computed input values (one per time point), as used by benchmark problems
- **Functions**: Callable functions of time `t -> value`, useful for custom problems with analytical inputs

Both formats are automatically handled by the discovery algorithm.

## Advanced Usage

### Multiple Experiments

```julia
# Use multiple experiments from a benchmark
experiments = BenchmarkSystems.load_problem("simpleFb1")
println("Number of experiments: ", length(experiments))

# Currently uses first experiment; could be extended to combine data
result = discover_ode_system(experiments; ode_options=options)
```

### Custom Operators

```julia
# Include additional operators
options = ODERegressionOptions(
    binary_operators=(+, *, -, /, ^),
    unary_operators=(cos, sin, exp, log, sqrt),
    niterations_derivative=25,
    complexity_derivative=18
)
```

### Accessing Intermediate Results

```julia
result = discover_ode_system(experiments; ode_options=options)

# Create SR Options for displaying equations
sr_opts = SymbolicRegression.Options(
    binary_operators=options.binary_operators,
    unary_operators=options.unary_operators
)

# All candidates from Stage 1
for (i, candidates) in enumerate(result.derivative_candidates)
    println("\nState $i has $(length(candidates)) candidates:")
    for (j, member) in enumerate(candidates[1:min(3, end)])
        println("  $j: ", string_tree(member.tree, sr_opts))
    end
end

# Selected equations from Stage 2
println("\nBest combination (indices): ", result.best_indices)
println("Integration loss: ", result.integration_loss)
```

## Performance Tips

1. **Start Small**: Use low iteration counts for initial testing
   - `niterations_derivative=5`, `niterations_integration=3`

2. **Increase Gradually**: For production runs:
   - `niterations_derivative=20-50`
   - `niterations_integration=10-20`

3. **Complexity Control**: Limit complexity to avoid overfitting
   - Start with `complexity_integration=8-10`
   - Increase only if necessary

4. **Parallelism**: Use `:multithreading` for faster search
   - Ensure Julia started with multiple threads: `julia -t auto`

5. **Monitor Progress**: Enable `verbose=true` to track search

## Algorithm Details

### Numerical Derivative Computation
- Central finite differences for interior points
- Forward/backward differences for endpoints
- Simple but effective for smooth data

### Integration Loss
- Solves ODE system with `AutoTsit5(Rosenbrock23())`
- Mean squared error between integrated and observed trajectories
- Returns `Inf` for failed integrations or non-finite values

### Search Strategy
- Exhaustive search over candidate combinations in Stage 2
- Feasible because complexity filtering limits candidate pool
- Typically 10-100 combinations for 2-3 state systems

## Limitations and Future Work

**Current Limitations:**
- Uses only first experiment from benchmark (could combine multiple)
- Exhaustive combination search (expensive for >4 states)
- Fixed numerical derivative method
- No explicit noise handling

**Potential Extensions:**
- Bayesian optimization for combination search
- Ensemble methods using multiple experiments
- Adaptive complexity limits
- Regularization for noise robustness
- Multi-objective optimization (accuracy vs. complexity)

## References

This implementation is based on the approach described in the MA thesis notebook `MA.ipynb`,
which prototyped symbolic regression for differential equations using:
- Two-stage derivative + integration approach
- SymbolicRegression.jl for equation discovery
- DifferentialEquations.jl for ODE integration
- Benchmark problems from the Chalmers Dynamical Systems Database

## Example Output

```
================================================================================
Symbolic Regression for Differential Equations
================================================================================
Time points: 13
States: 3
Inputs: 2

================================================================================
Stage 1: Discovering Derivative Equations
================================================================================
Number of states: 3
Number of time points: 13
Feature dimensions: (5, 13)

Searching for dx1/dt...
  Found 8 candidate equations
Searching for dx2/dt...
  Found 7 candidate equations
Searching for dx3/dt...
  Found 9 candidate equations

================================================================================
Stage 2: Integration-Based Refinement
================================================================================
Candidates per state (complexity ≤ 10): [6, 5, 7]
Total combinations to test: 210

Progress: 21/210 (10.0%)
Progress: 42/210 (20.0%)
...

================================================================================
Best ODE System Found
================================================================================

State 1 (candidate 3/6):
  Derivative loss: 0.0012
  Complexity: 8
  dx1/dt = (x1 * -2.1) + (u1 * 0.95)

State 2 (candidate 2/5):
  Derivative loss: 0.0008
  Complexity: 7
  dx2/dt = (x2 * -1.05) + (x1 * 3.2)

State 3 (candidate 4/7):
  Derivative loss: 0.0015
  Complexity: 9
  dx3/dt = (x3 * -0.48) + (x2 * 1.9)

================================================================================
Integration loss: 0.0234
================================================================================
```

## Benchmarking

The `benchmark_ode_discovery.jl` module provides comprehensive benchmarking capabilities to evaluate the ODE discovery algorithm on all benchmark problems.

### Features

- **Automatic comparison**: Compares discovered equations with ground truth using R² scores and relative errors
- **Equivalence detection**: Determines if discovered equations are functionally equivalent (handles algebraic rearrangements)
- **Comprehensive metrics**: Reports R², mean/max absolute errors, relative errors
- **Batch processing**: Test multiple problems with customizable filters
- **Result persistence**: Saves detailed results to timestamped files

### Quick Benchmark

```julia
include("benchmark_ode_discovery.jl")

# Test first 3 problems quickly
quick_benchmark(3)
```

### Benchmark Specific Problems

```julia
# Benchmark all simple linear problems
results = benchmark_all_problems(
    problem_filter = name -> startswith(name, "simpleLin"),
    ode_options = ODERegressionOptions(
        niterations_derivative=15,
        niterations_integration=8,
        differentiation_method=:savitzky_golay,
        verbose=false
    ),
    r2_threshold=0.95,          # R² threshold for equivalence
    max_error_threshold=0.1,    # Max relative error threshold
    save_results=true
)
```

### Benchmark Single Problem

```julia
result = benchmark_single_problem(
    "simpleLin1",
    ode_options=ODERegressionOptions(
        niterations_derivative=20,
        niterations_integration=10
    )
)

# Access results
println("Success: ", result["success"])
println("Discovery time: ", result["discovery_time"], " seconds")
println("Integration loss: ", result["integration_loss"])

for (i, state_result) in enumerate(result["state_results"])
    println("State $i:")
    println("  Equation: ", state_result["equation"])
    println("  R²: ", state_result["r2"])
    println("  Equivalent: ", state_result["is_equivalent"])
end
```

### Comparison Metrics

The benchmarking system compares discovered equations with ground truth using:

1. **R² Score**: Coefficient of determination (1.0 = perfect match)
2. **Mean/Max Absolute Error**: Direct error in derivative values
3. **Mean/Max Relative Error**: Normalized error metrics
4. **Equivalence Detection**: Considers equations equivalent if:
   - R² ≥ threshold (default: 0.95)
   - Max relative error ≤ threshold (default: 0.1)

This approach handles algebraic equivalences like:
- Operation reordering: `x + y` vs `y + x`
- Constant approximations: `2.0` vs `1.999`
- Algebraic simplifications: `x * 2` vs `2 * x`

### Example Output

```
================================================================================
Benchmarking: simpleLin1
================================================================================

State 1:
  Discovered: (x1 * -2.0) + (u1 * 1.0)
  R² score: 0.999845
  Mean relative error: 0.000234
  Max relative error: 0.001456
  Equivalent: ✓ YES

State 2:
  Discovered: (x1 * 3.0) + (x2 * -1.0)
  R² score: 0.999912
  Mean relative error: 0.000189
  Max relative error: 0.000987
  Equivalent: ✓ YES

--------------------------------------------------------------------------------
Overall Result: ✓ SUCCESS
Discovery time: 12.34 seconds
Integration loss: 1.234567e-04
```

### Running Full Benchmark Suite

```julia
# Run on all problems (may take hours)
all_results = benchmark_all_problems(
    ode_options = ODERegressionOptions(
        niterations_derivative=30,
        niterations_integration=15,
        complexity_derivative=20,
        differentiation_method=:savitzky_golay
    ),
    save_results=true
)

# Filter by category
ss_results = benchmark_all_problems(
    problem_filter = name -> startswith(name, "ss_"),
    save_results=true
)
```

Results are saved to `benchmark_results_YYYYMMDD_HHMMSS.txt` with detailed per-problem statistics.
