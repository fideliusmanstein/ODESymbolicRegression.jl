# Test Suite Documentation

## Overview

This directory contains comprehensive tests for the ODE discovery system with multi-trajectory evaluation.

## Test Files

### 1. `test_multi_trajectory.jl`
**Purpose:** Tests core multi-trajectory functionality

**Tests:**
- Single trajectory loading (backward compatibility)
- IntegrationLoss constructors
- discover_derivatives with multiple experiments
- evaluate_ode_system with multiple trajectories
- Full pipeline integration
- Comparison of single vs multiple trajectory results

**Run:** `julia test_multi_trajectory.jl`

### 2. `test_multi_ic_robustness.jl`
**Purpose:** Tests robustness improvements from varied initial conditions

**Tests:**
- Data generation with different ICs
- Conservation law validation (X3 + X4 + X5 = 1.0)
- IntegrationLoss trajectory storage
- Full discovery pipeline with multiple ICs
- End-to-end validation

**Run:** `julia test_multi_ic_robustness.jl`

### 3. `test_benchmark.jl` ⭐ **NEW: Refactored & Enhanced**
**Purpose:** Comprehensive test of all 63 benchmark systems with multi-trajectory evaluation

**Features:**
- ✨ **Multi-trajectory evaluation** (2 ICs per experiment by default)
- 🔄 Refactored for readability with modular helper functions
- ⏱️ Timeout protection for large systems
- 📊 Detailed result reporting
- 🎯 Excludes timeout-prone problems (ss_15genes, ss_30genes)

**Configuration:**
```julia
NUM_TRAJECTORIES = 2        # ICs per experiment (easily adjustable)
TIMEOUT_SECONDS = 180       # Per-problem timeout
TEST_OPTIONS:
  - niterations_derivative: 3
  - niterations_integration: 3
  - operators: +, -, *, /
  - parallelism: :serial
```

**Structure:**
```julia
# Setup and Configuration
├── Constants (TIMEOUT_PROBLEMS, TEST_OPTIONS, NUM_TRAJECTORIES)
│
# Helper Functions
├── get_test_problems()          # Get filtered problem list
├── create_result_dict()         # Standardized results
├── run_single_benchmark()       # Execute one test
├── run_with_timeout()           # Timeout protection
│
# Result Reporting
├── write_result_to_file()       # File output
├── print_failure_diagnostics()  # Console diagnostics
├── write_summary()              # Final summary
│
# Main Execution
└── Test loop with @testset
```

**Run:** `julia --project=.. test_benchmark.jl`

**Output:**
- Console: Progress and failure diagnostics
- File: `test_results_YYYYMMDD_HHMMSS.txt` with detailed results

### 4. `demo_multi_trajectory_improvement.jl`
**Purpose:** Demonstration of multi-trajectory benefits

**Shows:**
- Single vs multi-trajectory comparison
- Why multiple ICs improve robustness
- Overfitting detection
- Best practices recommendations

**Run:** `julia demo_multi_trajectory_improvement.jl`

## Quick Start

### Run All Tests
```bash
cd master_thesis/tests

# Core functionality
julia test_multi_trajectory.jl

# Robustness validation
julia test_multi_ic_robustness.jl

# Full benchmark suite (takes ~30-60 min)
julia --project=.. test_benchmark.jl
```

### Adjust Multi-Trajectory Settings

To change the number of trajectories in `test_benchmark.jl`:
```julia
# Line 60: Change this constant
const NUM_TRAJECTORIES = 3  # Default is 2
```

**Recommendations:**
- `NUM_TRAJECTORIES = 1`: Fast, original behavior (backward compatible)
- `NUM_TRAJECTORIES = 2`: Good balance (default)
- `NUM_TRAJECTORIES = 3`: More robust, slower
- `NUM_TRAJECTORIES = 5`: Maximum robustness, significantly slower

## Test Results

### Expected Behavior

**All tests passing:**
```
✓ test_multi_trajectory.jl - 6/6 tests pass
✓ test_multi_ic_robustness.jl - 5/5 tests pass
✓ test_benchmark.jl - ~50-58/58 problems succeed
```

**Typical failures in benchmark:**
- Very complex systems (15+ states)
- High noise problems
- Systems requiring sin/cos operators (disabled in minimal config)

### Interpreting Results

**Integration Loss Guidelines:**
- `< 0.01`: Excellent discovery
- `0.01 - 0.1`: Good discovery
- `0.1 - 1.0`: Acceptable (threshold for success)
- `> 1.0`: Failed discovery

**Multi-trajectory benefits:**
- Lower overfitting risk
- Better generalization
- More reliable equation validation
- Conservation laws respected

## Key Improvements

### Refactoring Benefits

**Before:**
- Monolithic 230-line function
- Repeated code patterns
- Hard to modify or extend
- Mixed concerns (testing, reporting, execution)

**After:**
- Modular helper functions
- Clear separation of concerns
- Easy to adjust NUM_TRAJECTORIES
- Better error handling
- Clearer flow and documentation

### Multi-Trajectory Integration

**Changes:**
1. Added `NUM_TRAJECTORIES` constant (line 60)
2. Modified `run_single_benchmark()` to pass `num_trajectories`
3. Updated `benchmark_single_problem()` to accept and use parameter
4. Enhanced reporting to show trajectory count

**Impact:**
- Evaluates equations on multiple initial conditions
- Rejects solutions that overfit to single IC
- Maintains backward compatibility (NUM_TRAJECTORIES=1)

## Troubleshooting

### Tests Time Out
- Increase `TIMEOUT_SECONDS`
- Reduce `NUM_TRAJECTORIES`
- Add problem to `TIMEOUT_PROBLEMS` list

### Low Success Rate
- Check `NUM_TRAJECTORIES` setting
- Verify test configuration (might be too minimal)
- Review integration loss threshold

### Memory Issues
- Use `:serial` parallelism
- Reduce `NUM_TRAJECTORIES`
- Test fewer problems at once

## Future Enhancements

Potential improvements:
- [ ] Adaptive NUM_TRAJECTORIES based on system complexity
- [ ] Parallel execution of independent benchmark tests
- [ ] Automatic operator selection based on ground truth
- [ ] Cross-validation with held-out trajectories
- [ ] Performance profiling and optimization

## References

- Main implementation: `../SymbolicRegressionODE.jl`
- Benchmark systems: `../benchmarkProblems/`
- Documentation: `../docs/`
