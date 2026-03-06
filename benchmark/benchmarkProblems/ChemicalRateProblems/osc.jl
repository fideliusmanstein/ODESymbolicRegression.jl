"""
osc.jl

Implementation of oscillator benchmark system.
Based on: https://www.cse.chalmers.se/~dag/identification/Benchmarks/osc.html

Reference: Karnaukhov et al. (2007) - Numerical Matrices Method for nonlinear 
system identification and description of dynamics of biochemical reaction networks.
"""

module OscModule

using DifferentialEquations

export osc_system, generate_osc_data, generate_osc_experiments, get_equation_strings

"""
    osc_system(X, p, t)

Oscillator benchmark system.

The system consists of 3 dependent variables modeling an oscillating system:

    X1'(t) = k1·X2(t)
    X2'(t) = -k2·X1(t) + k3·X2(t) - k4·X2(t)·X3(t)
    X3'(t) = k5·X1(t)² - k6·X3(t)

Parameters: k = [0.9, 0.9, 1.0, 1.0, 0.6, 0.6] (note: k7=0.8 not used based on equations)
"""
function osc_system(X, p, t)
    X1, X2, X3 = X
    k1, k2, k3, k4, k5, k6 = p
    
    # System equations
    dX1 = k1 * X2
    dX2 = -k2 * X1 + k3 * X2 - k4 * X2 * X3
    dX3 = k5 * X1^2 - k6 * X3
    
    return [dX1, dX2, dX3]
end

"""
    generate_osc_data(; X0=[1.0, 0.0, 0.0], tspan=(0.0, 20.0), n_points=41, 
                      noise_std=0.0, k=[0.9, 0.9, 1.0, 1.0, 0.6, 0.6])

Generate data from the oscillator benchmark system.

Arguments:
- X0: Initial conditions [X1_0, X2_0, X3_0]
- tspan: Time span as tuple (t_start, t_end)
- n_points: Number of uniformly sampled time points
- noise_std: Standard deviation of Gaussian noise (as fraction of value)
- k: Parameter vector [k1, k2, k3, k4, k5, k6]

Returns:
- t: Time points
- X: Matrix of states (n_points × 3)
"""
function generate_osc_data(;
    X0=[1.0, 0.0, 0.0],
    tspan=(0.0, 20.0),
    n_points=41,
    noise_std=0.0,
    k=[0.9, 0.9, 1.0, 1.0, 0.6, 0.6]
)
    # Define ODE problem
    function ode_func!(dX, X, p, t)
        dX .= osc_system(X, p, t)
    end
    
    prob = ODEProblem(ode_func!, X0, tspan, k)
    
    # Solve ODE
    t_eval = range(tspan[1], tspan[2], length=n_points)
    sol = solve(prob, AutoTsit5(Rosenbrock23()), saveat=t_eval, maxiters=10^6)
    
    # Extract solution — always returns exactly n_points rows even if the solver terminates early
    t = collect(t_eval)
    n_got = length(sol.u)
    X = if n_got == n_points
        hcat(sol.u...)'
    else
        Xfill = fill(NaN, n_points, length(X0))
        for i in 1:n_got; Xfill[i, :] = sol.u[i]; end
        Xfill
    end
    
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
    generate_osc_experiments(; problem="osc1")

Generate data for oscillator benchmark problems.

Problem variants:
- osc1: 1 experiment, 41 points, 0% noise
- osc2: 1 experiment, 41 points, 3% noise

Returns:
- experiments: Vector of dictionaries with :t, :X, :X0 for each experiment
"""
function generate_osc_experiments(; problem="osc1", noise_std::Union{Float64,Nothing}=nothing, n_points::Union{Int,Nothing}=nothing)
    if problem == "osc1"
        noise_std = noise_std !== nothing ? noise_std : 0.0
    elseif problem == "osc2"
        noise_std = noise_std !== nothing ? noise_std : 0.0
    else
        error("Unknown problem: $problem. Choose from osc1, osc2")
    end
    
    experiments = []
    X0 = [1.0, 0.0, 0.0]
    
    _n_points = n_points !== nothing ? n_points : 41
    t, X = generate_osc_data(
        X0=X0,
        tspan=(0.0, 20.0),
        n_points=_n_points,
        noise_std=noise_std
    )
    
    push!(experiments, Dict(
        :experiment => 1,
        :t => t,
        :X => X,
        :X0 => X0
    ))
    
    return experiments
end

"""
    get_equation_strings(problem::String)

Return the ground truth equations for oscillator problems as strings.

For both osc1 and osc2:
    X1' = k1·X2
    X2' = -k2·X1 + k3·X2 - k4·X2·X3
    X3' = k5·X1² - k6·X3

Parameters: k = [0.9, 0.9, 1.0, 1.0, 0.6, 0.6]
"""
function get_equation_strings(problem::String)
    if !startswith(problem, "osc")
        error("Problem $problem is not an osc problem")
    end
    
    return [
        "X1' = 0.9·X2",
        "X2' = -0.9·X1 + 1.0·X2 - 1.0·X2·X3",
        "X3' = 0.6·X1² - 0.6·X3"
    ]
end

end # module

