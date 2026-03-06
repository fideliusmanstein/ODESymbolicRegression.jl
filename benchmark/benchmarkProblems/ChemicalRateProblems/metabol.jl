"""
metabol.jl

Implementation of metabol benchmark system (metabolic pathway).
Based on: https://www.cse.chalmers.se/~dag/identification/Benchmarks/metabol.html

Reference: Arkin & Ross (1995), Gennemark & Wedelin (2007)
Models a metabolic pathway with Michaelis-Menten kinetics.
"""

module MetabolModule

using DifferentialEquations

export metabol_system, generate_metabol_data, generate_metabol_experiments, get_equation_strings

"""
    metabol_system(X, inputs, t)

Metabolic pathway benchmark system with Michaelis-Menten kinetics.

The system has:
- 2 input variables: X1(t), X2(t)
- 5 state variables: X3, X4, X5, X6, X7

Equations:
    X3'(t) = -v1 - v2 + v3 + v4
    X4'(t) = v1 - v3
    X5'(t) = v2 - v4
    X6'(t) = v5 - v6
    X7'(t) = -v5 + v6

where:
    v1 = X3·Vmax1 / ((X3 + KD1)·(1 + X1/KI1))
    v2 = X3·Vmax2 / ((X3 + KD2)·(1 + X2/KI2))
    v3 = X4·Vmax3 / (X4 + KD3)
    v4 = X5·Vmax4 / (X5 + KD4)
    v5 = X7·Vmax5 / ((X7 + KD5)·(1 + X3/KI3))
    v6 = X6·Vmax6 / (X6 + KD6)

Parameters (from Arkin & Ross 1995):
- Vmax1-2 = 5, Vmax3-4 = Vmax6 = 1, Vmax5 = 10
- KD1-6 = 5
- KI1-3 = 1

Conservation laws: X3 + X4 + X5 = const, X6 + X7 = const
"""
function metabol_system(X, inputs, t)
    X3, X4, X5, X6, X7 = X
    
    # Get input values at time t
    X1 = inputs[:X1](t)
    X2 = inputs[:X2](t)
    
    # Parameters
    Vmax1, Vmax2 = 5.0, 5.0
    Vmax3, Vmax4, Vmax6 = 1.0, 1.0, 1.0
    Vmax5 = 10.0
    KD1, KD2, KD3, KD4, KD5, KD6 = 5.0, 5.0, 5.0, 5.0, 5.0, 5.0
    KI1, KI2, KI3 = 1.0, 1.0, 1.0
    
    # Reaction rates (Michaelis-Menten kinetics with non-competitive inhibition)
    v1 = X3 * Vmax1 / ((X3 + KD1) * (1 + X1 / KI1))
    v2 = X3 * Vmax2 / ((X3 + KD2) * (1 + X2 / KI2))
    v3 = X4 * Vmax3 / (X4 + KD3)
    v4 = X5 * Vmax4 / (X5 + KD4)
    v5 = X7 * Vmax5 / ((X7 + KD5) * (1 + X3 / KI3))
    v6 = X6 * Vmax6 / (X6 + KD6)
    
    # System equations
    dX3 = -v1 - v2 + v3 + v4
    dX4 = v1 - v3
    dX5 = v2 - v4
    dX6 = v5 - v6
    dX7 = -v5 + v6
    
    return [dX3, dX4, dX5, dX6, dX7]
end

"""
    generate_metabol_data(; X1_const=1.0, X2_const=1.0, X3_0=10.0, X4_0=0.1, X5_0=0.1,
                          X6_0=1.0, X7_0=1.0, tspan=(0.0, 150.0), n_points=7, 
                          noise_std=0.0, X1_func=nothing, X2_func=nothing)

Generate data from the metabol benchmark system.

Arguments:
- X1_const, X2_const: Constant values for inputs (if functions not provided)
- X3_0 through X7_0: Initial conditions for state variables
- tspan: Time span as tuple (t_start, t_end)
- n_points: Number of uniformly sampled time points
- noise_std: Standard deviation of Gaussian noise (as fraction of value)
- X1_func, X2_func: Optional functions for time-varying inputs

Returns:
- t: Time points
- X: Matrix of states (n_points × 5)
- inputs: Dictionary with X1 and X2 values at each time point
"""
function generate_metabol_data(;
    X1_const=1.0,
    X2_const=1.0,
    X3_0=10.0,
    X4_0=0.1,
    X5_0=0.1,
    X6_0=1.0,
    X7_0=1.0,
    tspan=(0.0, 150.0),
    n_points=7,
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
    X0 = [X3_0, X4_0, X5_0, X6_0, X7_0]
    
    # Define ODE problem
    function ode_func!(dX, X, p, t)
        dX .= metabol_system(X, inputs, t)
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
    
    # Prepare input values at each time point
    input_values = Dict(
        :X1 => [X1_func(ti) for ti in t],
        :X2 => [X2_func(ti) for ti in t]
    )
    
    return t, X, input_values
end

"""
    generate_metabol_experiments(; problem="metabol1")

Generate data for metabol benchmark problems.

Problem variants:
- metabol1: 12 experiments, 7 points, 0% noise
- metabol2: 12 experiments, 21 points, 10% noise
- metabol3: 12 experiments, 21 points, 20% noise

Returns:
- experiments: Vector of dictionaries with :t, :X, :inputs, :params
"""
function generate_metabol_experiments(; problem="metabol1", noise_std::Union{Float64,Nothing}=nothing)
    if problem == "metabol1"
        noise_std = noise_std !== nothing ? noise_std : 0.0
        n_points = 7
    elseif problem == "metabol2"
        noise_std = noise_std !== nothing ? noise_std : 0.0
        n_points = 21
    elseif problem == "metabol3"
        noise_std = noise_std !== nothing ? noise_std : 0.0
        n_points = 21
    else
        error("Unknown problem: $problem. Choose from metabol1, metabol2, metabol3")
    end
    
    # 12 different combinations of input values
    experiment_params = [
        (X1=0.5, X2=0.5),
        (X1=0.5, X2=1.0),
        (X1=0.5, X2=2.0),
        (X1=1.0, X2=0.5),
        (X1=1.0, X2=1.0),
        (X1=1.0, X2=2.0),
        (X1=2.0, X2=0.5),
        (X1=2.0, X2=1.0),
        (X1=2.0, X2=2.0),
        (X1=0.1, X2=0.1),
        (X1=5.0, X2=5.0),
        (X1=0.1, X2=5.0),
    ]
    
    experiments = []
    
    for (i, params) in enumerate(experiment_params)
        t, X, input_values = generate_metabol_data(
            X1_const=params.X1,
            X2_const=params.X2,
            X3_0=10.0,
            X4_0=0.1,
            X5_0=0.1,
            X6_0=1.0,
            X7_0=1.0,
            tspan=(0.0, 150.0),
            n_points=n_points,
            noise_std=noise_std
        )
        
        push!(experiments, Dict(
            :experiment => i,
            :t => t,
            :X => X,
            :inputs => input_values,
            :params => params
        ))
    end
    
    return experiments
end

"""
    get_equation_strings(problem::String)

Return the ground truth equations for metabol problems as strings.

For metabol1, metabol2, and metabol3:
    X3' = -v1 - v2 + v3 + v4
    X4' = v1 - v3
    X5' = v2 - v4
    X6' = v5 - v6
    X7' = -v5 + v6

Where (with parameters from Arkin & Ross 1995):
    v1 = X3·5.0 / ((X3 + 5.0)·(1 + X1/1.0))
    v2 = X3·5.0 / ((X3 + 5.0)·(1 + X2/1.0))
    v3 = X4·1.0 / (X4 + 5.0)
    v4 = X5·1.0 / (X5 + 5.0)
    v5 = X7·10.0 / ((X7 + 5.0)·(1 + X3/1.0))
    v6 = X6·1.0 / (X6 + 5.0)
"""
function get_equation_strings(problem::String)
    if !startswith(problem, "metabol")
        error("Problem $problem is not a metabol problem")
    end
    
    # State mapping: X3-7 -> X1-5
    # Input mapping: X1-2 -> X6-7
    # Note: X1 and X2 are sorted alphabetically, so X1 comes first (X6), X2 second (X7)
    return [
        "X1' = -X1*5.0/((X1+5.0)*(1+X6/1.0)) - X1*5.0/((X1+5.0)*(1+X7/1.0)) + X2*1.0/(X2+5.0) + X3*1.0/(X3+5.0)",
        "X2' = X1*5.0/((X1+5.0)*(1+X6/1.0)) - X2*1.0/(X2+5.0)",
        "X3' = X1*5.0/((X1+5.0)*(1+X7/1.0)) - X3*1.0/(X3+5.0)",
        "X4' = X5*10.0/((X5+5.0)*(1+X1/1.0)) - X4*1.0/(X4+5.0)",
        "X5' = -X5*10.0/((X5+5.0)*(1+X1/1.0)) + X4*1.0/(X4+5.0)"
    ]
end

end # module

