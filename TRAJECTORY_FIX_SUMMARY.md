# Summary: num_trajectories Investigation & Fix

## Question
"Check if num trajectories actually work, can every experiment be given any initial values?"

## Answer

### ✅ FIXED: num_trajectories now works correctly for simpleLin

**Bug Found & Fixed**: The `load_problem()` function had a bug that truncated results for simpleLin problems.

- **Before fix**: `load_problem("simpleLin1", num_trajectories=3)` returned 3 experiments (WRONG)
- **After fix**: Returns 24 experiments = 8 input combinations × 3 trajectories each (CORRECT)

### Current Support Status

| Problem Type | num_trajectories Support | Behavior |
|-------------|-------------------------|----------|
| **simpleLin1, simpleLin2** | ✅ **YES** (Native) | Generates N trajectories per experiment with different ICs |
| **All other problems** | ⚠️ **NO** (Partial) | Limits total experiments to first N |

### How simpleLin Works

When you call:
```julia
experiments = BenchmarkSystems.load_problem("simpleLin1", num_trajectories=3)
```

You get **24 total experiments**:
- 8 different input combinations (X1, X2 values)
- 3 different initial conditions per combination
- Each IC satisfies conservation law: X3 + X4 + X5 = 1.0
- First trajectory uses standard IC: (1.0, 0.0, 0.0)
- Additional trajectories use random ICs

### Can Every Experiment Be Given Any Initial Values?

**Answer: Depends on the problem**

1. **simpleLin**: ✅ YES
   - Automatically generates varied ICs when `num_trajectories > 1`
   - ICs respect conservation law
   - Cannot manually specify ICs (automatic generation only)

2. **Other problems** (simpleFb, osc, metabol, etc.): ❌ NO
   - Have fixed, predefined initial conditions
   - `num_trajectories` only limits how many experiments to load
   - Would need code modifications to support multiple ICs

### Files Modified

1. **[BenchmarkSystems.jl](benchmark/benchmarkProblems/BenchmarkSystems.jl#L419-L495)** - Fixed `load_problem()` function
   - Changed limiting logic to only apply to non-simpleLin problems
   - Updated documentation to clarify support status

### Tests Verified

All tests in [test_multi_ic_robustness.jl](test/tests/test_multi_ic_robustness.jl) now pass:
- ✅ Data generation with varied ICs
- ✅ Conservation law respected
- ✅ IntegrationLoss uses all trajectories
- ✅ Full discovery pipeline works with multiple ICs

### Future Enhancements

To add `num_trajectories` support to other problems:
1. Modify each `generate_*_experiments()` function to accept parameter
2. Implement IC generation logic (respecting system constraints)
3. Add `:trajectory` and `:ic` fields to experiment dictionaries

See [TRAJECTORY_INVESTIGATION_REPORT.md](TRAJECTORY_INVESTIGATION_REPORT.md) for detailed analysis.
