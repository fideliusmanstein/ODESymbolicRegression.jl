# Running Benchmarks After NaN Fixes

## Quick Start

### 1. Install Dependencies

First, install all required Julia packages:

```bash
cd /path/to/ODESymbolicRegression.jl
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

This may take several minutes on first run as it downloads and compiles dependencies.

### 2. Verify the Fix

Run the standalone test to verify the NaN fixes work:

```bash
cd benchmark
julia test_nan_fix.jl
```

Expected output:
```
================================================================================
Testing Ground Truth Evaluation Fix
================================================================================
...
All tests completed successfully!
================================================================================
```

### 3. Run a Single Problem Benchmark

For a quick test, you can run a single problem:

```bash
cd benchmark
julia --project=.. benchmark.jl
```

**Note**: The benchmark.jl file is configured by default to test only 1 problem. Modify the constant `MAX_PROBLEMS_TO_TEST` at the top of the file to test more problems:

```julia
const MAX_PROBLEMS_TO_TEST = 1  # Change to 5, 10, 20, or nothing for all problems
```

### 4. Run Full Benchmark Suite

To run all testable problems (excluding timeout-prone ones):

```julia
const MAX_PROBLEMS_TO_TEST = nothing  # Test all problems
const TIMEOUT_SECONDS = 300  # 5 minutes per problem (optional)
```

Then run:
```bash
julia --project=.. benchmark.jl
```

### 5. Run Parallel Benchmarks

For faster execution across multiple problems:

```bash
julia --project=.. parallel_benchmark.jl
```

## Benchmark Configuration

Key parameters in `benchmark/benchmark.jl`:

```julia
# Test configuration
const TEST_OPTIONS = SymbolicRegressionODE.ODERegressionOptions(
    niterations_derivative = 3,   # Increase to 100 for production
    niterations_integration = 3,  # Increase to 20 for production
    complexity_derivative = 15,
    complexity_integration = 15,
    ...
)

# Multi-trajectory evaluation
const NUM_TRAJECTORIES = 3  # Number of initial conditions per experiment
const NOISE_STD = 0.0       # Noise level (0.0 = no noise)

# Testing limits
const MAX_PROBLEMS_TO_TEST = 1    # Limit for quick testing
const TIMEOUT_SECONDS = nothing   # Optional timeout per problem
```

## Understanding Results

### Successful Run

Example output:
```
Problem: simpleLin1
  Success: true
  Integration Loss: 0.0234
  Discovery Time: 12.5s
  N States: 3
  
  Equation Similarity Analysis
  ================================================================================
  Equation 1:
    RMSE: 1.234e-02
    NRMSE: 0.0145
    MAE: 9.876e-03
    Max Error: 2.345e-02
    R²: 0.998765
    Valid samples: 300
    ✓ Excellent match (R² > 0.99)
```

### Failed Run (Before Fix)

This is what you would see with the NaN bug:
```
  Equation Similarity Analysis
  ================================================================================
  Equation 1:
    ⚠ Unable to compute metrics (NaN values)
```

### After Fix

With the fix, you should see valid metrics with finite values.

## Results Location

Benchmark results are saved to:
```
benchmark_results/results_YYYYMMDD_HHMMSS.txt
```

Example:
```
benchmark_results/results_20260209_133000.txt
```

## Troubleshooting

### Issue: "Package X not installed"

**Solution**: Run `Pkg.instantiate()` in the project environment:
```bash
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

### Issue: "NaN values still appearing"

**Checklist**:
1. Verify you're using the updated code (check for `·` to `*` replacement in benchmark_ode_discovery.jl)
2. Run `test_nan_fix.jl` to verify the fix is working
3. Check that ground truth equations are being parsed correctly
4. Look for error messages in the output that might indicate other issues

### Issue: Tests timeout

**Solution**: Increase `TIMEOUT_SECONDS` or use `MAX_PROBLEMS_TO_TEST` to limit which problems are tested:

```julia
const TIMEOUT_SECONDS = 600  # 10 minutes
const MAX_PROBLEMS_TO_TEST = 10  # Only test first 10 problems
```

### Issue: Low success rate

**Note**: With minimal test configuration (3 iterations), success rate may be low. This is expected for quick testing. For production-quality results:

```julia
const TEST_OPTIONS = SymbolicRegressionODE.ODERegressionOptions(
    niterations_derivative = 100,  # Production setting
    niterations_integration = 20,  # Production setting
    ...
)
```

## Next Steps

After running benchmarks:

1. **Review Results**: Check the generated results file for success rates and equation quality

2. **Analyze Failures**: Look at which problems failed and why
   - Integration loss too high?
   - Timeout?
   - Error during discovery?

3. **Compare Equations**: For successful discoveries, review the equation similarity scores to see how close the discovered equations are to ground truth

4. **Iterate**: Adjust parameters (iterations, complexity limits) based on results

## Expected Behavior

With the NaN fixes:
- ✓ All equation similarity metrics should be finite numbers or intentionally NaN (for edge cases like constant values)
- ✓ Error messages should be clear and actionable
- ✓ No silent failures in equation evaluation
- ✓ Accurate assessment of equation quality

## Example: Running a Quick Test

Complete workflow for a quick verification:

```bash
# 1. Navigate to project
cd /path/to/ODESymbolicRegression.jl

# 2. Install dependencies (first time only)
julia --project=. -e "using Pkg; Pkg.instantiate()"

# 3. Verify fix works
cd benchmark
julia test_nan_fix.jl

# 4. Run single problem benchmark
julia --project=.. benchmark.jl

# 5. Check results
cat ../benchmark_results/results_*.txt | less
```

Expected time: 5-15 minutes for a single problem with minimal configuration.

## Support

For issues or questions:
1. Check NAN_FIX_SUMMARY.md for detailed explanation of fixes
2. Review debug_nan_issue.jl for diagnostic code
3. Check the generated results files for error messages
