# Iterative Co-Refinement in ODE Discovery

## Problem

Previously, the integration phase (Stage 2) only tested combinations of pre-discovered equations from Stage 1. Each derivative equation was optimized independently in Stage 1, but they couldn't evolve together during Stage 2.

This meant:
1. **Sequential optimization**: Equation 1 finalized → Equation 2 finalized → ... → Equation N finalized
2. **No co-evolution**: Equations couldn't adapt to work better as a coupled system
3. **Local optima**: Once a combination was selected, it was fixed

## Solution

The new implementation adds **iterative co-refinement** to Stage 2:

### Stage 2 Process (Updated)

**Step 1: Initial Selection (unchanged)**
- Test all combinations of candidate equations
- Select the combination with lowest integration loss
- This gives us a good starting point

**Step 2: Iterative Co-Refinement (NEW)**
- For `niterations_integration` iterations:
  - For each equation in the system:
    - Compute integration residuals (how well current system predicts trajectories)
    - Use residuals to create synthetic training targets
    - Run short symbolic regression to improve this equation
    - Test if the improvement reduces overall integration loss
    - Keep the improvement if it helps
  - Continue until no improvements found or iterations exhausted

### Key Features

1. **Residual-Based Targets**: Instead of using numerical derivatives, we use the difference between integrated predictions and observed data to guide improvements

2. **System-Level Optimization**: All equations evolve together - improving one equation considers its effect on the entire system

3. **Configurable Refinement**: Set `niterations_integration`:
   - `0`: No refinement (original behavior)
   - `3-5`: Fast refinement for quick results
   - `10+`: Thorough refinement for best accuracy

## Example Usage

```julia
using .SymbolicRegressionODE
using .BenchmarkSystems

# Load problem with multiple trajectories
experiments = BenchmarkSystems.load_problem("simpleLin", num_trajectories=3)

# Configure with iterative refinement
options = ODERegressionOptions(
    niterations_derivative = 15,      # Stage 1 iterations
    niterations_integration = 5,      # Stage 2 refinement iterations (NEW)
    complexity_derivative = 12,
    complexity_integration = 10,
    parallelism = :serial,
    verbose = true
)

# Discover ODE system
result = discover_ode_system(experiments; ode_options=options)
```

## Output Example

```
Step 1: Finding best initial combination...
  Progress: 64/64 (100.0%)
  Initial best loss: 0.0234

Step 2: Iterative co-refinement (5 iterations)...
  All equations will be optimized simultaneously using integration loss

  Iteration 1/5
    Refining equation 1...
      ✓ Improved! Loss: 0.0198 (15.4% better than initial)
    Refining equation 2...
      ✓ Improved! Loss: 0.0176 (24.8% better than initial)
    Refining equation 3...
    No improvement

  Iteration 2/5
    ...

  Refinement complete!
    Initial loss: 0.0234
    Final loss: 0.0142
    Improvement: 39.3%
```

## Benefits

1. **Better Solutions**: Equations can adapt to work together, finding better coupled dynamics
2. **Robustness**: Multi-trajectory evaluation ensures solutions work across different initial conditions
3. **Flexibility**: Can trade off speed (fewer iterations) vs accuracy (more iterations)
4. **Backward Compatible**: Setting `niterations_integration=0` gives original behavior

## Technical Details

### Residual Computation

For each equation being refined:
1. Integrate current ODE system forward in time
2. Compute residuals: `residual = X_observed - X_predicted`
3. Differentiate residuals to get correction term: `dR/dt`
4. New target: `dx/dt_new = dx/dt_current + dR/dt`

This tells symbolic regression how to adjust the equation to reduce integration error.

### Search Strategy

Each refinement iteration runs 3 symbolic regression iterations per equation (configurable). This is intentionally short because:
- We do multiple outer iterations
- We want incremental improvements
- Longer searches per iteration can overfit to current system state

### Multi-Trajectory Support

All refinement uses integration loss across ALL trajectories, ensuring:
- Solutions generalize to different initial conditions
- Overfitting to single trajectories is prevented
- More robust derivative discovery

## Performance Notes

- **Computational Cost**: Refinement adds ~20-50% overhead depending on system size
- **Recommended Settings**:
  - Fast testing: `niterations_integration = 3`
  - Production: `niterations_integration = 5-10`
  - Research: `niterations_integration = 10-20`

## Implementation

See `SymbolicRegressionODE.jl`:
- `refine_with_integration()`: Main refinement loop
- `compute_integration_residuals()`: Residual computation
- `create_ode_function()`: ODE system construction
- `setup_input_interpolations()`: Input handling
