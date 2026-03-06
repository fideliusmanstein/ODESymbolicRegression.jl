"""
simpleLin.jl

Implementation of simpleLin benchmark differential equation system for testing symbolic regression.
Based on: https://www.cse.chalmers.se/~dag/identification/Benchmarks/simpleLin.html

This system is designed to test equation discovery algorithms on a standard test case
with known ground truth equations.
"""

module SimpleLinModule

using DifferentialEquations

export simplelin_system, generate_simplelin_data, get_equation_strings

"""
    simplelin_system(X, inputs, t)

Simple linear metabolic pathway benchmark system.

This system models a simplified metabolic pathway with:
- 2 input variables: X1(t), X2(t)
- 3 state variables: X3(t), X4(t), X5(t)

The system equations are:
    X3'(t) = -k1·X3(t) + k2·X1(t)·X4(t)
    X4'(t) = k1·X3(t) - k2·X1(t)·X4(t) + k3·X5(t) - k4·X2(t)·X4(t)
    X5'(t) = -k3·X5(t) + k4·X2(t)·X4(t)

Conservation law: X3(t) + X4(t) + X5(t) = constant

Parameters:
- k1 = k2 = k3 = k4 = 1.0

Arguments:
- X: State vector [X3, X4, X5]
- inputs: Dictionary or named tuple with keys :X1 and :X2 (input functions or interpolations)
- t: Time

Returns:
- dX: Time derivatives [X3', X4', X5']
"""
function simplelin_system(X, inputs, t)
    # Unpack state variables
    X3, X4, X5 = X
    
    # Get input values at time t
    X1 = inputs[:X1](t)
    X2 = inputs[:X2](t)
    
    # Rate constants (all equal to 1.0 in the benchmark)
    k1, k2, k3, k4 = 1.0, 1.0, 1.0, 1.0
    
    # System equations
    dX3 = -k1 * X3 + k2 * X1 * X4
    dX4 = k1 * X3 - k2 * X1 * X4 + k3 * X5 - k4 * X2 * X4
    dX5 = -k3 * X5 + k4 * X2 * X4
    
    return [dX3, dX4, dX5]
end

"""
    generate_simplelin_data(; X1_const=3.0, X2_const=2.0, X3_0=1.0, X4_0=0.0, X5_0=0.0,
                            tspan=(0.0, 3.0), n_points=13, noise_std=0.0, 
                            X1_func=nothing, X2_func=nothing)

Generate data from the simpleLin benchmark system.

Arguments:
- X1_const: Constant value for input X1 (used if X1_func is nothing)
- X2_const: Constant value for input X2 (used if X2_func is nothing)
- X3_0, X4_0, X5_0: Initial conditions for state variables
- tspan: Time span as tuple (t_start, t_end)
- n_points: Number of uniformly sampled time points
- noise_std: Standard deviation of Gaussian noise (as fraction of value, e.g., 0.1 for 10%)
- X1_func: Optional function X1(t) for time-varying input
- X2_func: Optional function X2(t) for time-varying input

Returns:
- t: Time points
- X: Matrix of states (n_points × 3) with columns [X3, X4, X5]
- inputs: Dictionary with X1 and X2 values at each time point

Example:
```julia
# Simple case with constant inputs
t, X, inputs = generate_simplelin_data(X1_const=3.0, X2_const=2.0)

# With noise (10% standard deviation)
t, X, inputs = generate_simplelin_data(X1_const=3.0, X2_const=2.0, noise_std=0.1)

# With time-varying inputs
t, X, inputs = generate_simplelin_data(X1_func=t->sin(t), X2_func=t->cos(t))
```
"""
function generate_simplelin_data(; 
    X1_const=3.0, 
    X2_const=2.0, 
    X3_0=1.0, 
    X4_0=0.0, 
    X5_0=0.0,
    tspan=(0.0, 3.0), 
    n_points=13, 
    noise_std=0.0,
    X1_func=nothing,
    X2_func=nothing
)
    # Create input functions
    if X1_func === nothing
        X1_func = t -> X1_const
    end
    if X2_func === nothing
        X2_func = t -> X2_const
    end
    
    inputs = Dict(:X1 => X1_func, :X2 => X2_func)
    
    # Initial conditions
    X0 = [X3_0, X4_0, X5_0]
    
    # Define ODE problem
    function ode_func!(dX, X, p, t)
        dX .= simplelin_system(X, inputs, t)
    end
    
    prob = ODEProblem(ode_func!, X0, tspan)
    
    # Solve ODE
    t_eval = range(tspan[1], tspan[2], length=n_points)
    sol = solve(prob, AutoTsit5(Rosenbrock23()), saveat=t_eval, maxiters=10^6)
    
    # Extract solution — always returns exactly n_points rows even if the solver terminates early
    n_expected = length(t_eval)
    t = collect(t_eval)
    n_got = length(sol.u)
    X = if n_got == n_expected
        hcat(sol.u...)'  # (n_points × n_states)
    else
        Xfill = fill(NaN, n_expected, length(X0))
        for i in 1:n_got; Xfill[i, :] = sol.u[i]; end
        Xfill
    end
    
    # Add noise if requested
    if noise_std > 0.0
        # Add Gaussian noise with standard deviation proportional to the value
        # For t=0, we would typically average multiple repetitions (not implemented here)
        for i in 1:size(X, 1)
            for j in 1:size(X, 2)
                # 10% noise means std = 0.1 * abs(value)
                noise = noise_std * abs(X[i, j]) * randn()
                X[i, j] += noise
            end
        end
    end
    
    # Prepare input values at each time point
    input_values = Dict(
        :X1 => [X1_func(ti) for ti in t],
        :X2 => [X2_func(ti) for ti in t]
    )
    
    return t, X, input_values
end

"""
    generate_simplelin_experiments()

Generate data for the 8 experiments from simpleLin2 benchmark.

Each experiment uses different input combinations:
    Exp.    X1     X2     X3_0   X4_0   X5_0
     1     3.0    2.0    1.0    0.0    0.0
     2     4.0    5.0    1.0    0.0    0.0
     3     1.0    3.0    1.0    0.0    0.0
     4     3.0    1.0    1.0    0.0    0.0
     5     0.5    1.0    1.0    0.0    0.0
     6     1.0    0.5    1.0    0.0    0.0
     7     0.5    5.0    1.0    0.0    0.0
     8     5.0    0.5    1.0    0.0    0.0

Arguments:
- noise_std: Standard deviation of noise (0.0 for no noise, 0.1 for 10%)
- n_points: Number of time points per experiment
- num_trajectories: Number of trajectories per experiment (different initial conditions)
                    If > 1, generates multiple trajectories from different ICs for each experiment.
                    ICs are sampled to satisfy conservation law: X3_0 + X4_0 + X5_0 = 1.0

Returns:
- experiments: Vector of dictionaries, each containing :t, :X, :inputs, :params, :ic
"""
function generate_simplelin_experiments(; noise_std=0.0, n_points::Union{Int,Nothing}=nothing, num_trajectories=1)
    _n_points = n_points !== nothing ? n_points : 13
    experiment_params = [
        (X1=3.0, X2=2.0),
        (X1=4.0, X2=5.0),
        (X1=1.0, X2=3.0),
        (X1=3.0, X2=1.0),
        (X1=0.5, X2=1.0),
        (X1=1.0, X2=0.5),
        (X1=0.5, X2=5.0),
        (X1=5.0, X2=0.5),
    ]
    
    experiments = []
    
    for (i, params) in enumerate(experiment_params)
        # Generate num_trajectories trajectories for this experiment
        for traj_idx in 1:num_trajectories
            # Default IC for first trajectory, varied for others
            if traj_idx == 1
                X3_0, X4_0, X5_0 = 1.0, 0.0, 0.0
            else
                # Sample random ICs satisfying conservation law: X3 + X4 + X5 = 1.0
                # Use Dirichlet-like sampling
                r1, r2 = rand(2)
                if r1 > r2
                    r1, r2 = r2, r1
                end
                X3_0 = r1
                X4_0 = r2 - r1
                X5_0 = 1.0 - r2
            end
            
            t, X, input_values = generate_simplelin_data(
                X1_const=params.X1,
                X2_const=params.X2,
                X3_0=X3_0,
                X4_0=X4_0,
                X5_0=X5_0,
                tspan=(0.0, 3.0),
                n_points=_n_points,
                noise_std=noise_std
            )
            
            push!(experiments, Dict(
                :experiment => i,
                :trajectory => traj_idx,
                :t => t,
                :X => X,
                :inputs => input_values,
                :params => params,
                :ic => (X3_0=X3_0, X4_0=X4_0, X5_0=X5_0)
            ))
        end
    end
    
    return experiments
end

"""
    get_equation_strings(problem::String)

Return the ground truth equations for simpleLin problems as strings.

For both simpleLin1 and simpleLin2:
    X3' = -k1·X3 + k2·X1·X4
    X4' = k1·X3 - k2·X1·X4 + k3·X5 - k4·X2·X4
    X5' = -k3·X5 + k4·X2·X4

Parameters: k1 = k2 = k3 = k4 = 1.0
"""
function get_equation_strings(problem::String)
    if !startswith(problem, "simpleLin")
        error("Problem $problem is not a simpleLin problem")
    end
    
    # State mapping: X3-5 -> X1-3
    # Input mapping: X1-2 -> X4-5 (sorted alphabetically :X1, :X2)
    return [
        "X1' = -1.0*X1 + 1.0*X4*X2",
        "X2' = 1.0*X1 - 1.0*X4*X2 + 1.0*X3 - 1.0*X5*X2",
        "X3' = -1.0*X3 + 1.0*X5*X2"
    ]
end

end # module

