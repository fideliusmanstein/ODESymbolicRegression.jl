# Unified Benchmark Problem Architecture - Implementation Plan

## Overview

This document describes the unified class architecture for all benchmark ODE problems.

## Design Principles

1. **Single Source of Truth**: Each problem defined once with tree representation
2. **Consistent API**: All problems share the same interface
3. **Programmatic Access**: Trees enable automated analysis and comparison
4. **Flexible Generation**: Easy to create experiments with varying parameters
5. **Backward Compatible**: Existing code continues to work

## Architecture

### Base Class: `BenchmarkProblem`

Located in: `benchmark/benchmarkProblems/BaseProblem.jl`

**Core Properties:**
- `name::String` - Problem identifier
- `n_states::Int` - Number of state variables
- `n_inputs::Int` - Number of input variables  
- `tree_equations::Vector{Node}` - Expression trees for ODEs
- `parameter_values::Dict{Symbol,Float64}` - Parameter values
- `default_ic::Vector{Float64}` - Default initial conditions
- `default_tspan::Tuple{Float64,Float64}` - Default time span
- `default_n_points::Int` - Default number of time points
- `default_noise::Float64` - Default noise level
- `experiment_configs::Vector{NamedTuple}` - Experiment parameter sets

**Core Methods:**
- `generate_data(problem; kwargs...)` - Generate single trajectory
- `generate_experiments(problem; num_trajectories=1, ...)` - Generate multiple experiments
- `get_tree_equations(problem)` - Get expression trees
- `get_equation_strings(problem; format=:text)` - Get string representations
- `problem_info(problem)` - Get metadata
- `evaluate_system(problem, X, inputs, t)` - Evaluate ODE system (must implement)
- `generate_varied_ic(problem, base_ic)` - Generate varied ICs (must implement)

### Tree Builder Utilities

Located in: `benchmark/benchmarkProblems/TreeBuilder.jl`

**Purpose**: Simplify tree construction with intuitive syntax

**Core Functions:**
- `var(i)` - Create variable node
- `const_val(v)` - Create constant node
- Overloaded operators: `+`, `-`, `*`, `/`, `^`
- Helper functions:
  - `michaelis_menten(substrate, vmax, km)` - MM kinetics
  - `hill_minus(x, k)` - Hill inhibition
  - `hill_plus(x, k)` - Hill activation
  - `hill_power(x, k, n)` - Cooperative Hill

## Implementation Status

### ✅ Completed

1. **Base Architecture**
   - [x] BaseProblem.jl - Abstract base class
   - [x] TreeBuilder.jl - Tree construction utilities
   - [x] SimpleLinProblem.jl - Example implementation

2. **Core Functionality**
   - [x] generate_data() with flexible parameters
   - [x] generate_experiments() with num_trajectories support
   - [x] get_tree_equations() for programmatic access
   - [x] get_equation_strings() with multiple formats

### 🚧 In Progress

3. **Additional Problem Implementations**
   - [ ] SimpleFbProblem.jl
   - [ ] OscProblem.jl
   - [ ] MetabolProblem.jl
   - [ ] FeedfProblem.jl
   - [ ] InhoscProblem.jl
   - [ ] BifeedbProblem.jl
   - [ ] ThreeGenesProblem.jl

4. **S-System Problems**
   - [ ] SsCascadeProblem.jl
   - [ ] SsBranchProblem.jl
   - [ ] Ss5genesProblem.jl
   - [ ] Ss15genesProblem.jl
   - [ ] Ss30genesProblem.jl
   - [ ] SsFeedfProblem.jl
   - [ ] SsInhoscProblem.jl
   - [ ] SsBifeedbProblem.jl

5. **GMA Problems**
   - [ ] GmaFeedfProblem.jl
   - [ ] GmaInhoscProblem.jl
   - [ ] GmaBifeedbProblem.jl

6. **Real Biological Problems**
   - [ ] CytokineProblem.jl
   - [ ] SsEthanolfermProblem.jl
   - [ ] SsSosrepairProblem.jl
   - [ ] SsCadBAProblem.jl
   - [ ] SsClockProblem.jl

### 📋 TODO

7. **Integration & Testing**
   - [ ] Update BenchmarkSystems.jl to use new architecture
   - [ ] Backward compatibility layer for old API
   - [ ] Unit tests for each problem
   - [ ] Integration tests for full pipeline
   - [ ] Performance benchmarks

8. **Documentation**
   - [ ] API documentation
   - [ ] Migration guide
   - [ ] Examples using new API

## Example Usage

### Creating a Problem

```julia
using BenchmarkProblems

# Create problem instance
problem = SimpleLin1()

# Get problem info
info = problem_info(problem)
println("Problem: $(info[:name])")
println("States: $(info[:n_states]), Inputs: $(info[:n_inputs])")

# Access equation trees
trees = get_tree_equations(problem)
println("Number of equations: $(length(trees))")

# Get equation strings
eqs = get_equation_strings(problem, format=:text)
for (i, eq) in enumerate(eqs)
    println("Equation $i: $eq")
end
```

### Generating Data

```julia
# Generate single experiment with default settings
t, X, inputs = generate_data(problem)

# Generate with custom parameters
t, X, inputs = generate_data(
    problem;
    X0=[0.5, 0.3, 0.2],
    tspan=(0.0, 5.0),
    n_points=50,
    noise_std=0.05,
    input_values=Dict(:X1 => 4.0, :X2 => 3.0)
)

# Generate with time-varying inputs
t, X, inputs = generate_data(
    problem;
    input_values=Dict(
        :X1 => t -> 3.0 * sin(t),
        :X2 => t -> 2.0 + 0.5 * t
    )
)
```

### Generating Experiments

```julia
# Generate all 8 experiments with default settings
experiments = generate_experiments(problem)

# Generate with multiple trajectories per experiment
experiments = generate_experiments(
    problem;
    num_trajectories=3,
    noise_std=0.1,
    n_points=20
)

# Result: 8 experiments × 3 trajectories = 24 total
println("Total experiments: $(length(experiments))")

# Access experiment data
exp = experiments[1]
println("Experiment: $(exp[:experiment]), Trajectory: $(exp[:trajectory])")
println("Initial conditions: $(exp[:ic])")
println("Parameters: $(exp[:params])")
```

### Using Trees for Analysis

```julia
# Get trees
trees = get_tree_equations(problem)

# Evaluate tree at a point
options = SymbolicRegression.Options(
    binary_operators=(+, -, *, /),
    unary_operators=()
)

# X = [X3, X4, X5, X1_input, X2_input]
X = [0.5, 0.3, 0.2, 3.0, 2.0]
result = eval_tree_array(trees[1], X, options)

# Convert tree to string
eq_str = string_tree(trees[1], options)
println("Equation 1: $eq_str")
```

## Migration Path

### Phase 1: Parallel Development (Current)
- New architecture coexists with old code
- Implement new problems alongside existing ones
- Test thoroughly with existing benchmarks

### Phase 2: Gradual Migration
- Update BenchmarkSystems.jl to support both APIs
- Add deprecation warnings to old functions
- Update documentation and examples

### Phase 3: Full Adoption
- Remove old problem implementations
- Clean up deprecated code
- Final performance optimization

## Benefits

1. **Consistency**: All problems follow same pattern
2. **Maintainability**: Single source of truth for equations
3. **Flexibility**: Easy to add new problems or modify existing ones
4. **Analysis**: Trees enable automated equation comparison
5. **Testing**: Unified interface simplifies testing
6. **Documentation**: Self-documenting through tree representation

## Next Steps

1. Review the prototype (SimpleLin Problem)
2. Implement remaining Chemical Rate problems
3. Create comprehensive test suite
4. Update BenchmarkSystems.jl loader
5. Write migration guide and examples
