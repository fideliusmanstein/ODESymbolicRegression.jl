"""
inhosc.jl

Implementation of inhosc benchmark system (inhibitory oscillator).
Based on: https://www.cse.chalmers.se/~dag/identification/Benchmarks/inhosc.html

Inhibitory oscillator with two or four dependent variables.
"""

module InhoscModule

using DifferentialEquations

export inhosc_system, generate_inhosc_data, generate_inhosc_experiments

"""
    get_equation_strings(problem)

Return the ground truth equation strings for the inhosc problem.
"""
function get_equation_strings(problem)
    # All k-values = 1.0.
    # Inputs are stored as features after the states, sorted alphabetically:
    #   In  → x{n_states+1}
    #   Out → x{n_states+2}
    if problem == "inhosc1"
        # 2 states → In=x3, Out=x4
        return [
            "X1' = x3 - 1.0/(X2+1.0)",
            "X2' = 1.0/(X1+1.0) - x4"
        ]
    elseif problem == "inhosc2"
        # 4 states → In=x5, Out=x6
        return [
            "X1' = x5 - 1.0/(X4+1.0)",
            "X2' = 1.0/(X1+1.0) - 1.0/(X3+1.0)",
            "X3' = 1.0/(X2+1.0) - 1.0/(X4+1.0)",
            "X4' = 1.0/(X3+1.0) - x6"
        ]
    else
        return ["Unknown problem: $problem"]
    end
end
export get_equation_strings

"""
    inhosc_system(X, inputs, t)

Inhibitory oscillator benchmark system.

2-state version:
    X1'(t) = In - k1/(X2+k2)
    X2'(t) = k3/(X1+k4) - Out

4-state version:
    X1'(t) = In - k1/(X4+k2)
    X2'(t) = k3/(X1+k4) - k5/(X3+k6)
    X3'(t) = k7/(X2+k8) - k9/(X4+k10)
    X4'(t) = k11/(X3+k12) - Out

Parameters (both versions):
    All k-values = 1.0
"""
function inhosc_system(X, inputs, t; n_states=2)
    # Get inputs
    In = inputs[:In](t)
    Out = inputs[:Out](t)
    
    # Parameters
    k = ones(12)
    
    if n_states == 2
        X1, X2 = X
        
        dX1 = In - k[1] / (X2 + k[2])
        dX2 = k[3] / (X1 + k[4]) - Out
        
        return [dX1, dX2]
    elseif n_states == 4
        X1, X2, X3, X4 = X
        
        dX1 = In - k[1] / (X4 + k[2])
        dX2 = k[3] / (X1 + k[4]) - k[5] / (X3 + k[6])
        dX3 = k[7] / (X2 + k[8]) - k[9] / (X4 + k[10])
        dX4 = k[11] / (X3 + k[12]) - Out
        
        return [dX1, dX2, dX3, dX4]
    else
        error("n_states must be 2 or 4")
    end
end

"""
    generate_inhosc_data(; In_const=1.0, Out_const=1.0, X0=nothing,
                         tspan=(0.0, 10.0), n_points=51, noise_std=0.0,
                         In_func=nothing, Out_func=nothing, n_states=2)

Generate data from the inhosc benchmark system.

Arguments:
- In_const, Out_const: Constant input/output rates
- X0: Initial conditions (default: [1.0, 1.0] for 2-state or [1.0, 1.0, 1.0, 1.0] for 4-state)
- tspan: Time span
- n_points: Number of time points
- noise_std: Noise level
- In_func, Out_func: Optional time-varying inputs/outputs
- n_states: 2 or 4

Returns:
- t: Time points
- X: State matrix (n_points × n_states)
- inputs: Input values
"""
function generate_inhosc_data(;
    In_const=1.0,
    Out_const=1.0,
    X0=nothing,
    tspan=(0.0, 10.0),
    n_points=51,
    noise_std=0.0,
    In_func=nothing,
    Out_func=nothing,
    n_states=2
)
    # Set default initial conditions
    if X0 === nothing
        X0 = ones(n_states)
    end
    
    # Create input functions
    if In_func === nothing
        In_func = t -> In_const
    end
    if Out_func === nothing
        Out_func = t -> Out_const
    end
    
    inputs = Dict(:In => In_func, :Out => Out_func)
    
    # Define ODE problem
    function ode_func!(dX, X, p, t)
        dX .= inhosc_system(X, inputs, t; n_states=n_states)
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
        :In => [In_func(ti) for ti in t],
        :Out => [Out_func(ti) for ti in t]
    )
    
    return t, X, input_values
end

"""
    generate_inhosc_experiments(; problem="inhosc1")

Generate data for inhosc benchmark problems.

Problem variants:
- inhosc1: 4 experiments (2-state), 51 points, 0% noise
- inhosc2: 4 experiments (4-state), 51 points, 3% noise

Each experiment has different In/Out values.

Returns:
- experiments: Vector of dictionaries
"""
function generate_inhosc_experiments(; problem="inhosc1", noise_std::Union{Float64,Nothing}=nothing, n_points::Union{Int,Nothing}=nothing)
    if problem == "inhosc1"
        noise_std = noise_std !== nothing ? noise_std : 0.0
        n_states = 2
    elseif problem == "inhosc2"
        noise_std = noise_std !== nothing ? noise_std : 0.0
        n_states = 4
    else
        error("Unknown problem: $problem. Choose from inhosc1, inhosc2")
    end
    
    experiments = []
    
    # Four different input/output combinations
    input_combinations = [
        (In=0.8, Out=0.8),
        (In=1.0, Out=1.0),
        (In=1.2, Out=1.0),
        (In=1.0, Out=1.2)
    ]
    
    for (exp, combo) in enumerate(input_combinations)
        X0 = ones(n_states)
        
        _n_points = n_points !== nothing ? n_points : 51
        t, X, input_values = generate_inhosc_data(
            In_const=combo.In,
            Out_const=combo.Out,
            X0=X0,
            tspan=(0.0, 10.0),
            n_points=_n_points,
            noise_std=noise_std,
            n_states=n_states
        )
        
        push!(experiments, Dict(
            :experiment => exp,
            :t => t,
            :X => X,
            :inputs => input_values,
            :X0 => X0,
            :In => combo.In,
            :Out => combo.Out
        ))
    end
    
    return experiments
end

end # module
