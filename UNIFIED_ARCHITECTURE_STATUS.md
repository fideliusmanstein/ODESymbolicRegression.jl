# Unified Problem Architecture - Implementation Status

## Overview

Successfully implemented unified problem architecture for ODESymbolicRegression.jl benchmarks. The new architecture uses abstract base classes, expression trees, and standardized interfaces.

## Completed Work (8 Problem Variants)

### ✅ SimpleLin Problems (2 variants)
- **simpleLin1**: Basic linear pathway (noise_std=0.0)
- **simpleLin2**: With noise (noise_std=0.1)
- **Features**:
  - 3 states (X3, X4, X5)
  - 2 inputs (X1, X2)
  - 8 experiments with conservation law (X3+X4+X5=1.0)
  - Full num_trajectories support
  - Expression trees using parse_expression()

### ✅ SimpleFb Problems (4 variants)
- **simpleFb1**: 4 experiments, no noise
- **simpleFb2**: 4 experiments, noise_std=0.05
- **simpleFb3**: 1 experiment, no noise
- **simpleFb4**: 1 experiment, noise_std=0.05
- **Features**:
  - 3 states (X1, X2, X3)
  - Hill inhibition function: h⁻(X3,k2) = k2/(X3+k2)
  - Expression trees with parse_expression()

### ✅ Osc Problems (2 variants)
- **osc1**: Oscillator without noise
- **osc2**: Oscillator with noise_std=0.03
- **Features**:
  - 3 states (X1, X2, X3)
  - Power operator: x^2
  - Single experiment with multiple trajectories

## Core Infrastructure

### BaseProblem.jl
- Abstract `BenchmarkProblem` base class
- Standard interface functions:
  - `generate_data()`: Single trajectory generation
  - `generate_experiments()`: Multiple experiments/trajectories
  - `get_tree_equations()`: Expression tree access
  - `get_equation_strings()`: Human-readable equations
  - `problem_info()`: Metadata retrieval
- Helper utilities:
  - `generate_random_ic_unit_sum()`: Conservation law ICs
  - `add_gaussian_noise!()`: Noise injection

### UnifiedBenchmarkSystems.jl
- Central loader module
- Functions:
  - `load_problem_unified(name; num_trajectories=1)`: Load and generate
  - `list_problems_unified()`: List available problems
  - `get_problem_trees(name)`: Get expression trees
- Backward compatibility with existing code

### Test Suite
- **test_all_unified_problems.jl**: Comprehensive testing
- Tests:
  - Single trajectory generation
  - Multiple trajectories (num_trajectories parameter)
  - Expression tree construction
  - Conservation law enforcement
  - Data shape validation
- **Result**: 9/9 tests passing ✅

## Technical Solutions

### Key Fixes
1. **Adjoint Type Issue**: Fixed by using `collect(hcat(sol.u...)')` instead of `hcat(sol.u...')`
2. **Type Annotations**: Simplified Dict parameter types to avoid type conflicts
3. **Module Organization**: Proper include order to avoid duplicate definitions
4. **Expression Trees**: Using `parse_expression()` from SymbolicRegression.jl

### Tree Construction Pattern
```julia
var_names = ["x1", "x2", "x3", ...]
binary_ops = [+, -, *, /]
unary_ops = Function[]

eq_str = "-1.0*x1 + 1.0*x4*x2"
tree = parse_expression(eq_str; 
    binary_operators=binary_ops,
    unary_operators=unary_ops,
    variable_names=var_names)
```

## Remaining Work

### Chemical Rate Problems (5 remaining)
- [ ] Metabol (5 states, 2 inputs, Michaelis-Menten)
- [ ] Feedf (4 states, 2 inputs)
- [ ] Inhosc (2-4 states, 2 inputs, variable)
- [ ] Bifeedb (4-5 states, variable)
- [ ] ThreeGenes (8 states, 2 inputs)

### S-System Problems (8 total)
- [ ] SsCascade
- [ ] SsBranch
- [ ] Ss5genes
- [ ] Ss15genes
- [ ] Ss30genes
- [ ] SsFeedf
- [ ] SsInhosc
- [ ] SsBifeedb

### GMA Problems (3 total)
- [ ] GmaFeedf
- [ ] GmaInhosc
- [ ] GmaBifeedb

### Real Biological Problems (5 total)
- [ ] Cytokine
- [ ] SsEthanolferm
- [ ] SsSosrepair
- [ ] SsCadBA
- [ ] SsClock

## Implementation Pattern

Each new problem follows this structure:

1. **Create Problem File** (e.g., `MetabolProblem.jl`)
   ```julia
   module MetabolProblemModule
   using DifferentialEquations
   using SymbolicRegression
   using ..BaseProblemModule
   
   struct MetabolProblem <: BenchmarkProblem
       # ... fields ...
   end
   
   # Implement: evaluate_system, generate_data, generate_experiments
   end
   ```

2. **Add to UnifiedBenchmarkSystems.jl**
   ```julia
   include("MetabolProblem.jl")
   using .MetabolProblemModule
   
   # Add to load_problem_unified()
   # Add to list_problems_unified()
   ```

3. **Add Tests** to `test_all_unified_problems.jl`

## Performance

- All problems generate data correctly
- num_trajectories works across all variants
- Conservation laws properly enforced
- Expression trees built correctly
- No performance regressions

## Git Status

**Branch**: `unified-problem-architecture`
**Commits**: 2 commits pushed
**Files Added**: 7 new files
  - BaseProblem.jl
  - SimpleLinProblem.jl
  - SimpleFbProblem.jl
  - OscProblem.jl
  - UnifiedBenchmarkSystems.jl
  - test_all_unified_problems.jl
  - TreeBuilder.jl (deprecated, use parse_expression instead)

**Test Results**: ✅ 9/9 passing

## Next Steps

1. Implement remaining Chemical Rate problems (Metabol, Feedf, Inhosc, Bifeedb, ThreeGenes)
2. Implement S-System problems (8 problems)
3. Implement GMA problems (3 problems)
4. Implement Real Biological problems (5 problems)
5. Update main BenchmarkSystems.jl to delegate to unified architecture
6. Comprehensive integration testing
7. Documentation updates
8. Merge to main branch

## References

- Original bug fix: num_trajectories in BenchmarkSystems.jl line 485-495
- Expression tree construction: `parse_expression()` from SymbolicRegression.jl
- Conservation law: `generate_random_ic_unit_sum()` for simpleLin problems
