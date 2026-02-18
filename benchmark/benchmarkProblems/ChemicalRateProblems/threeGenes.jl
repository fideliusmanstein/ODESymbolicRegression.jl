"""
threeGenes.jl

Implementation of 3genes benchmark system (gene network).
Based on: https://www.cse.chalmers.se/~dag/identification/Benchmarks/3genes.html

Reference: Moles et al. (2003) - Parameter estimation in biochemical pathways: 
a comparison of global optimization methods.
"""

module ThreeGenesModule

using DifferentialEquations

export threegenes_system, generate_threegenes_data, generate_threegenes_experiments, get_equation_strings

"""
    threegenes_system(X, inputs, t; N=3)

Gene network benchmark system.

Models a gene network with N genes (default 3).
S and P are input metabolites, G are mRNAs, E are enzymes, M are metabolites.

For N=3:
States: G1, G2, G3, E1, E2, E3, M1, M2
Inputs: S (=M0), P (=M3)

Equations:
    Gi'(t) = VGi / (1+(P/KIi)^ni+(KAi/Mi-1)^mi) - kGi·Gi
    Ei'(t) = VEi·Gi / (KEi+Gi) - kEi·Ei
    Mi'(t) = kM1i·Ei·(kM2i)^(-1)·(Mi-1 - Mi) / (1+Mi-1/kM2i+Mi/kM3i) - 
             kM1(i+1)·E(i+1)·(kM2(i+1))^(-1)·(Mi - M(i+1)) / (1+Mi/kM2(i+1)+M(i+1)/kM3(i+1))

Parameters:
    VGi = KIi = KAi = kGi = KEi = kM1i = kM2i = kM3i = 1
    ni = mi = 2
    VEi = kEi = 0.1
"""
function threegenes_system(X, inputs, t; N=3)
    # For N=3: X = [G1, G2, G3, E1, E2, E3, M1, M2]
    # States: N genes (G), N enzymes (E), N-1 metabolites (M)
    G = X[1:N]
    E = X[N+1:2N]
    M = X[2N+1:end]
    
    # Get inputs
    S = inputs[:S](t)  # M0
    P = inputs[:P](t)  # MN
    
    # Parameters (all equal to 1 except VE and kE)
    VG = 1.0
    KI = 1.0
    KA = 1.0
    kG = 1.0
    KE = 1.0
    kM1 = 1.0
    kM2 = 1.0
    kM3 = 1.0
    n = 2
    m = 2
    VE = 0.1
    kE = 0.1
    
    # Create extended M array [S, M1, M2, ..., MN-1, P] = [M0, M1, ..., MN]
    M_ext = vcat([S], M, [P])
    
    dX = zeros(length(X))
    
    # Gene equations
    for i in 1:N
        Mi_minus_1 = M_ext[i]  # M[i-1] in extended array is M_ext[i]
        dX[i] = VG / (1 + (P/KI)^n + (KA/Mi_minus_1)^m) - kG * G[i]
    end
    
    # Enzyme equations
    for i in 1:N
        dX[N+i] = VE * G[i] / (KE + G[i]) - kE * E[i]
    end
    
    # Metabolite equations (only N-1 equations for M1 to M(N-1))
    for i in 1:N-1
        Mi_minus_1 = M_ext[i]    # M[i-1]
        Mi = M_ext[i+1]           # M[i]
        Mi_plus_1 = M_ext[i+2]    # M[i+1]
        
        # Production from previous step
        prod = kM1 * E[i] * (1/kM2) * (Mi_minus_1 - Mi) / (1 + Mi_minus_1/kM2 + Mi/kM3)
        
        # Consumption by next step
        cons = kM1 * E[i+1] * (1/kM2) * (Mi - Mi_plus_1) / (1 + Mi/kM2 + Mi_plus_1/kM3)
        
        dX[2N+i] = prod - cons
    end
    
    return dX
end

"""
    generate_threegenes_data(; S_const=1.0, P_const=1.0, X0=nothing, N=3,
                             tspan=(0.0, 10.0), n_points=21, noise_std=0.0,
                             S_func=nothing, P_func=nothing)

Generate data from the 3genes benchmark system.

Arguments:
- S_const, P_const: Constant values for inputs
- X0: Initial conditions (if nothing, uses defaults)
- N: Number of genes (default 3, resulting in 8 states)
- tspan: Time span
- n_points: Number of time points
- noise_std: Noise level (fraction of value)
- S_func, P_func: Optional time-varying input functions

Returns:
- t: Time points
- X: State matrix (n_points × (3N-1))
- inputs: Input values
"""
function generate_threegenes_data(;
    S_const=1.0,
    P_const=1.0,
    X0=nothing,
    N=3,
    tspan=(0.0, 10.0),
    n_points=21,
    noise_std=0.0,
    S_func=nothing,
    P_func=nothing
)
    # Create input functions
    if S_func === nothing
        S_func = t -> S_const
    end
    if P_func === nothing
        P_func = t -> P_const
    end
    
    inputs = Dict(:S => S_func, :P => P_func)
    
    # Initial conditions: N genes, N enzymes, N-1 metabolites = 3N-1 states
    if X0 === nothing
        X0 = zeros(3*N - 1)
        X0[1:N] .= 0.1     # Genes
        X0[N+1:2N] .= 0.1  # Enzymes
        X0[2N+1:end] .= 0.5  # Metabolites
    end
    
    # Define ODE problem
    function ode_func!(dX, X, p, t)
        dX .= threegenes_system(X, inputs, t; N=N)
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
    
    # Prepare input values
    input_values = Dict(
        :S => [S_func(ti) for ti in t],
        :P => [P_func(ti) for ti in t]
    )
    
    return t, X, input_values
end

"""
    generate_threegenes_experiments(; problem="threeGenes1")

Generate data for 3genes benchmark problems.

Problem variants:
- threeGenes1: 16 experiments, 21 points, 0% noise
- threeGenes2: 16 experiments, 21 points, 5% noise

Returns:
- experiments: Vector of dictionaries
"""
function generate_threegenes_experiments(; problem="threeGenes1")
    if problem == "threeGenes1"
        noise_std = 0.0
    elseif problem == "threeGenes2"
        noise_std = 0.05
    else
        error("Unknown problem: $problem. Choose from threeGenes1, threeGenes2")
    end
    
    # Generate 16 different initial conditions
    # Each variable varies around steady state
    experiments = []
    N = 3
    n_exp = 16
    
    for exp in 1:n_exp
        # Vary initial conditions
        X0 = zeros(3*N - 1)
        for i in 1:N
            X0[i] = 0.1 + 0.05 * randn()     # Genes
            X0[N+i] = 0.1 + 0.05 * randn()  # Enzymes
        end
        for i in 1:(N-1)
            X0[2N+i] = 0.5 + 0.2 * randn()  # Metabolites
        end
        
        t, X, input_values = generate_threegenes_data(
            S_const=1.0,
            P_const=1.0,
            X0=X0,
            N=3,
            tspan=(0.0, 10.0),
            n_points=21,
            noise_std=noise_std
        )
        
        push!(experiments, Dict(
            :experiment => exp,
            :t => t,
            :X => X,
            :inputs => input_values,
            :X0 => X0
        ))
    end
    
    return experiments
end

"""
    get_equation_strings(problem::String)

Return the ground truth equations for 3genes problems as strings.

For both threeGenes1 and threeGenes2 (N=3):
States: G1, G2, G3, E1, E2, E3, M1, M2
Inputs: S (=M0), P (=M3)

Gene equations:
    Gi' = VG / (1+(P/KI)^n+(KA/Mi-1)^m) - kG·Gi

Enzyme equations:
    Ei' = VE·Gi / (KE+Gi) - kE·Ei

Metabolite equations:
    Mi' = kM1·Ei·(kM2)^(-1)·(Mi-1 - Mi) / (1+Mi-1/kM2+Mi/kM3) - 
          kM1·E(i+1)·(kM2)^(-1)·(Mi - M(i+1)) / (1+Mi/kM2+M(i+1)/kM3)

Parameters: VG=KI=KA=kG=KE=kM1=kM2=kM3=1.0, n=m=2, VE=kE=0.1
"""
function get_equation_strings(problem::String)
    if !startswith(problem, "threeGenes")
        error("Problem $problem is not a threeGenes problem")
    end
    
    # For N=3 with all parameters = 1.0 except VE=kE=0.1, n=m=2
    # Variable mapping: G1-3 -> X1-3, E1-3 -> X4-6, M1-2 -> X7-8
    # Inputs: P -> X9, S -> X10 (alphabetically sorted keys :P, :S)
    return [
        "X1' = 1.0 / (1+(X9/1.0)^2+(1.0/X10)^2) - 1.0*X1",
        "X2' = 1.0 / (1+(X9/1.0)^2+(1.0/X7)^2) - 1.0*X2",
        "X3' = 1.0 / (1+(X9/1.0)^2+(1.0/X8)^2) - 1.0*X3",
        "X4' = 0.1*X1 / (1.0+X1) - 0.1*X4",
        "X5' = 0.1*X2 / (1.0+X2) - 0.1*X5",
        "X6' = 0.1*X3 / (1.0+X3) - 0.1*X6",
        "X7' = 1.0*X4*(X10-X7) / (1+X10/1.0+X7/1.0) - 1.0*X5*(X7-X8) / (1+X7/1.0+X8/1.0)",
        "X8' = 1.0*X5*(X7-X8) / (1+X7/1.0+X8/1.0) - 1.0*X6*(X8-X9) / (1+X8/1.0+X9/1.0)"
    ]
end

end # module

