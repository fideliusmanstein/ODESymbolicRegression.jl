# Trajectory Investigation Report

## Summary

Investigation of the `num_trajectories` functionality revealed:

1. **BUG FOUND**: `load_problem()` incorrectly truncates results when `num_trajectories` is specified
2. **LIMITED SUPPORT**: Only `simpleLin` problems support multiple trajectories per experiment natively
3. **OTHER PROBLEMS**: All other problems have fixed initial conditions and don't support `num_trajectories`

## Detailed Findings

### Bug in `load_problem()`

**Location**: [benchmark/benchmarkProblems/BenchmarkSystems.jl](benchmark/benchmarkProblems/BenchmarkSystems.jl#L485-L490)

**Issue**: The function has trailing code that limits total experiments:

```julia
# Limit to requested number of trajectories if specified
if num_trajectories !== nothing && num_trajectories < length(experiments)
    return experiments[1:num_trajectories]
else
    return experiments
end
```

**Problem**: When `simpleLin` generates 8 experiments × 3 trajectories = 24 total, this code incorrectly truncates to just 3 experiments.

**Expected Behavior**:
- `load_problem("simpleLin1", num_trajectories=3)` should return **24 experiments** (8 input combinations × 3 trajectories each)
- **Actual behavior**: Returns only **3 experiments** (first 3 from the list)

**Impact**: 
- Tests fail (`test_multi_ic_robustness.jl` expects 24 but gets 3)
- Users cannot use multiple trajectories feature for simpleLin problems
- The limiting code was meant for problems that don't support `num_trajectories`, but it applies to all problems

### Problems Supporting `num_trajectories`

| Problem | Native Support | Notes |
|---------|---------------|-------|
| simpleLin1, simpleLin2 | ✅ YES | Generates multiple ICs per experiment, respects conservation law |
| simpleFb1-4 | ❌ NO | Fixed 1-4 experiments with predefined ICs |
| osc1-2 | ❌ NO | Single experiment with fixed IC |
| metabol1-3 | ❌ NO | 12 experiments with fixed IC, varying inputs |
| threeGenes1-2 | ❌ NO | 16 experiments with predefined ICs |
| feedf1-2 | ❌ NO | 16 experiments with predefined ICs |
| inhosc1-2 | ❌ NO | 4 experiments with predefined ICs |
| bifeedb1-2 | ❌ NO | 16 experiments with predefined ICs |

### How `simpleLin` Implements Multiple Trajectories

[simpleLin.jl](benchmark/benchmarkProblems/ChemicalRateProblems/simpleLin.jl#L185-L243) correctly implements:

1. Accepts `num_trajectories` parameter (default: 1)
2. For each of 8 input combinations:
   - Generates `num_trajectories` different initial conditions
   - First trajectory uses standard IC: `(X3_0=1.0, X4_0=0.0, X5_0=0.0)`
   - Additional trajectories use random ICs satisfying `X3 + X4 + X5 = 1.0`
3. Each experiment dictionary includes:
   - `:experiment` - which input combination (1-8)
   - `:trajectory` - which trajectory for that experiment (1-N)
   - `:ic` - the initial conditions used

**Example output for `num_trajectories=3`**:
```julia
experiments = load_problem("simpleLin1", num_trajectories=3)
# Should contain 24 total experiments:
# - Experiment 1, Trajectory 1-3
# - Experiment 2, Trajectory 1-3
# - ...
# - Experiment 8, Trajectory 1-3
```

## Test Results

### Before Fix

```bash
julia test/tests/test_multi_ic_robustness.jl
# FAIL: Expected 24 experiments, got 3
```

### Investigation Script Output

```
simpleLin1 with num_trajectories=3:
  Total experiments: 3  ← WRONG! Should be 24
  Unique experiment numbers: [1]  ← Only first experiment
  Unique trajectory numbers: [1, 2, 3]
```

## Recommended Fixes

### Fix 1: Correct the `load_problem()` Bug (REQUIRED)

The limiting code should only apply to problems that **don't** natively support `num_trajectories`. Options:

**Option A**: Remove the limiting code entirely
```julia
# Just return what the problem generator produces
return experiments
```

**Option B**: Only limit for non-simpleLin problems
```julia
# Only limit for problems that don't natively support num_trajectories
if num_trajectories !== nothing && !startswith(problem_name, "simpleLin")
    if num_trajectories < length(experiments)
        return experiments[1:num_trajectories]
    end
end
return experiments
```

**Option C**: Add a flag to track native support
- More complex but cleaner architecture
- Would require documenting which problems support it

### Fix 2: Add `num_trajectories` Support to Other Problems (OPTIONAL)

Each problem would need:

1. Update `generate_*_experiments()` to accept `num_trajectories` parameter
2. Generate multiple ICs per experiment (respecting system constraints)
3. Add `:trajectory` and `:ic` fields to dictionaries
4. Update tests and documentation

**Example for simpleFb**:
```julia
function generate_simplefb_experiments(; problem="simpleFb1", num_trajectories=1)
    # ... determine noise_std and base_ics ...
    
    experiments = []
    for (exp_idx, base_ic) in enumerate(base_ics)
        for traj_idx in 1:num_trajectories
            # Generate varied IC if traj_idx > 1
            ic = (traj_idx == 1) ? base_ic : generate_varied_ic(base_ic)
            
            # ... generate data ...
            
            push!(experiments, Dict(
                :experiment => exp_idx,
                :trajectory => traj_idx,
                :ic => ic,
                # ... other fields ...
            ))
        end
    end
end
```

## Recommendations

1. **IMMEDIATE**: Fix the bug in `load_problem()` (Option A or B)
2. **SHORT TERM**: Update documentation to clarify which problems support `num_trajectories`
3. **LONG TERM**: Consider adding support to other problems if needed for research

## Files to Fix

1. [benchmark/benchmarkProblems/BenchmarkSystems.jl](benchmark/benchmarkProblems/BenchmarkSystems.jl) - Fix `load_problem()` function
2. [test/tests/test_multi_ic_robustness.jl](test/tests/test_multi_ic_robustness.jl) - Should pass after fix
3. Documentation files - Update to clarify support status
