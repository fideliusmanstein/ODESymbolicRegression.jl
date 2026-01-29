# Benchmark Systems for Symbolic Regression

This directory contains Julia implementations of standard benchmark differential equation systems for testing symbolic regression and equation discovery algorithms.

Based on: https://www.cse.chalmers.se/~dag/identification/Benchmarks/

## Overview

**Total: 63+ implemented benchmark problems** across 4 main categories:
- **Chemical Rate Equations** (19 problems): Direct chemical kinetics models
- **S-Systems** (28 problems): Power-law approximations of biochemical systems
- **GMA Models** (6 problems): Generalized Mass Action formalism
- **Real Biological Data** (10 problems): Based on actual experimental data

## Available Systems

### 1. **simpleLin** - Simple Linear Metabolic Pathway
- **States**: 3 (X3, X4, X5)
- **Inputs**: 2 (X1, X2)
- **Equations**: Linear ODEs with multiplicative input terms
- **Problems**: 
  - `simpleLin1`: 3 experiments, 13 points, 0% noise
  - `simpleLin2`: 8 experiments, 13 points, 10% noise

### 2. **simpleFb** - Simple Feedback System
- **States**: 3 (X1, X2, X3)
- **Inputs**: None
- **Equations**: Nonlinear feedback with Hill functions
- **Problems**:
  - `simpleFb1`: 4 experiments, 7 points, 0% noise
  - `simpleFb2`: 4 experiments, 7 points, 5% noise
  - `simpleFb3`: 1 experiment, 7 points, 0% noise (sparse)
  - `simpleFb4`: 1 experiment, 7 points, ~5% noise (sparse)

### 3. **osc** - Oscillator System
- **States**: 3 (X1, X2, X3)
- **Inputs**: None
- **Equations**: Nonlinear oscillating system
- **Problems**:
  - `osc1`: 1 experiment, 41 points, 0% noise
  - `osc2`: 1 experiment, 41 points, 3% noise

### 4. **metabol** - Metabolic Pathway (Michaelis-Menten)
- **States**: 5 (X3, X4, X5, X6, X7)
- **Inputs**: 2 (X1, X2)
- **Equations**: Michaelis-Menten kinetics with non-competitive inhibition
- **Problems**:
  - `metabol1`: 12 experiments, 7 points, 0% noise
  - `metabol2`: 12 experiments, 21 points, 10% noise
  - `metabol3`: 12 experiments, 21 points, 20% noise

### 5. **threeGenes** - Gene Network (3 genes)
- **States**: 8 (G1, G2, G3, E1, E2, E3, M1, M2)
- **Inputs**: 2 (S=M0, P=M3)
- **Equations**: Gene regulatory network with Hill-like regulation
- **Problems**:
  - `threeGenes1`: 16 experiments, 21 points, 0% noise
  - `threeGenes2`: 16 experiments, 21 points, 5% noise

### 6. **feedf** - Feed-Forward Pathway
- **States**: 4 (X1, X2, X3, X4)
- **Inputs**: 2 (In1, In2)
- **Equations**: Michaelis-Menten reactions in series
- **Problems**:
  - `feedf1`: 16 experiments, 51 points, 0% noise
  - `feedf2`: 16 experiments, 51 points, 5% noise

### 7. **inhosc** - Inhibitory Oscillator
- **States**: 2 or 4 (X1, X2, [X3, X4])
- **Inputs**: 2 (In, Out)
- **Equations**: Inhibitory feedback oscillator
- **Problems**:
  - `inhosc1`: 4 experiments, 51 points, 0% noise (2-state)
  - `inhosc2`: 4 experiments, 51 points, 3% noise (4-state)

### 8. **bifeedb** - Bi-Molecular Feedback
- **States**: 4 or 5 (X1, X2, X3, X4, [X5])
- **Inputs**: None
- **Equations**: Bi-molecular reactions (X²) with feedback
- **Problems**:
  - `bifeedb1`: 16 experiments, 51 points, 0% noise (4-state)
  - `bifeedb2`: 16 experiments, 51 points, 5% noise (5-state)

## Usage

### Quick Start - Load a Benchmark Problem

```julia
include("benchmarkProblems/BenchmarkSystems.jl")
using .BenchmarkSystems

# List all available problems
problems = BenchmarkSystems.list_problems()

# Get info about a specific problem
BenchmarkSystems.problem_info("simpleLin2")

# Load a problem
experiments = BenchmarkSystems.load_problem("simpleLin2")

# Access data from first experiment
t = experiments[1][:t]        # Time points
X = experiments[1][:X]        # State variables (n_points × n_states)
inputs = experiments[1][:inputs]  # Input values (if applicable)
```

### Using Individual Modules

```julia
# Load specific module
include("benchmarkProblems/simpleLin.jl")
using .SimpleLinModule

# Generate custom data
t, X, inputs = SimpleLinModule.generate_simplelin_data(
    X1_const=3.0,
    X2_const=2.0,
    X3_0=1.0,
    X4_0=0.0,
    X5_0=0.0,
    noise_std=0.1
)

# Or load standard experiments
experiments = SimpleLinModule.generate_simplelin_experiments(noise_std=0.1)
```

### Example: Test Symbolic Regression

```julia
include("benchmarkProblems/BenchmarkSystems.jl")
using .BenchmarkSystems
using SymbolicRegression

# Load benchmark data
experiments = BenchmarkSystems.load_problem("simpleFb1")

# Extract data from first experiment
t = experiments[1][:t]
X = experiments[1][:X]

# Prepare for symbolic regression
# X has shape (n_points, n_states)
# Create feature matrix [t, X1, X2, X3]
features = hcat(t, X)  # (n_points × 4)

# Search for equation for state X1 (dX1/dt)
# ... use your symbolic regression code here ...
```

## System Equations

### simpleLin
```
X3'(t) = -k1·X3(t) + k2·X1(t)·X4(t)
X4'(t) = k1·X3(t) - k2·X1(t)·X4(t) + k3·X5(t) - k4·X2(t)·X4(t)
X5'(t) = -k3·X5(t) + k4·X2(t)·X4(t)
```
Conservation: X3 + X4 + X5 = constant

### simpleFb
```
X1'(t) = k1·h⁻(X3,k2) - k3·X1(t)
X2'(t) = k4·X1(t) - k5·X2(t)
X3'(t) = k6·X2(t) - k7·X3(t)
```
where h⁻(Xi,kj) = kj / (Xi + kj)

### osc
```
X1'(t) = k1·X2(t)
X2'(t) = -k2·X1(t) + k3·X2(t) - k4·X2(t)·X3(t)
X3'(t) = k5·X1(t)² - k6·X3(t)
```

### metabol
```
X3'(t) = -v1 - v2 + v3 + v4
X4'(t) = v1 - v3
X5'(t) = v2 - v4
X6'(t) = v5 - v6
X7'(t) = -v5 + v6
```
where v1...v6 are Michaelis-Menten reaction rates (see metabol.jl for details)

### threeGenes
```
Gi'(t) = VGi / (1+(P/KIi)^ni+(KAi/Mi-1)^mi) - kGi·Gi
Ei'(t) = VEi·Gi / (KEi+Gi) - kEi·Ei
Mi'(t) = kM1i·Ei·... (see threeGenes.jl for full details)
```
Gene network with N=3 genes, 3 enzymes, 2 metabolites

### feedf
```
X1'(t) = In1 - k1·X1/(X1+k2)
X2'(t) = In2 - k3·X2/(X2+k4)
X3'(t) = k5·X1/(X1+k6) + k7·X2/(X2+k8) - k9·X3/(X3+k10)
X4'(t) = k11·X3/(X3+k12) - k13·X4/(X4+k14)
```
Feed-forward pathway with Michaelis-Menten kinetics

### inhosc
2-state version:
```
X1'(t) = In - k1/(X2+k2)
X2'(t) = k3/(X1+k4) - Out
```
4-state version adds intermediate inhibitory steps

### bifeedb
4-state version:
```
X1'(t) = k1/(X3+k2) - k3·X1²
X2'(t) = k5·X1² - k7·X2/(X2+k8)
X3'(t) = k9·X2/(X2+k10) - k11·X3/(X3+k12)
X4'(t) = k13·X3/(X3+k14) - k15·X4/(X4+k16)
```
5-state version adds one more state with similar kinetics

## File Structure

```
benchmarkProblems/
├── BenchmarkSystems.jl                 # Main unified interface module
├── ChemicalRateProblems/               # Chemical rate equation systems (19 problems)
│   ├── simpleLin.jl                    # Simple linear pathway
│   ├── simpleFb.jl                     # Feedback system
│   ├── osc.jl                          # Oscillator
│   ├── metabol.jl                      # Metabolic pathway
│   ├── threeGenes.jl                   # Gene network (N=3)
│   ├── feedf.jl                        # Feed-forward pathway
│   ├── inhosc.jl                       # Inhibitory oscillator
│   └── bifeedb.jl                      # Bi-molecular feedback
├── SSystemProblems/                    # S-system models (28 problems)
│   ├── SSystemBase.jl                  # Base S-system ODE solver
│   ├── ss_cascade.jl                   # Cascade pathway (3 problems)
│   ├── ss_branch.jl                    # Branched pathway (6 problems)
│   ├── ss_5genes.jl                    # 5-gene network (8 problems)
│   ├── ss_15genes.jl                   # 15-gene network (2 problems)
│   ├── ss_30genes.jl                   # 30-gene network (3 problems)
│   ├── ss_feedf.jl                     # S-system feedf (2 problems)
│   ├── ss_inhosc.jl                    # S-system inhosc (2 problems)
│   └── ss_bifeedb.jl                   # S-system bifeedb (2 problems)
├── GMAProblems/                        # GMA models (6 problems)
│   ├── GMABase.jl                      # Base GMA ODE solver
│   └── gma_problems.jl                 # All GMA variants
├── RealBiologicalProblems/             # Real biological data (10 problems)
│   └── biological_problems.jl          # cytokine, ethanolferm, etc.
├── ParameterEstimationProblems/        # Parameter estimation variants
│   └── README.md                       # Documentation (pe_* problems)
├── test_benchmarks.jl                  # Test suite
└── README.md                           # This file
```

## References

- Gennemark, P., & Wedelin, D. (2007). Efficient algorithms for ordinary differential equation model identification of biological systems. IET Systems Biology, 1(2), 120-129.
- McKinney, B. A., et al. (2006). Hybrid grammar-based approach to nonlinear dynamical system identification from biological time series. Physical Review E, 73(2).
- Karnaukhov, A. V., et al. (2007). Numerical Matrices Method for nonlinear system identification. Biophysical Journal, 92(10), 3459-3473.
- Arkin, A. P., & Ross, J. (1995). Statistical construction of chemical reaction mechanisms from measured time-series. Journal of Physical Chemistry, 99(3), 970-979.

## Adding More Benchmark Systems

To add additional benchmark systems from the Chalmers database:

1. Create a new file `systemName.jl` in this directory
2. Define a module with:
   - `systemname_system()` function with the ODE equations
   - `generate_systemname_data()` for custom data generation
   - `generate_systemname_experiments()` for standard benchmark problems
3. Add the system to `BenchmarkSystems.jl`:
   - Include the file
   - Add to `list_problems()`
   - Add case to `load_problem()`

See existing files for examples.
