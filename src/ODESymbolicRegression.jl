"""
ODESymbolicRegression.jl

Main module for discovering ordinary differential equations from time-series data
using symbolic regression.

This package implements a two-stage approach:
1. Derivative Estimation: Use symbolic regression to find dx/dt from numerical derivatives
2. Integration Refinement: Refine equations by solving ODEs and comparing integrated solutions

# Example
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
    complexity_integration=15
)

# Discover ODE system
result = discover_ode_system([experiment]; ode_options=options)
```
"""
module ODESymbolicRegression

# Re-export the main module
include("SymbolicRegressionODE.jl")
using .SymbolicRegressionODE

export ODERegressionOptions, discover_ode_system, IntegrationLoss, create_feature_matrix

end # module
