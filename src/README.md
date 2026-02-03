# Source Code Organization

This directory contains the modular implementation of the ODE discovery algorithm. The code is organized to follow the execution pipeline, making it easy to understand the data flow.

## Pipeline Overview

```
User Input (time-series data)
         ↓
[discovery.jl] - Main orchestration
         ↓
[Stage 1: Derivative Discovery]
    ↓
differentiation.jl - Compute numerical derivatives & features
    ↓
stage1_derivatives.jl - Symbolic regression on derivatives
    ↓
[Stage 2: Integration Refinement]
    ↓
integration_loss.jl - Evaluate candidates via ODE integration
    ↓
stage2_refinement.jl - Test combinations & refine equations
    ↓
Result: Discovered ODE system
```

## Files in Pipeline Order

### 1. **ODESymbolicRegression.jl** (42 lines)
**Purpose**: Package entry point and thin wrapper module

**What it does**:
- Defines the top-level `ODESymbolicRegression` module
- Includes and re-exports the implementation from `SymbolicRegressionODE`
- This is what users interact with via `using ODESymbolicRegression`

**Key exports**: All public API functions

---

### 2. **SymbolicRegressionODE.jl** (42 lines)
**Purpose**: Main module coordinator

**What it does**:
- Loads all dependencies (DifferentialEquations, SymbolicRegression, etc.)
- Includes all submodules in correct dependency order
- Defines the module structure and exports

**Key exports**:
- `ODERegressionOptions` - Configuration structure
- `discover_ode_system` - Main discovery function
- `IntegrationLoss` - Loss evaluation structure
- `create_feature_matrix` - Feature preparation utility

**Includes**: helpers.jl → options.jl → differentiation.jl → stage1_derivatives.jl → integration_loss.jl → stage2_refinement.jl → discovery.jl

---

### 3. **helpers.jl** (143 lines)
**Purpose**: Shared utility functions used across multiple modules

**What it provides**:
- `normalize_equation_internal(tree, sr_options)` - Simplifies and formats equations for display
  - Uses SymbolicUtils to simplify expressions
  - Rounds constants to 2 decimal places
  - Handles symbolic variable substitution
  
- `setup_input_interpolations(t, inputs)` - Creates interpolation functions for time-varying inputs
  - Handles external forcing functions
  - Returns dictionary of interpolation functions
  
- `create_ode_function(trees, input_interps)` - Constructs ODE dynamics function
  - Builds the `f(dx, x, p, t)` function required by DifferentialEquations.jl
  - Combines equation trees with input interpolations
  - Handles error cases gracefully

**Used by**: All stages of the pipeline

---

### 4. **options.jl** (68 lines)
**Purpose**: Configuration structure for ODE discovery

**What it provides**:
- `ODERegressionOptions` struct with validated parameters:
  - **Operators**: Binary (+, *, -, /) and unary (cos, sin, exp) operators
  - **Complexity limits**: `complexity_derivative` (Stage 1), `complexity_integration` (Stage 2)
  - **Iteration counts**: `niterations_derivative`, `niterations_integration`
  - **Differentiation method**: `:finite_difference` or `:savitzky_golay`
  - **Parallelism**: `:serial`, `:multithreading`, or `:multiprocessing`
  - **Savitzky-Golay parameters**: Window size and polynomial order
  - **Random seed** and verbosity settings

**Validation**: Ensures odd window sizes, valid methods, and positive values

**Used by**: Passed throughout the entire pipeline

---

### 5. **differentiation.jl** (156 lines)
**Purpose**: Numerical differentiation and feature matrix construction

**What it provides**:
- `compute_numerical_derivatives(t, X; method, window, poly_order)` - Computes dx/dt numerically
  - **Finite difference**: Central differences (interior), forward/backward (endpoints)
  - **Savitzky-Golay**: Smoothed polynomial derivatives for noisy data
  - Returns derivative matrix (n_time × n_states)
  
- `create_feature_matrix(t, X, inputs)` - Prepares features for symbolic regression
  - Features are `[x1, x2, ..., xn, u1, u2, ...]` (time is implicit in ODEs)
  - Handles both vector and function inputs
  - Returns (n_features × n_time) matrix
  
- `aggregate_features_and_derivatives(experiments, ode_options)` - Combines multi-trajectory data
  - Concatenates features and derivatives from all trajectories
  - Enables learning from multiple initial conditions
  - Returns combined data for robust fitting

**Used by**: Stage 1 (derivative discovery) and Stage 2 (residual computation)

---

### 6. **stage1_derivatives.jl** (86 lines)
**Purpose**: Stage 1 - Derivative-based symbolic regression

**What it does**:
1. Aggregates features and derivatives from all trajectories
2. For each state variable `xi`:
   - Runs symbolic regression: `dxi/dt ≈ f(x1, x2, ..., u1, u2, ...)`
   - Uses `SymbolicRegression.equation_search`
   - Extracts Pareto frontier of complexity vs. accuracy
3. Returns candidate equations for each state

**Key function**:
- `discover_derivatives(experiments, ode_options)` - Main Stage 1 function
  - Returns: `Vector{Vector}` - List of candidate equations per state
  - Prints progress if verbose mode enabled

**Output**: Multiple candidate equations per state variable (Pareto frontier)

---

### 7. **integration_loss.jl** (151 lines)
**Purpose**: Integration-based evaluation of candidate ODE systems

**What it provides**:
- `IntegrationLoss` struct - Holds trajectory data for evaluation
  - Supports single or multiple trajectories
  - Normalizes data format (handles `:X` or `:X_observed` keys)
  - Stores time vectors, state matrices, and input dictionaries
  
- `evaluate_ode_system(trees, loss_config)` - Evaluates ODE system quality
  - Constructs ODE from equation trees
  - Integrates each trajectory using DifferentialEquations.jl
  - Compares integrated solutions to observed data
  - Returns average MSE across all valid trajectories
  - Handles integration failures gracefully (returns Inf)

**Why integration-based?**: Ensures equations work together as a coupled system, not just individually

**Used by**: Stage 2 combination testing and refinement

---

### 8. **stage2_refinement.jl** (293 lines)
**Purpose**: Stage 2 - Integration-based combination testing and refinement

**What it does**:

**Step 1: Find best initial combination**
- Filters candidates by complexity threshold
- Tests all combinations of candidate equations
- Evaluates each using `IntegrationLoss` (multi-trajectory)
- Selects combination with lowest integration loss
- Shows progress during combinatorial search

**Step 2: Iterative refinement** (if `niterations_integration > 0`)
- For each equation in the system:
  - Computes integration residuals (how well current system integrates)
  - Runs symbolic regression on residuals to find corrections
  - Tests if refined equation improves overall system
  - Keeps improvements, rejects regressions
- Prints improvement statistics

**Key functions**:
- `refine_with_integration(derivative_candidates, experiments, ode_options)` - Main Stage 2 function
  - Returns: `(best_trees, best_loss, best_indices, initial_trees, initial_loss)`
  
- `compute_integration_residuals(trees, state_idx, experiments, ode_options)` - Residual calculation
  - Integrates current system
  - Computes residuals = observed - predicted
  - Takes derivative of residuals to get dx/dt correction
  - Returns synthetic training data for refinement

**Output**: Final refined ODE system with integration loss

---

### 9. **discovery.jl** (92 lines)
**Purpose**: Main orchestration - coordinates the two-stage discovery process

**What it does**:
1. **Validates input**:
   - Ensures at least one experiment provided
   - Checks all experiments have same number of states
   
2. **Prints configuration** (if verbose):
   - Number of experiments/trajectories
   - States per experiment
   - Time points and inputs per experiment
   
3. **Executes pipeline**:
   - Calls `discover_derivatives()` - Stage 1
   - Calls `refine_with_integration()` - Stage 2
   
4. **Returns results** as named tuple:
   - `derivative_candidates` - All Stage 1 candidates
   - `best_trees` - Final equation trees
   - `integration_loss` - Final loss value
   - `best_indices` - Which candidates were selected
   - `initial_trees` - Trees before refinement
   - `initial_loss` - Loss before refinement

**Key function**:
- `discover_ode_system(experiments; ode_options)` - Main entry point
  - This is what users call to discover ODEs
  - Supports multi-trajectory experiments for robustness

**Example usage**:
```julia
using ODESymbolicRegression

experiments = load_problem("simpleLin1")
options = ODERegressionOptions(
    niterations_derivative=100,
    niterations_integration=20
)
result = discover_ode_system(experiments; ode_options=options)
```

---

## Data Flow Summary

```
1. User provides experiments (time-series + optional inputs)
   ↓
2. discovery.jl validates and starts pipeline
   ↓
3. differentiation.jl computes dx/dt and features
   ↓
4. stage1_derivatives.jl finds candidate equations
   ↓
5. integration_loss.jl evaluates candidates
   ↓
6. stage2_refinement.jl tests combinations & refines
   ↓
7. helpers.jl used throughout for ODE construction
   ↓
8. discovery.jl returns final ODE system
```

## Design Principles

- **Modularity**: Each file has a single, clear responsibility
- **Pipeline order**: Files are organized by execution flow
- **Reusability**: Common utilities in helpers.jl
- **Clarity**: File names describe their purpose
- **Size**: All files under 300 lines for maintainability

## Key Algorithms

### Two-Stage Approach

**Stage 1** finds equations that fit numerical derivatives well (local accuracy)

**Stage 2** ensures equations work together when integrated (global consistency)

This combination provides both accuracy and physical plausibility.

### Multi-Trajectory Robustness

All stages support multiple trajectories with different initial conditions:
- Prevents overfitting to single trajectory
- Ensures equations generalize across state space
- More robust discovery for complex systems
