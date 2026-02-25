"""
bifeedb.jl

Implementation of bifeedb benchmark system (bi-molecular feedback).
Based on: https://www.cse.chalmers.se/~dag/identification/Benchmarks/bifeedb.html

Bi-molecular reactions with feedback, using 4 or 5 dependent variables.
"""

module BifeedbModule

using DifferentialEquations

export bifeedb_system, generate_bifeedb_data, generate_bifeedb_experiments

"""
    get_equation_strings(problem)

Return the ground truth equation strings for the bifeedb problem.
"""
function get_equation_strings(problem)
    if problem == "bifeedb1"
        return [
            "X1' = 1.0/(X3+0.1) - 1.0*X1^2",
            "X2' = 1.0*X1^2 - 1.0*X2/(X2+0.1)",
            "X3' = 1.0*X2/(X2+0.1) - 1.0*X3/(X3+0.1)",
            "X4' = 1.0*X3/(X3+0.1) - 1.0*X4/(X4+0.1)"
        ]
    elseif problem == "bifeedb2"
        return [
            "X1' = 1.0/(X3+0.1) - 1.0*X1^2",
            "X2' = 1.0*X1^2 - 1.0*X2/(X2+0.1)",
            "X3' = 1.0*X2/(X2+0.1) - 1.0*X3/(X3+0.1)",
            "X4' = 1.0*X3/(X3+0.1) - 1.0*X4/(X4+0.1)",
            "X5' = 1.0*X4/(X4+0.1) - 1.0*X5/(X5+0.1)"
        ]
    else
        return ["Unknown problem: $problem"]
    end
end
export get_equation_strings

"""
    bifeedb_system(X, inputs, t; n_states=4)

Bi-molecular feedback benchmark system.

4-state version:
    X1'(t) = k1/(X3+k2) - k3·X1²
    X2'(t) = k5·X1² - k7·X2/(X2+k8)
    X3'(t) = k9·X2/(X2+k10) - k11·X3/(X3+k12)
    X4'(t) = k13·X3/(X3+k14) - k15·X4/(X4+k16)

5-state version adds:
    X5'(t) = k17·X4/(X4+k18) - k19·X5/(X5+k20)

Parameters:
    k1 = k3 = k5 = k7 = k9 = k11 = k13 = k15 = 1
    k17 = k19 = 1 (for 5-state)
    k2 = k4 = k6 = k8 = k10 = k12 = k14 = k16 = 0.1
    k18 = k20 = 0.1 (for 5-state)
"""
function bifeedb_system(X, inputs, t; n_states=4)
    # Parameters
    k_odd = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]  # k1, k3, k5, k7, k9, k11, k13, k15, k17, k19
    k_even = fill(0.1, 10)  # k2, k4, k6, k8, k10, k12, k14, k16, k18, k20
    
    if n_states == 4
        X1, X2, X3, X4 = X
        
        dX1 = k_odd[1] / (X3 + k_even[1]) - k_odd[2] * X1^2
        dX2 = k_odd[3] * X1^2 - k_odd[4] * X2 / (X2 + k_even[4])
        dX3 = k_odd[5] * X2 / (X2 + k_even[5]) - k_odd[6] * X3 / (X3 + k_even[6])
        dX4 = k_odd[7] * X3 / (X3 + k_even[7]) - k_odd[8] * X4 / (X4 + k_even[8])
        
        return [dX1, dX2, dX3, dX4]
        
    elseif n_states == 5
        X1, X2, X3, X4, X5 = X
        
        dX1 = k_odd[1] / (X3 + k_even[1]) - k_odd[2] * X1^2
        dX2 = k_odd[3] * X1^2 - k_odd[4] * X2 / (X2 + k_even[4])
        dX3 = k_odd[5] * X2 / (X2 + k_even[5]) - k_odd[6] * X3 / (X3 + k_even[6])
        dX4 = k_odd[7] * X3 / (X3 + k_even[7]) - k_odd[8] * X4 / (X4 + k_even[8])
        dX5 = k_odd[9] * X4 / (X4 + k_even[9]) - k_odd[10] * X5 / (X5 + k_even[10])
        
        return [dX1, dX2, dX3, dX4, dX5]
    else
        error("n_states must be 4 or 5")
    end
end

"""
    generate_bifeedb_data(; X0=nothing, tspan=(0.0, 5.0), n_points=51,
                          noise_std=0.0, n_states=4)

Generate data from the bifeedb benchmark system.

Arguments:
- X0: Initial conditions (default: [1.0, 1.0, 1.0, 1.0] for 4-state or [..., 1.0] for 5-state)
- tspan: Time span
- n_points: Number of time points
- noise_std: Noise level
- n_states: 4 or 5

Returns:
- t: Time points
- X: State matrix (n_points × n_states)
- inputs: Empty dict (no inputs for this system)
"""
function generate_bifeedb_data(;
    X0=nothing,
    tspan=(0.0, 5.0),
    n_points=51,
    noise_std=0.0,
    n_states=4
)
    # Set default initial conditions
    if X0 === nothing
        X0 = ones(n_states)
    end
    
    # No external inputs for this system
    inputs = Dict{Symbol, Function}()
    
    # Define ODE problem
    function ode_func!(dX, X, p, t)
        dX .= bifeedb_system(X, inputs, t; n_states=n_states)
    end
    
    prob = ODEProblem(ode_func!, X0, tspan)
    
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
    
    return t, X, Dict()
end

"""
    generate_bifeedb_experiments(; problem="bifeedb1")

Generate data for bifeedb benchmark problems.

Problem variants:
- bifeedb1: 16 experiments (4-state), 51 points, 0% noise
- bifeedb2: 16 experiments (5-state), 51 points, 5% noise

Each experiment has different initial conditions (±75% of steady state).

Returns:
- experiments: Vector of dictionaries
"""
function generate_bifeedb_experiments(; problem="bifeedb1", noise_std::Union{Float64,Nothing}=nothing)
    if problem == "bifeedb1"
        noise_std = noise_std !== nothing ? noise_std : 0.0
        n_states = 4
    elseif problem == "bifeedb2"
        noise_std = noise_std !== nothing ? noise_std : 0.05
        n_states = 5
    else
        error("Unknown problem: $problem. Choose from bifeedb1, bifeedb2")
    end
    
    experiments = []
    
    # Steady state values (approximate, based on n_states)
    if n_states == 4
        X_ss = [0.5, 1.0, 1.5, 2.0]
    else  # n_states == 5
        X_ss = [0.5, 1.0, 1.5, 2.0, 2.5]
    end
    
    # Generate 16 different initial conditions
    for exp in 1:16
        # Vary initial conditions ±75% of steady state
        X0 = X_ss .* (1.0 .+ 0.75 * (2.0 * rand(n_states) .- 1.0))
        X0 = max.(X0, 0.01)  # Ensure positive values
        
        t, X, _ = generate_bifeedb_data(
            X0=X0,
            tspan=(0.0, 5.0),
            n_points=51,
            noise_std=noise_std,
            n_states=n_states
        )
        
        push!(experiments, Dict(
            :experiment => exp,
            :t => t,
            :X => X,
            :inputs => Dict(),
            :X0 => X0
        ))
    end
    
    return experiments
end

end # module
