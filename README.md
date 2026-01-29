# ODESymbolicRegression.jl

Discover ordinary differential equations from time-series data using symbolic regression.

## Overview

This package implements a two-stage approach for ODE discovery:

1. **Derivative Estimation**: Use symbolic regression to find dx/dt from numerical derivatives
2. **Integration Refinement**: Refine equations by solving ODEs and comparing integrated solutions with observations

## Features

- 🔍 **Automatic ODE Discovery**: Learn differential equations directly from time-series data
- 🎯 **Multi-trajectory Evaluation**: Use multiple initial conditions to ensure generalization
- 🔄 **Iterative Refinement**: Improve equations through integration-based residual learning
- 📊 **Comprehensive Benchmarks**: 63 benchmark problems from systems biology literature
- 🎨 **Equation Normalization**: Automatic simplification and formatting of discovered equations

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/YourUsername/ODESymbolicRegression.jl")
```

## Quick Start

```julia
using ODESymbolicRegression

# Your time series data
t = 0.0:0.01:10.0
X = [...] # State variables (n_timepoints × n_states)

# Create experiment
experiment = Dict(
    :t => t,
    :X => X
)

# Configure options
options = ODERegressionOptions(
    niterations_derivative=100,
    niterations_integration=20,
    complexity_derivative=20,
    complexity_integration=15,
    binary_operators=(+, -, *, /),
    unary_operators=(square,),
    verbose=true
)

# Discover ODE system
result = discover_ode_system([experiment]; ode_options=options)

# Print discovered equations
for (i, tree) in enumerate(result.best_trees)
    println("x$i' = ", string_tree(tree, options))
end
```

## Key Concepts

### Two-Stage Discovery Process

**Stage 1: Derivative-Based Symbolic Regression**
- Compute numerical derivatives using Savitzky-Golay filtering
- Run symbolic regression on dx/dt ≈ f(x) for each state variable
- Generate candidate equations (Pareto frontier of complexity vs. accuracy)

**Stage 2: Integration-Based Refinement**
- Find best combination of candidate equations by integrating and comparing to data
- Iteratively refine each equation using integration residuals
- Return final ODE system with lowest integration loss

### Multi-Trajectory Evaluation

Provide multiple trajectories with different initial conditions to:
- Ensure discovered equations generalize beyond a single trajectory
- Avoid overfitting to specific initial states
- Improve robustness of discovered systems

```julia
experiments = [
    Dict(:t => t1, :X => X1),  # Trajectory 1
    Dict(:t => t2, :X => X2),  # Trajectory 2
    Dict(:t => t3, :X => X3),  # Trajectory 3
]

result = discover_ode_system(experiments; ode_options=options)
```

## Configuration Options

```julia
ODERegressionOptions(;
    # Iteration counts
    niterations_derivative=100,      # SR iterations for derivative stage
    niterations_integration=20,      # SR iterations for integration refinement
    
    # Complexity limits
    complexity_derivative=20,        # Max complexity for derivative stage
    complexity_integration=15,       # Max complexity for integration stage
    
    # Operators
    binary_operators=(+, -, *, /),   # Binary operators
    unary_operators=(square,),       # Unary operators
    
    # Numerical settings
    savgol_window=11,                # Savitzky-Golay filter window
    savgol_poly=3,                   # Savitzky-Golay polynomial order
    
    # Execution
    parallelism=:multithreading,     # or :serial
    verbose=true,                    # Print progress
    seed=0                           # Random seed
)
```

## Benchmarks

The package includes 63 benchmark problems from systems biology:

```julia
# Run single benchmark
include("benchmark/benchmark_ode_discovery.jl")
result = benchmark_single_problem("simpleLin1"; num_trajectories=3)

# Run full benchmark suite
include("benchmark/benchmark.jl")
# Edit MAX_PROBLEMS_TO_TEST and run
```

### Benchmark Categories

- **Simple Linear**: Linear systems for validation
- **Oscillators**: Limit cycle dynamics (chemical reactions)
- **Metabolic**: Metabolic pathway models
- **Gene Regulation**: Genetic regulatory networks
- **S-Systems**: Power-law formulations
- **GMA Systems**: Generalized mass action models

## Documentation

See the `docs/` directory for detailed guides:

- [Equation Comparison Guide](docs/EQUATION_COMPARISON_GUIDE.md) - Strategies for validating discovered equations
- [Normalization Implementation](docs/NORMALIZATION_IMPLEMENTATION.md) - How equation normalization works
- [ODE Discovery README](docs/ODE_DISCOVERY_README.md) - Original implementation notes
- [Implementation Summary](docs/IMPLEMENTATION_SUMMARY.txt) - Complete implementation details

## Project Structure

```
ODESymbolicRegression.jl/
├── src/
│   ├── ODESymbolicRegression.jl     # Main module
│   └── SymbolicRegressionODE.jl     # Core implementation
├── benchmark/
│   ├── benchmarkProblems/           # 63 benchmark systems
│   ├── benchmark.jl                 # Main benchmark runner
│   ├── benchmark_ode_discovery.jl   # Single problem testing
│   └── benchmark_reporting.jl       # Results formatting
├── test/
│   ├── test_multi_trajectory.jl     # Multi-IC tests
│   └── ...
├── examples/
│   ├── example_ode_discovery.jl     # Basic example
│   └── test_normalization.jl        # Normalization examples
└── docs/                            # Documentation
```

## Requirements

- Julia ≥ 1.10
- SymbolicRegression.jl v2.x
- DifferentialEquations.jl v7.x
- SymbolicUtils.jl, Symbolics.jl

## Citation

If you use this package in your research, please cite:

```bibtex
@software{odesymbolicregression2026,
  author = {Your Name},
  title = {ODESymbolicRegression.jl: Discovering ODEs from Time-Series Data},
  year = {2026},
  url = {https://github.com/YourUsername/ODESymbolicRegression.jl}
}
```

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## Related Work

This implementation builds on:
- [SymbolicRegression.jl](https://github.com/MilesCranmer/SymbolicRegression.jl) - Symbolic regression framework
- [SINDy](https://www.pnas.org/doi/10.1073/pnas.1517384113) - Sparse identification of nonlinear dynamics
- [PySINDy](https://github.com/dynamicslab/pysindy) - Python implementation

## Contact

- Issues: https://github.com/YourUsername/ODESymbolicRegression.jl/issues
- Discussions: https://github.com/YourUsername/ODESymbolicRegression.jl/discussions
