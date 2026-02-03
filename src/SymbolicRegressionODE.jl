"""
SymbolicRegressionODE.jl

Symbolic regression for discovering differential equations from time-series data.

This module implements a two-stage approach:
1. Derivative Estimation: Use symbolic regression to find dx/dt from numerical derivatives
2. Integration Refinement: Refine equations by solving ODEs and comparing integrated solutions

Compatible with benchmark problems from benchmarkProblems/BenchmarkSystems.jl

File structure:
- helpers.jl: Shared utility functions
- options.jl: Configuration structures
- differentiation.jl: Numerical differentiation methods
- stage1_derivatives.jl: Stage 1 derivative discovery
- integration_loss.jl: Integration-based loss evaluation
- stage2_refinement.jl: Stage 2 refinement with integration
- discovery.jl: Main discovery orchestration
"""

module SymbolicRegressionODE

using DifferentialEquations
using SymbolicRegression
using Interpolations
using Logging
using SavitzkyGolay
using SymbolicUtils
using Symbolics

# Include submodules in dependency order
include("helpers.jl")
include("options.jl")
include("differentiation.jl")
include("stage1_derivatives.jl")
include("integration_loss.jl")
include("stage2_refinement.jl")
include("discovery.jl")

# Export public API
export ODERegressionOptions, discover_ode_system, IntegrationLoss, create_feature_matrix

end # module
