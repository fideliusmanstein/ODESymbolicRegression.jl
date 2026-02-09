# Benchmark Results Analysis

This directory provides comprehensive tools for analyzing ODE discovery benchmark results.

## Quick Start

### 1. Run Benchmarks

```julia
# In Julia REPL
include("benchmark/benchmark.jl")

# Benchmark runs automatically save 3 files:
# - summary_TIMESTAMP.csv      (quick statistics)
# - detailed_TIMESTAMP.json    (complete information)
# - results_TIMESTAMP.txt      (human-readable report)
```

### 2. Analyze Results

```julia
# Load analysis tools
include("benchmark/analyze_results.jl")

# Analyze summary statistics
df = analyze_benchmark_summary("benchmark_results/summary_20260209_142430.csv")

# Deep dive into specific problem  
analyze_problem_details("benchmark_results/detailed_20260209_142430.json", "bifeedb1")

# Compare multiple runs
compare_runs(
    "benchmark_results/summary_20260209_120000.csv",
    "benchmark_results/summary_20260209_140000.csv"
)
```

## Output Files

### CSV Summary (`summary_TIMESTAMP.csv`)

One row per problem with columns:
- `problem_name`: Problem identifier
- `success`: Boolean - whether discovery succeeded
- `n_states`: Number of state variables
- `n_equations_correct`: Equations with R² > 0.9
- `n_equations_total`: Total equations in system
- `avg_r2`: Average R² across all equations
- `integration_loss`: Final integration loss
- `initial_loss`: Loss before refinement
- `discovery_time`: Time in seconds
- `has_error`: Boolean - whether an error occurred
- `error_type`: Type of error if failed

**Best for:** Quick filtering, sorting, statistics, Excel/Python analysis

### JSON Details (`detailed_TIMESTAMP.json`)

Complete nested structure including:
- All fields from CSV
- Ground truth equations (strings)
- Discovered equations (strings) 
- Initial equations before refinement
- Per-equation similarity scores:
  - `r2`: Coefficient of determination
  - `rmse`: Root mean squared error
  - `nrmse`: Normalized RMSE
  - `mae`: Mean absolute error
  - `max_error`: Maximum error
  - `valid_samples`: Number of valid test points

**Best for:** Deep analysis, debugging specific problems, complete audit trail

### Text Report (`results_TIMESTAMP.txt`)

Human-readable format showing:
- Summary statistics
- Per-problem results
- Equations side-by-side
- Error details

**Best for:** Quick review, sharing results, debugging

## Analysis Functions

### `analyze_benchmark_summary(csv_file)`

Comprehensive statistical analysis including:
- ✅ Overall success rate
- 🎯 Equation recovery rate (R² > 0.9)
- ⏱️ Performance metrics (time, loss)
- ❌ Failure analysis by error type
- 📈 Success rate by problem size
- 🏆 Top 5 best matches

**Example output:**
```
📊 Overall Results:
  Total problems: 50
  ✓ Successful: 42 (84.0%)
  ✗ Failed: 8 (16.0%)

🎯 Equation Recovery (successful problems only):
  Total equations: 168
  Correctly recovered (R² > 0.9): 112 (66.7%)
  Average R² across all equations: 0.752
  Perfect recovery (all equations): 28 / 42 problems (66.7%)

⏱️  Performance:
  Avg discovery time: 45.3s
  Avg integration loss: 2.45e-03
```

### `analyze_problem_details(json_file, problem_name)`

Detailed analysis of a single problem:
- 📋 Basic info (time, loss, states)
- 📐 Ground truth equations
- 🔍 Discovered equations (initial & final)
- 🎯 Per-equation similarity metrics
- Match quality assessment

**Example output:**
```
Equation 1: ✓ Excellent
  R² = 0.999891
  RMSE = 3.45e-03
  NRMSE = 0.0124
  Match: Excellent

Equation 2: ✗ Poor
  R² = -1.148075
  RMSE = 1.11e+01
  Match: Poor
```

### `compare_runs(csv_files...)`

Side-by-side comparison of multiple benchmark runs:
- Success rates
- Equation recovery rates
- Performance metrics

**Use cases:**
- Compare different hyperparameters
- Track improvements over time
- A/B test algorithm changes

## Metrics Explained

### R² (Coefficient of Determination)
- **1.0**: Perfect match
- **> 0.99**: Excellent recovery (✓)
- **> 0.9**: Good recovery (✓)
- **> 0.7**: Fair recovery (~)
- **< 0.7**: Poor match (✗)
- **< 0**: Worse than constant prediction

### NRMSE (Normalized Root Mean Squared Error)
- Normalized by standard deviation of ground truth
- **< 0.1**: Very good
- **< 0.5**: Acceptable
- **> 1.0**: Poor

### Success Criteria
A problem is "successful" if `integration_loss < 1.0`

An equation is "correctly recovered" if `R² > 0.9`

## Example Workflow

```julia
# 1. Run benchmarks
include("benchmark/benchmark.jl")

# 2. Analyze latest results
include("benchmark/analyze_results.jl")

# Find the latest files
using Dates
latest = sort(readdir("benchmark_results"))[end]
timestamp = split(latest, "_")[2:3] |> join("_") |> x -> split(x, ".")[1]

# 3. Get overview
df = analyze_benchmark_summary("benchmark_results/summary_$timestamp.csv")

# 4. Find best and worst performers
sort!(df, :avg_r2, rev=true)
println("Best: ", df[1, :problem_name])
println("Worst: ", df[end, :problem_name])

# 5. Deep dive into failures
failures = df[df.success .== false, :]
for row in eachrow(failures)
    analyze_problem_details(
        "benchmark_results/detailed_$timestamp.json",
        row.problem_name
    )
end

# 6. Export subset for further analysis
using CSV
CSV.write("my_analysis.csv", df[df.n_states .== 4, :])
```

## Tips

- **Keep old results**: CSV files are small, great for tracking progress
- **Use DataFrames.jl**: Load CSV and use powerful filtering/grouping
- **Compare runs**: Track how changes affect performance
- **Filter by size**: Analyze 2-state vs 4-state problems separately
- **Python integration**: CSV files work great with pandas

## Customization

Modify thresholds in `analyze_results.jl`:
```julia
# Change "correct" threshold (default: R² > 0.9)
n_good_equations = count(r2 -> r2 > 0.95, r2_values)  # Stricter

# Change match quality ranges
if r2 > 0.99
    "Excellent"
elseif r2 > 0.85  # Changed from 0.9
    "Good"
```
