"""
simpleFb.jl

Implementation of simpleFb benchmark system (feedback system).
Based on: https://www.cse.chalmers.se/~dag/identification/Benchmarks/simpleFb.html

Reference: McKinney et al. (2006) - Hybrid grammar-based approach to nonlinear 
dynamical system identification from biological time series.
"""

module SimpleFbModule

using DifferentialEquations

export simplefb_system, generate_simplefb_data, generate_simplefb_experiments, get_equation_strings

"""
    simplefb_system(X, p, t)

Simple feedback system benchmark.

The system consists of 3 dependent variables X1, X2, X3 with feedback regulation:

    X1'(t) = k1·h⁻(X3,k2) - k3·X1(t)
    X2'(t) = k4·X1(t) - k5·X2(t)
    X3'(t) = k6·X2(t) - k7·X3(t)

where:
    h⁺(Xi,kj) = Xi / (Xi + kj)
    h⁻(Xi,kj) = 1 - h⁺(Xi,kj) = kj / (Xi + kj)

Parameters: k = [0.9, 0.9, 1.0, 1.0, 0.6, 0.6, 0.8]
"""
function simplefb_system(X, p, t)
    X1, X2, X3 = X
    k1, k2, k3, k4, k5, k6, k7 = p
    
    # Hill functions
    h_minus(xi, kj) = kj / (xi + kj)
    
    # System equations
    dX1 = k1 * h_minus(X3, k2) - k3 * X1
    dX2 = k4 * X1 - k5 * X2
    dX3 = k6 * X2 - k7 * X3
    
    return [dX1, dX2, dX3]
end

"""
    generate_simplefb_data(; X0=[1.0, 0.0, 0.0], tspan=(0.0, 10.0), n_points=7, 
                           noise_std=0.0, k=[0.9, 0.9, 1.0, 1.0, 0.6, 0.6, 0.8])

Generate data from the simpleFb benchmark system.

Arguments:
- X0: Initial conditions [X1_0, X2_0, X3_0]
- tspan: Time span as tuple (t_start, t_end)
- n_points: Number of uniformly sampled time points
- noise_std: Standard deviation of Gaussian noise (as fraction of value)
- k: Parameter vector [k1, k2, k3, k4, k5, k6, k7]

Returns:
- t: Time points
- X: Matrix of states (n_points × 3)
"""
function generate_simplefb_data(;
    X0=[1.0, 0.0, 0.0],
    tspan=(0.0, 10.0),
    n_points=7,
    noise_std=0.0,
    k=[0.9, 0.9, 1.0, 1.0, 0.6, 0.6, 0.8]
)
    # Define ODE problem
    function ode_func!(dX, X, p, t)
        dX .= simplefb_system(X, p, t)
    end
    
    prob = ODEProblem(ode_func!, X0, tspan, k)
    
    # Solve ODE
    t_eval = range(tspan[1], tspan[2], length=n_points)
    sol = solve(prob, AutoTsit5(Rosenbrock23()), saveat=t_eval)
    
    # Extract solution
    t = sol.t
    X = hcat(sol.u...)'
    
    # Add noise if requested
    if noise_std > 0.0
        for i in 1:size(X, 1)
            for j in 1:size(X, 2)
                noise = noise_std * abs(X[i, j]) * randn()
                X[i, j] += noise
            end
        end
    end
    
    return t, X
end

"""
    generate_simplefb_experiments(; problem="simpleFb1")

Generate data for simpleFb benchmark problems.

Problem variants:
- simpleFb1: 4 experiments, 7 points, 0% noise
- simpleFb2: 4 experiments, 7 points, 5% noise
- simpleFb3: 1 experiment, 7 points, 0% noise (sparse data)
- simpleFb4: 1 experiment, 7 points, ~5% noise (sparse data)

Returns:
- experiments: Vector of dictionaries with :t, :X, :X0 for each experiment
"""
function generate_simplefb_experiments(; problem="simpleFb1", noise_std::Union{Float64,Nothing}=nothing)
    if problem == "simpleFb1"
        noise_std = noise_std !== nothing ? noise_std : 0.0
        initial_conditions = [
            [1.0, 0.0, 0.0],
            [0.0, 1.0, 0.0],
            [0.0, 0.0, 1.0],
            [0.5, 0.5, 0.5]
        ]
    elseif problem == "simpleFb2"
        noise_std = noise_std !== nothing ? noise_std : 0.05
        initial_conditions = [
            [1.0, 0.0, 0.0],
            [0.0, 1.0, 0.0],
            [0.0, 0.0, 1.0],
            [0.5, 0.5, 0.5]
        ]
    elseif problem == "simpleFb3"
        noise_std = noise_std !== nothing ? noise_std : 0.0
        initial_conditions = [[1.0, 0.0, 0.0]]
    elseif problem == "simpleFb4"
        noise_std = noise_std !== nothing ? noise_std : 0.05
        initial_conditions = [[1.0, 0.0, 0.0]]
    else
        error("Unknown problem: $problem. Choose from simpleFb1, simpleFb2, simpleFb3, simpleFb4")
    end
    
    experiments = []
    
    for (i, X0) in enumerate(initial_conditions)
        t, X = generate_simplefb_data(
            X0=X0,
            tspan=(0.0, 10.0),
            n_points=7,
            noise_std=noise_std
        )
        
        push!(experiments, Dict(
            :experiment => i,
            :t => t,
            :X => X,
            :X0 => X0
        ))
    end
    
    return experiments
end

"""
    get_equation_strings(problem::String)

Return the ground truth equations for simpleFb problems as strings.

For both simpleFb1 and simpleFb2:
    X1' = k1·h⁻(X3,k2) - k3·X1
    X2' = k4·X1 - k5·X2
    X3' = k6·X2 - k7·X3

Where h⁻(Xi,kj) = kj/(Xi+kj) is a Hill function.
Parameters: k = [0.9, 0.9, 1.0, 1.0, 0.6, 0.6, 0.8]

Expanded form:
    X1' = 0.9·(0.9/(X3+0.9)) - 1.0·X1
    X2' = 1.0·X1 - 0.6·X2
    X3' = 0.6·X2 - 0.8·X3
"""
function get_equation_strings(problem::String)
    if !startswith(problem, "simpleFb")
        error("Problem $problem is not a simpleFb problem")
    end
    
    return [
        "X1' = 0.9 * (0.9 / (X3 + 0.9)) - 1.0 * X1",
        "X2' = 1.0 * X1 - 0.6 * X2",
        "X3' = 0.6 * X2 - 0.8 * X3"
    ]
end

end # module

