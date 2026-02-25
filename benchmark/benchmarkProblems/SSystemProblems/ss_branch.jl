"""
ss_branch.jl

S-system branched pathway with 4 dependent variables.
Based on: Voit (2000), Voit and Almeida (2004)
"""

module SsBranchModule

include("SSystemBase.jl")
using .SSystemBase
using DifferentialEquations

export ss_branch_system, generate_ss_branch_data, generate_ss_branch_experiments, get_equation_strings

# System parameters (4 variables)
const α = [12.0, 8.0, 3.0, 2.0]
const β = [10.0, 3.0, 5.0, 6.0]
const g = [0.0   0.0  -0.8  0.0;
           0.5   0.0   0.0  0.0;
           0.0   0.75  0.0  0.0;
           0.5   0.0   0.0  0.0]
const h = [0.5  0.0   0.0  0.0;
           0.0  0.75  0.0  0.0;
           0.0  0.0   0.5  0.2;
           0.0  0.0   0.0  0.8]

"""
    ss_branch_system(X, inputs, t)

Branched pathway S-system with 4 dependent variables.

Equations:
    X1'(t) = 12·X3^(-0.8) - 10·X1^0.5
    X2'(t) = 8·X1^0.5 - 3·X2^0.75
    X3'(t) = 3·X2^0.75 - 5·X3^0.5·X4^0.2
    X4'(t) = 2·X1^0.5 - 6·X4^0.8
"""
function ss_branch_system(X, inputs, t)
    return SSystemBase.ssystem_ode(X, α, β, g, h, inputs, t)
end

function generate_ss_branch_data(;
    X0=[1.0, 1.0, 1.0, 1.0],
    tspan=(0.0, 10.0),
    n_points=51,
    noise_std=0.0
)
    inputs = Dict{Symbol, Function}()
    
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

function generate_ss_branch_experiments(; problem="ss_branch1", noise_std::Union{Float64,Nothing}=nothing)
    # Problem-specific parameters
    params = Dict(
        "ss_branch1" => (n_exp=3, n_points=21, noise_std=0.0),
        "ss_branch2" => (n_exp=6, n_points=51, noise_std=0.0),
        "ss_branch3" => (n_exp=5, n_points=20, noise_std=0.0),
        "ss_branch4" => (n_exp=4, n_points=20, noise_std=0.0),
        "ss_branch5" => (n_exp=4, n_points=20, noise_std=0.025),
        "ss_branch6" => (n_exp=5, n_points=31, noise_std=0.0)
    )
    
    if !haskey(params, problem)
        error("Unknown problem: $problem. Choose from ss_branch1-6")
    end
    
    p = params[problem]
    _noise = noise_std !== nothing ? noise_std : p.noise_std
    experiments = []
    
    for exp in 1:p.n_exp
        X0 = 1.0 .+ 0.5 * randn(4)
        X0 = max.(X0, 0.1)
        
        t, X, input_values = generate_ss_branch_data(
            X0=X0,
            tspan=(0.0, 10.0),
            n_points=p.n_points,
            noise_std=_noise
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

Return the ground truth equations for ss_branch problems as strings.

Equations:
    X1' = 12·X3^(-0.8) - 10·X1^0.5
    X2' = 8·X1^0.5 - 3·X2^0.75
    X3' = 3·X2^0.75 - 5·X3^0.5·X4^0.2
    X4' = 2·X1^0.5 - 6·X4^0.8
"""
function get_equation_strings(problem::String)
    if !startswith(problem, "ss_branch")
        error("Problem $problem is not a ss_branch problem")
    end
    
    return SSystemBase.format_ssystem_equations(α, β, g, h, 4, nothing)
end

end # module
