"""
ss_cascade.jl

S-system cascade pathway with 3 dependent variables.
Based on: Voit (2000), Tsai and Wang (2005)
"""

module SsCascadeModule

include("SSystemBase.jl")
using .SSystemBase
using DifferentialEquations

export ss_cascade_system, generate_ss_cascade_data, generate_ss_cascade_experiments, get_equation_strings

# System parameters
const α = [10.0, 2.0, 3.0]
const β = [5.0, 1.44, 7.2]
const g = [0.0  -0.1  -0.05  1.0;
           0.5   0.0   0.0   0.0;
           0.0   0.5   0.0   0.0]
const h = [0.5  0.0  0.0  0.0;
           0.0  0.5  0.0  0.0;
           0.0  0.0  0.5  0.0]

"""
    ss_cascade_system(X, inputs, t)

Cascaded pathway S-system with 3 dependent variables (X1-X3) and 1 input (X4).

Equations:
    X1'(t) = 10·X2^(-0.1)·X3^(-0.05)·X4 - 5·X1^0.5
    X2'(t) = 2·X1^0.5 - 1.44·X2^0.5
    X3'(t) = 3·X2^0.5 - 7.2·X3^0.5
"""
function ss_cascade_system(X, inputs, t)
    return SSystemBase.ssystem_ode(X, α, β, g, h, inputs, t)
end

function generate_ss_cascade_data(;
    X4_const=5.0,
    X0=[1.0, 1.0, 1.0],
    tspan=(0.0, 10.0),
    n_points=41,
    noise_std=0.0,
    X4_func=nothing
)
    if X4_func === nothing
        X4_func = t -> X4_const
    end
    
    inputs = Dict(:X4 => X4_func)
    
    t, X, input_values = SSystemBase.generate_ssystem_data(
        α, β, g, h;
        X0=X0,
        tspan=tspan,
        n_points=n_points,
        noise_std=noise_std,
        inputs=inputs
    )
    
    return t, X, input_values
end

function generate_ss_cascade_experiments(; problem="ss_cascade1", noise_std::Union{Float64,Nothing}=nothing, n_points::Union{Int,Nothing}=nothing)
    if problem == "ss_cascade1"
        n_exp = 8
        noise_std = noise_std !== nothing ? noise_std : 0.0
    elseif problem == "ss_cascade2"
        n_exp = 4
        noise_std = noise_std !== nothing ? noise_std : 0.0
    elseif problem == "ss_cascade3"
        n_exp = 8
        noise_std = noise_std !== nothing ? noise_std : 0.0
    else
        error("Unknown problem: $problem. Choose from ss_cascade1, ss_cascade2, ss_cascade3")
    end
    
    experiments = []
    
    # Different initial conditions for each experiment
    for exp in 1:n_exp
        X0 = 1.0 .+ 0.5 * randn(3)
        X0 = max.(X0, 0.1)
        
        _n_points = n_points !== nothing ? n_points : 41
        t, X, input_values = generate_ss_cascade_data(
            X4_const=5.0,
            X0=X0,
            tspan=(0.0, 10.0),
            n_points=_n_points,
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

Return the ground truth equations for ss_cascade problems as strings.

Equations:
    X1' = 10·X2^(-0.1)·X3^(-0.05)·X4 - 5·X1^0.5
    X2' = 2·X1^0.5 - 1.44·X2^0.5
    X3' = 3·X2^0.5 - 7.2·X3^0.5
"""
function get_equation_strings(problem::String)
    if !startswith(problem, "ss_cascade")
        error("Problem $problem is not a ss_cascade problem")
    end
    
    return SSystemBase.format_ssystem_equations(α, β, g, h, 3, Dict(4 => "X4"))
end

end # module

