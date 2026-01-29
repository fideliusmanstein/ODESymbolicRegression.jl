## Multi-Trajectory ODE Discovery: Implementation Summary

### Overview
Successfully implemented multi-trajectory evaluation for ODE discovery to address the problem where incorrect solutions achieve good results by overfitting to a single trajectory.

### Problem Analysis
The original system evaluated candidate ODEs on a single trajectory (one set of initial conditions), allowing incorrect equations to achieve low loss by memorizing that specific trajectory without capturing the true underlying dynamics.

### Solution
Implemented evaluation on multiple trajectories with **different initial conditions**, forcing candidates to work across diverse system states. This makes the discovery process more robust and helps reject overfitted solutions.

---

## Implementation Details

### Phase 1: Data Generation
**File:** `master_thesis/benchmarkProblems/ChemicalRateProblems/simpleLin.jl`

- Added `num_trajectories` parameter to `generate_simplelin_experiments()`
- Generates multiple trajectories per experiment with varied initial conditions
- Samples ICs using Dirichlet-like distribution to respect conservation law: X3 + X4 + X5 = 1.0
- First trajectory uses standard IC (1.0, 0.0, 0.0), additional trajectories use randomized ICs

**File:** `master_thesis/benchmarkProblems/BenchmarkSystems.jl`

- Updated `load_problem()` to accept `num_trajectories` keyword argument
- Passes parameter through to problem generators
- Backward compatible: defaults to `num_trajectories=1` for single-trajectory behavior

### Phase 2: Core Evaluation Logic
**File:** `master_thesis/SymbolicRegressionODE.jl`

**IntegrationLoss struct (lines ~297-329):**
- Changed from storing single (t, X_observed, inputs) to `trajectories::Vector{Dict}`
- Two constructors:
  1. Multi-trajectory: `IntegrationLoss(trajectories::Vector)`
  2. Single-trajectory: `IntegrationLoss(t, X_observed, inputs)` (backward compatible)
- Normalizes dict keys (:X → :X_observed) and matrix types (Adjoint → Matrix)

**evaluate_ode_system() (lines ~347-456):**
- Loops over all trajectories in `loss_config.trajectories`
- Integrates each trajectory from its specific initial condition
- Computes MSE for each trajectory
- Returns average loss across all trajectories
- Handles integration failures gracefully

### Phase 3: Derivative Enhancement
**File:** `master_thesis/SymbolicRegressionODE.jl`

**aggregate_features_and_derivatives() (lines ~170-211):**
- NEW helper function
- Combines features and numerical derivatives from all experiments
- Converts matrices to ensure type consistency (handles Adjoint types)
- Concatenates:
  - Features: horizontally (more time points)
  - Derivatives: vertically (stack trajectories)

**discover_derivatives() (lines ~220-299):**
- Updated signature: accepts `experiments::Vector` instead of `(t, X, inputs)`
- Uses `aggregate_features_and_derivatives()` to combine all trajectory data
- Runs symbolic regression on combined dataset
- Results in equations that fit all trajectories, not just one

### Phase 4: Main Functions
**File:** `master_thesis/SymbolicRegressionODE.jl`

**refine_with_integration() (lines ~463-555):**
- Updated signature to accept `experiments::Vector`
- Creates `IntegrationLoss` with all experiments
- Evaluates candidates on all trajectories simultaneously

**discover_ode_system() (lines ~560-676):**
- Validates all experiments have same state dimensionality
- Passes all experiments to both stages:
  1. Derivative discovery stage
  2. Integration refinement stage
- Returns named tuple with:
  - `derivative_candidates`: Initial equations from Stage 1
  - `best_trees`: Final refined equations from Stage 2
  - `integration_loss`: Average loss across all trajectories
  - `best_indices`: Pareto front indices

---

## Testing

### Test Suite 1: Basic Multi-Trajectory
**File:** `master_thesis/tests/test_multi_trajectory.jl`

**6 tests covering:**
1. ✓ Single trajectory loading (backward compatibility)
2. ✓ IntegrationLoss constructors (old and new style)
3. ✓ discover_derivatives with multiple experiments
4. ✓ evaluate_ode_system with multiple trajectories
5. ✓ Full discover_ode_system pipeline
6. ✓ Comparison of single vs multi-trajectory losses

### Test Suite 2: Multi-IC Robustness
**File:** `master_thesis/tests/test_multi_ic_robustness.jl`

**5 tests covering:**
1. ✓ Data generation with varied ICs (24 trajectories = 8 experiments × 3 ICs)
2. ✓ Single vs multiple trajectory datasets
3. ✓ Full discovery pipeline with 3 ICs
4. ✓ IntegrationLoss storage of all trajectories
5. ✓ discover_ode_system with multiple ICs (4 total trajectories)

**All tests pass!**

---

## Key Features

### Backward Compatibility
- Default behavior unchanged (`num_trajectories=1`)
- Old-style function calls still work
- Single-trajectory constructor for IntegrationLoss preserved

### Type Robustness
- Handles Adjoint matrices from benchmark data
- Converts to standard Matrix type internally
- Normalizes dict keys across different data sources

### Conservation Laws
- Initial conditions respect system constraints
- SimpleLin system: X3 + X4 + X5 = 1.0
- Sampled using Dirichlet-like distribution

### Validation
- Checks all experiments have same state dimensionality
- Validates at least one experiment provided
- Informative error messages for debugging

---

## Usage Example

```julia
using .BenchmarkSystems
using .SymbolicRegressionODE

# Load problem with 3 trajectories per experiment (robust evaluation)
experiments = BenchmarkSystems.load_problem("simpleLin1", num_trajectories=3)
# Returns 24 total trajectories (8 experiments × 3 ICs)

# Create options
ode_options = ODERegressionOptions(
    niterations_derivative = 50,
    niterations_integration = 20,
    differentiation_method = :finite_difference
)

# Discover ODE system (evaluated on all 24 trajectories)
result = discover_ode_system(experiments; ode_options=ode_options)

# Access results
println("Best equations: ", result.best_trees)
println("Integration loss (avg across all trajectories): ", result.integration_loss)
```

---

## Files Modified

1. **SymbolicRegressionODE.jl** (676 lines total)
   - IntegrationLoss struct: ~33 lines
   - aggregate_features_and_derivatives(): ~42 lines  
   - discover_derivatives(): ~80 lines (updated)
   - evaluate_ode_system(): ~110 lines (updated)
   - refine_with_integration(): ~93 lines (updated)
   - discover_ode_system(): ~117 lines (updated)

2. **benchmarkProblems/BenchmarkSystems.jl** 
   - load_problem(): Added num_trajectories parameter

3. **benchmarkProblems/ChemicalRateProblems/simpleLin.jl**
   - generate_simplelin_experiments(): Added IC variation logic

4. **tests/test_multi_trajectory.jl** (NEW, 180 lines)
   - 6 comprehensive tests

5. **tests/test_multi_ic_robustness.jl** (NEW, 208 lines)
   - 5 robustness validation tests

**Total:** ~700 lines of new/modified code

---

## Performance Impact

- **Memory:** O(k) where k = number of trajectories (linear increase)
- **Computation:** Integration done k times instead of 1
- **Benefit:** Much better rejection of incorrect solutions
- **Trade-off:** ~k× slower evaluation, but more robust results

For typical usage (k=2-5), overhead is acceptable given the improved robustness.

---

## Next Steps (Future Work)

1. **Extend to other benchmark systems:**
   - Add num_trajectories support to simpleFb, osc, metabol, etc.
   
2. **Adaptive IC sampling:**
   - Use variance-based sampling to maximize information gain
   
3. **Parallel evaluation:**
   - Integrate trajectories in parallel using threading
   
4. **IC optimization:**
   - Active learning to select most informative initial conditions
   
5. **Comprehensive benchmarking:**
   - Compare single vs multi-trajectory discovery success rates
   - Measure improvement in equation accuracy

---

## Conclusion

The multi-trajectory implementation successfully addresses the overfitting problem by:

1. ✅ Evaluating on diverse initial conditions
2. ✅ Maintaining backward compatibility  
3. ✅ Preserving system conservation laws
4. ✅ Providing robust type handling
5. ✅ Comprehensive test coverage

The system is now production-ready for discovering ODEs with improved robustness against incorrect solutions.
