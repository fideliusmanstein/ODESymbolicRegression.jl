"""
feedf.jl

Implementation of feedf benchmark system (feed-forward pathway).
Based on: https://www.cse.chalmers.se/~dag/identification/Benchmarks/feedf.html

Two Michaelis-Menten reactions affecting production of a single variable.
"""

module FeedfModule

using DifferentialEquations

export feedf_system, generate_feedf_data, generate_feedf_experiments

"""
    get_equation_strings(problem)

Return the ground truth equation strings for the feedf problem.
"""
function get_equation_strings(problem)
    # All feedf problems use the same 4-state system
    # Expanded with constants and input mapping (In1->X5, In2->X6)
    return [
        "X1' = X5 - 1.0*X1/(X1+0.5)",
        "X2' = X6 - 1.0*X2/(X2+0.4)",
        "X3' = 1.0*X1/(X1+0.5) + 1.0*X2/(X2+0.4) - 1.0*X3/(X3+0.3)",
        "X4' = 1.0*X3/(X3+0.3) - 1.0*X4/(X4+0.3)"
    ]
end
export get_equation_strings

"""
    feedf_system(X, inputs, t)

Feed-forward pathway benchmark system with Michaelis-Menten kinetics.

The system has 2 input rates (In1, In2) and 4 dependent variables:

    X1'(t) = In1 - k1·X1/(X1+k2)
    X2'(t) = In2 - k3·X2/(X2+k4)
    X3'(t) = k5·X1/(X1+k6) + k7·X2/(X2+k8) - k9·X3/(X3+k10)
    X4'(t) = k11·X3/(X3+k12) - k13·X4/(X4+k14)

Parameters:
    k1 = k3 = k5 = k7 = k9 = k11 = k13 = 1
    k2 = k6 = 0.5
    k4 = k8 = 0.4
    k10 = k12 = k14 = 0.3
"""
function feedf_system(X, inputs, t)
    X1, X2, X3, X4 = X
    
    # Get inputs
    In1 = inputs[:In1](t)
    In2 = inputs[:In2](t)
    
    # Parameters
    k1, k3, k5, k7, k9, k11, k13 = 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0
    k2, k6 = 0.5, 0.5
    k4, k8 = 0.4, 0.4
    k10, k12, k14 = 0.3, 0.3, 0.3
    
    # System equations (Michaelis-Menten kinetics)
    dX1 = In1 - k1 * X1 / (X1 + k2)
    dX2 = In2 - k3 * X2 / (X2 + k4)
    dX3 = k5 * X1 / (X1 + k6) + k7 * X2 / (X2 + k8) - k9 * X3 / (X3 + k10)
    dX4 = k11 * X3 / (X3 + k12) - k13 * X4 / (X4 + k14)
    
    return [dX1, dX2, dX3, dX4]
end

"""
    generate_feedf_data(; In1_const=1.0, In2_const=1.0, X0=[0.5, 0.5, 0.5, 0.5],
                        tspan=(0.0, 5.0), n_points=51, noise_std=0.0,
                        In1_func=nothing, In2_func=nothing)

Generate data from the feedf benchmark system.

Arguments:
- In1_const, In2_const: Constant input rates
- X0: Initial conditions
- tspan: Time span
- n_points: Number of time points
- noise_std: Noise level
- In1_func, In2_func: Optional time-varying inputs

Returns:
- t: Time points
- X: State matrix (n_points × 4)
- inputs: Input values
"""
function generate_feedf_data(;
    In1_const=1.0,
    In2_const=1.0,
    X0=[0.5, 0.5, 0.5, 0.5],
    tspan=(0.0, 5.0),
    n_points=51,
    noise_std=0.0,
    In1_func=nothing,
    In2_func=nothing
)
    # Create input functions
    if In1_func === nothing
        In1_func = t -> In1_const
    end
    if In2_func === nothing
        In2_func = t -> In2_const
    end
    
    inputs = Dict(:In1 => In1_func, :In2 => In2_func)
    
    # Define ODE problem
    function ode_func!(dX, X, p, t)
        dX .= feedf_system(X, inputs, t)
    end
    
    prob = ODEProblem(ode_func!, X0, tspan)
    
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
    
    # Prepare input values
    input_values = Dict(
        :In1 => [In1_func(ti) for ti in t],
        :In2 => [In2_func(ti) for ti in t]
    )
    
    return t, X, input_values
end

"""
    generate_feedf_experiments(; problem="feedf1")

Generate data for feedf benchmark problems.

Problem variants:
- feedf1: 16 experiments, 51 points, 0% noise
- feedf2: 16 experiments, 51 points, 5% noise

Each experiment has different initial conditions (±75% of steady state).

Returns:
- experiments: Vector of dictionaries
"""
function generate_feedf_experiments(; problem="feedf1", noise_std::Union{Float64,Nothing}=nothing, n_points::Union{Int,Nothing}=nothing)
    if problem == "feedf1"
        noise_std = noise_std !== nothing ? noise_std : 0.0
    elseif problem == "feedf2"
        noise_std = noise_std !== nothing ? noise_std : 0.0
    else
        error("Unknown problem: $problem. Choose from feedf1, feedf2")
    end

    experiments = []

    # Bug 2 fix: vary both input levels across experiments (4×4 grid).
    # Values are chosen so that In1 + In2 < 1, which guarantees finite steady
    # states for all four state variables.
    in1_vals = [0.1, 0.2, 0.3, 0.4]
    in2_vals = [0.1, 0.2, 0.3, 0.4]

    exp_num = 1
    for in1 in in1_vals, in2 in in2_vals
        # Compute true steady states for this (In1, In2) combination:
        #   X1_ss = 0.5·In1 / (1 − In1)
        #   X2_ss = 0.4·In2 / (1 − In2)
        #   X3_ss = X4_ss = 0.3·(In1+In2) / (1 − In1 − In2)
        X1_ss = 0.5 * in1 / (1.0 - in1)
        X2_ss = 0.4 * in2 / (1.0 - in2)
        X34_ss = 0.3 * (in1 + in2) / (1.0 - in1 - in2)
        X_ss = [X1_ss, X2_ss, X34_ss, X34_ss]

        # Perturb initial conditions ±50 % around the steady state
        X0 = X_ss .* (1.0 .+ 0.5 * (2.0 * rand(4) .- 1.0))
        X0 = max.(X0, 0.01)

        _n_points = n_points !== nothing ? n_points : 51
        t, X, input_values = generate_feedf_data(
            In1_const=in1,
            In2_const=in2,
            X0=X0,
            tspan=(0.0, 5.0),
            n_points=_n_points,
            noise_std=noise_std
        )

        push!(experiments, Dict(
            :experiment => exp_num,
            :t => t,
            :X => X,
            :inputs => input_values,
            :X0 => X0
        ))
        exp_num += 1
    end

    return experiments
end

end # module
